import request from 'supertest';
import { createApp } from '../src/app';
import { prisma } from '../src/config/database';
import { Role, TransportOption } from '@prisma/client';
import bcrypt from 'bcryptjs';

const app = createApp();

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function createTestUser(role: Role, suffix: string) {
  const hash = await bcrypt.hash('TestPass#2026!', 10);
  return prisma.user.create({
    data: {
      name: `Test ${role} ${suffix}`,
      email: `test.svc.${role.toLowerCase()}.${suffix}@oduvar.test`,
      phone: '+919988776655',
      passwordHash: hash,
      role,
    },
  });
}

async function loginUser(email: string): Promise<string> {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ email, password: 'TestPass#2026!' });
  return res.body.data.accessToken;
}

// ─── Cleanup ─────────────────────────────────────────────────────────────────

afterAll(async () => {
  await prisma.servicePricing.deleteMany({});
  await prisma.oduvarService.deleteMany({});
  await prisma.oduvarProfile.deleteMany({
    where: { user: { email: { contains: 'test.svc.' } } },
  });
  await prisma.user.deleteMany({
    where: { email: { contains: 'test.svc.' } },
  });
  await prisma.$disconnect();
});

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('Phase 3: Oduvar Services and Pricing API', () => {
  let oduvarToken: string;
  let oduvarUserId: string;
  let oduvar2Token: string;
  let clientToken: string;
  let baseServiceId1: string;
  let baseServiceId2: string;
  let createdOduvarServiceId: string;
  let createdPricingId: string;

  beforeAll(async () => {
    // Clean old test data if any
    await prisma.servicePricing.deleteMany({});
    await prisma.oduvarService.deleteMany({});
    await prisma.oduvarProfile.deleteMany({
      where: { user: { email: { contains: 'test.svc.' } } },
    });
    await prisma.user.deleteMany({
      where: { email: { contains: 'test.svc.' } },
    });

    // Create users
    const oduvarUser = await createTestUser(Role.ODUVAR, 'primary');
    oduvarUserId = oduvarUser.id;
    oduvarToken = await loginUser(oduvarUser.email);

    const oduvarUser2 = await createTestUser(Role.ODUVAR, 'secondary');
    oduvar2Token = await loginUser(oduvarUser2.email);

    const clientUser = await createTestUser(Role.CLIENT, 'client');
    clientToken = await loginUser(clientUser.email);

    // Fetch 2 seeded services
    const services = await prisma.service.findMany({ take: 2 });
    baseServiceId1 = services[0].id;
    baseServiceId2 = services[1].id;
  });

  // ─── 1. Oduvar can create a service ───────────────────────────────────────
  it('1. Oduvar can create a service with initial pricing and transport', async () => {
    const res = await request(app)
      .post('/api/oduvars/me/services')
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        serviceId: baseServiceId1,
        customDescription: 'Special Thevaram pann recital for morning rituals',
        transport: TransportOption.INCLUDED,
        pricings: [
          { durationMinutes: 30, amount: 500 },
          { durationMinutes: 60, amount: 900 },
          { durationMinutes: 120, amount: 1700 },
        ],
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.service).toBeDefined();
    expect(res.body.data.service.serviceId).toBe(baseServiceId1);
    expect(res.body.data.service.transport).toBe(TransportOption.INCLUDED);
    expect(res.body.data.service.pricings).toHaveLength(3);
    expect(res.body.data.service.pricings[0].amount).toBe(500);

    createdOduvarServiceId = res.body.data.service.id;
    createdPricingId = res.body.data.service.pricings[0].id;
  });

  // ─── 2. Oduvar can update own service ─────────────────────────────────────
  it('2. Oduvar can update own service description and transport', async () => {
    const res = await request(app)
      .put(`/api/oduvars/me/services/${createdOduvarServiceId}`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        customDescription: 'Updated special recital description',
        transport: TransportOption.ADDITIONAL_FEE,
        transportFee: 300,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.service.customDescription).toBe('Updated special recital description');
    expect(res.body.data.service.transport).toBe(TransportOption.ADDITIONAL_FEE);
    expect(res.body.data.service.transportFee).toBe(300);
  });

  // ─── 3. Oduvar cannot edit another Oduvar's service ───────────────────────
  it('3. Oduvar cannot edit another Oduvar service (403 Forbidden)', async () => {
    const res = await request(app)
      .put(`/api/oduvars/me/services/${createdOduvarServiceId}`)
      .set('Authorization', `Bearer ${oduvar2Token}`)
      .send({
        customDescription: 'Malicious update',
      });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });

  // ─── 4. Client cannot modify services ─────────────────────────────────────
  it('4. Client cannot create or modify services (403 Forbidden)', async () => {
    const createRes = await request(app)
      .post('/api/oduvars/me/services')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({
        serviceId: baseServiceId2,
        transport: TransportOption.INCLUDED,
      });
    expect(createRes.status).toBe(403);

    const updateRes = await request(app)
      .put(`/api/oduvars/me/services/${createdOduvarServiceId}`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({
        customDescription: 'Client attempt',
      });
    expect(updateRes.status).toBe(403);
  });

  // ─── 5. Oduvar can create pricing ─────────────────────────────────────────
  it('5. Oduvar can create new duration pricing for their service', async () => {
    const res = await request(app)
      .post(`/api/oduvars/me/services/${createdOduvarServiceId}/pricing`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        durationMinutes: 180, // 3 hours
        amount: 2500,
        currency: 'INR',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.pricing.durationMinutes).toBe(180);
    expect(res.body.data.pricing.amount).toBe(2500);
    expect(res.body.data.pricing.currency).toBe('INR');
  });

  // ─── 6. Minimum 30-minute rule is enforced ────────────────────────────────
  it('6. Minimum 30-minute rule is enforced (rejects < 30 min)', async () => {
    const res = await request(app)
      .post(`/api/oduvars/me/services/${createdOduvarServiceId}/pricing`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        durationMinutes: 20, // Invalid: < 30
        amount: 300,
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  // ─── 7. Duplicate duration pricing is rejected ────────────────────────────
  it('7. Duplicate duration pricing is rejected (409 Conflict)', async () => {
    const res = await request(app)
      .post(`/api/oduvars/me/services/${createdOduvarServiceId}/pricing`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        durationMinutes: 30, // Already exists from test 1
        amount: 550,
      });

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
  });

  // ─── 8. Invalid amount is rejected ────────────────────────────────────────
  it('8. Invalid amount (<= 0) is rejected with 400', async () => {
    const res = await request(app)
      .post(`/api/oduvars/me/services/${createdOduvarServiceId}/pricing`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        durationMinutes: 90,
        amount: -100, // Invalid: negative
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  // ─── 9. Transport fee validation works ─────────────────────────────────────
  it('9. Transport fee validation requires positive fee when ADDITIONAL_FEE', async () => {
    const res = await request(app)
      .put(`/api/oduvars/me/services/${createdOduvarServiceId}`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        transport: TransportOption.ADDITIONAL_FEE,
        transportFee: 0, // Invalid: must be > 0
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  // ─── 10. Oduvar can deactivate a service ──────────────────────────────────
  it('10. Oduvar can deactivate a service', async () => {
    const res = await request(app)
      .put(`/api/oduvars/me/services/${createdOduvarServiceId}`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        isActive: false,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.service.isActive).toBe(false);
  });

  // ─── 11. Public endpoint hides inactive services ──────────────────────────
  it('11. Public endpoint hides inactive services', async () => {
    // First make profile published so public endpoint serves it
    await prisma.oduvarProfile.update({
      where: { userId: oduvarUserId },
      data: { isPublished: true },
    });

    // Currently createdOduvarServiceId is isActive: false
    const res = await request(app).get(`/api/oduvars/${oduvarUserId}/services`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const activeServices = res.body.data.services;
    const found = activeServices.find((s: any) => s.id === createdOduvarServiceId);
    expect(found).toBeUndefined(); // Inactive service is hidden!
  });

  // ─── 12. Public service endpoint exposes published pricing ─────────────────
  it('12. Public service endpoint exposes active services and active pricing', async () => {
    // Reactivate service
    await request(app)
      .put(`/api/oduvars/me/services/${createdOduvarServiceId}`)
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        isActive: true,
        transport: TransportOption.ADDITIONAL_FEE,
        transportFee: 300,
      });

    const res = await request(app).get(`/api/oduvars/${oduvarUserId}/services`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const services = res.body.data.services;
    expect(services.length).toBeGreaterThanOrEqual(1);

    const svc = services.find((s: any) => s.id === createdOduvarServiceId);
    expect(svc).toBeDefined();
    expect(svc.transport).toBe(TransportOption.ADDITIONAL_FEE);
    expect(svc.transportFee).toBe(300);
    expect(svc.pricings.length).toBeGreaterThanOrEqual(3);
    expect(svc.pricings[0].amount).toBeGreaterThan(0);
  });

  // ─── 13. Client cannot access Oduvar management endpoints ──────────────────
  it('13. Client cannot access Oduvar management endpoints (403 Forbidden)', async () => {
    const res = await request(app)
      .get('/api/oduvars/me/services')
      .set('Authorization', `Bearer ${clientToken}`);

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);

    const deleteRes = await request(app)
      .delete(`/api/oduvars/me/services/${createdOduvarServiceId}`)
      .set('Authorization', `Bearer ${clientToken}`);

    expect(deleteRes.status).toBe(403);
  });

  // ─── Reference Data: GET /api/services ────────────────────────────────────
  it('GET /api/services returns active reference services', async () => {
    const res = await request(app).get('/api/services');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data.services)).toBe(true);
    expect(res.body.data.services.length).toBeGreaterThanOrEqual(4);
    const categories = res.body.data.services.map((s: any) => s.category);
    expect(categories).toContain('Thevaram');
  });
});
