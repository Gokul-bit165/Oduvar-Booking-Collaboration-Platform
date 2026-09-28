import request from 'supertest';
import { createApp } from '../src/app';
import { prisma } from '../src/config/database';
import { Application } from 'express';

describe('Auth & Role Authorization API Tests (Phase 1)', () => {
  let app: Application;

  const testClient = {
    name: 'Anand Kumar',
    email: 'test.client.flow@oduvar.local',
    phone: '+919988776655',
    password: 'Password123!',
    role: 'CLIENT',
  };

  const testOduvar = {
    name: 'Oduvar Muthukumaran',
    email: 'test.oduvar.flow@oduvar.local',
    phone: '+919988776644',
    password: 'Password123!',
    role: 'ODUVAR',
  };

  beforeAll(async () => {
    app = createApp();
    // Clean up any previous test artifacts
    await prisma.user.deleteMany({
      where: {
        email: {
          in: [testClient.email, testOduvar.email, 'another.client@oduvar.local'],
        },
      },
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({
      where: {
        email: {
          in: [testClient.email, testOduvar.email, 'another.client@oduvar.local'],
        },
      },
    });
    await prisma.$disconnect();
  });

  // 1. User registration
  it('1. User registration - should successfully register a new CLIENT user', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(testClient);

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.user).toBeDefined();
    expect(res.body.data.user.email).toBe(testClient.email.toLowerCase());
    expect(res.body.data.user.role).toBe('CLIENT');
    expect(res.body.data.user.passwordHash).toBeUndefined(); // Must NEVER expose passwordHash
    expect(res.body.data.accessToken).toBeDefined();
    expect(res.body.data.refreshToken).toBeDefined();
  });

  // 2. Duplicate email
  it('2. Duplicate email - should reject registration with 409 when email already exists', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(testClient);

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toBeDefined();
    expect(res.body.error.code).toBe('AUTH_EMAIL_EXISTS');
  });

  // 3. Invalid email
  it('3. Invalid email - should reject registration with 400 when email format is invalid', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        ...testClient,
        email: 'invalid-email-address',
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  // 4. Invalid password
  it('4. Invalid password - should reject registration with 400 when password is too short (< 8 chars)', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        name: 'Short Pass User',
        email: 'shortpass@oduvar.local',
        phone: '+919988776633',
        password: '123',
        role: 'CLIENT',
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  // Security test: Cannot register as ADMIN publicly
  it('Security: Should reject registration if client attempts to register as ADMIN', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        name: 'Hacker Admin',
        email: 'fakeadmin@oduvar.local',
        phone: '+919988776632',
        password: 'Password123!',
        role: 'ADMIN',
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  // 5. Successful login
  let clientAccessToken = '';
  let clientRefreshToken = '';

  it('5. Successful login - should log in with valid credentials and return tokens', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({
        email: testClient.email,
        password: testClient.password,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(testClient.email.toLowerCase());
    expect(res.body.data.user.passwordHash).toBeUndefined();
    expect(res.body.data.accessToken).toBeDefined();
    expect(res.body.data.refreshToken).toBeDefined();

    clientAccessToken = res.body.data.accessToken;
    clientRefreshToken = res.body.data.refreshToken;
  });

  // 6. Invalid login
  it('6. Invalid login - should reject login with invalid password (401)', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({
        email: testClient.email,
        password: 'WrongPassword!',
      });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
  });

  it('6b. Invalid login - should reject login with non-existent email (401)', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'nonexistent.user@oduvar.local',
        password: 'Password123!',
      });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
  });

  // 7. /auth/me with valid token
  it('7. /auth/me with valid token - should return current authenticated user profile', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${clientAccessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(testClient.email.toLowerCase());
    expect(res.body.data.user.name).toBe(testClient.name);
    expect(res.body.data.user.role).toBe('CLIENT');
  });

  // 8. /auth/me without token
  it('8. /auth/me without token - should reject with 401 Unauthorized', async () => {
    const res = await request(app).get('/api/auth/me');

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('AUTH_UNAUTHORIZED');
  });

  // 9. Role authorization
  it('9. Role authorization - Client can access Client protected route', async () => {
    const res = await request(app)
      .get('/api/auth/protected/client')
      .set('Authorization', `Bearer ${clientAccessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.message).toBe('Welcome to Client Area');
  });

  it('9b. Role authorization - Client is FORBIDDEN (403) from accessing Admin protected route', async () => {
    const res = await request(app)
      .get('/api/auth/protected/admin')
      .set('Authorization', `Bearer ${clientAccessToken}`);

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
  });

  it('9c. Role authorization - Register and verify Oduvar role access', async () => {
    const oduvarReg = await request(app)
      .post('/api/auth/register')
      .send(testOduvar);

    expect(oduvarReg.status).toBe(201);
    const oduvarToken = oduvarReg.body.data.accessToken;

    // Oduvar accessing Oduvar area -> 200
    const oduvarRes = await request(app)
      .get('/api/auth/protected/oduvar')
      .set('Authorization', `Bearer ${oduvarToken}`);
    expect(oduvarRes.status).toBe(200);

    // Oduvar accessing Client-only area -> 403
    const clientAreaRes = await request(app)
      .get('/api/auth/protected/client')
      .set('Authorization', `Bearer ${oduvarToken}`);
    expect(clientAreaRes.status).toBe(403);
  });

  // 10. Refresh token
  let newAccessToken = '';
  it('10. Refresh token - should issue new access token using valid refresh token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({
        refreshToken: clientRefreshToken,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.accessToken).toBeDefined();
    expect(res.body.data.refreshToken).toBeDefined();

    newAccessToken = res.body.data.accessToken;

    // Verify the new access token works
    const meRes = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${newAccessToken}`);
    expect(meRes.status).toBe(200);
  });

  // 11. Logout
  it('11. Logout - should invalidate session and subsequent me requests with previous tokens fail', async () => {
    // Call logout with newAccessToken
    const logoutRes = await request(app)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${newAccessToken}`);

    expect(logoutRes.status).toBe(200);
    expect(logoutRes.body.success).toBe(true);

    // Now, previous token should be revoked (tokenVersion incremented)
    const afterLogoutRes = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${newAccessToken}`);

    expect(afterLogoutRes.status).toBe(401);
    expect(afterLogoutRes.body.error.code).toBe('AUTH_TOKEN_REVOKED');
  });
});
