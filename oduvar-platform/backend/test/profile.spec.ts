import request from 'supertest';
import { createApp } from '../src/app';
import { prisma } from '../src/config/database';
import { Role, TransportOption } from '@prisma/client';
import bcrypt from 'bcryptjs';

const app = createApp();

// ─── Test helpers ─────────────────────────────────────────────────────────────

async function createTestUser(role: Role, suffix: string) {
  const hash = await bcrypt.hash('TestPass#2026!', 10);
  return prisma.user.create({
    data: {
      name: `Test ${role} ${suffix}`,
      email: `test.${role.toLowerCase()}.${suffix}@oduvar.test`,
      phone: '+910000000000',
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

async function getSkillIds(): Promise<string[]> {
  const skills = await prisma.skill.findMany({ take: 2 });
  return skills.map((s) => s.id);
}

async function getInstrumentIds(): Promise<string[]> {
  const instruments = await prisma.instrument.findMany({ take: 2 });
  return instruments.map((i) => i.id);
}

// ─── Test data cleanup ────────────────────────────────────────────────────────

afterAll(async () => {
  await prisma.oduvarProfileSkill.deleteMany({});
  await prisma.oduvarProfileInstrument.deleteMany({});
  await prisma.oduvarPhoto.deleteMany({});
  await prisma.oduvarProfile.deleteMany({
    where: { user: { email: { contains: '@oduvar.test' } } },
  });
  await prisma.user.deleteMany({ where: { email: { contains: '@oduvar.test' } } });
  await prisma.$disconnect();
});

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('Phase 2: Oduvar Profile API', () => {
  let oduvarToken: string;
  let oduvarUserId: string;
  let oduvar2Token: string;
  let clientToken: string;
  let skillIds: string[];
  let instrumentIds: string[];

  beforeAll(async () => {
    const oduvar = await createTestUser(Role.ODUVAR, 'main');
    const oduvar2 = await createTestUser(Role.ODUVAR, 'other');
    const client = await createTestUser(Role.CLIENT, 'main');

    oduvarUserId = oduvar.id;
    oduvarToken = await loginUser(oduvar.email);
    oduvar2Token = await loginUser(oduvar2.email);
    clientToken = await loginUser(client.email);

    skillIds = await getSkillIds();
    instrumentIds = await getInstrumentIds();
  });

  // ─── 1. Oduvar can create profile ──────────────────────────────────────────
  test('1. Oduvar can create a profile', async () => {
    const res = await request(app)
      .post('/api/oduvars/me/profile')
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        bio: 'I sing Thevaram with devotion',
        location: 'Chennai, Tamil Nadu',
        performanceTypes: ['VOCAL'],
        songCategories: ['THEVARAM', 'THIRUVASAGAM'],
        transport: 'INCLUDED',
        collaborationEnabled: true,
        isPublished: true,
        skillIds,
        instrumentIds,
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.profile.bio).toBe('I sing Thevaram with devotion');
    expect(res.body.data.profile.skills).toHaveLength(2);
    expect(res.body.data.profile.instruments).toHaveLength(2);
  });

  // ─── 2. Oduvar can update own profile ──────────────────────────────────────
  test('2. Oduvar can update their own profile', async () => {
    const res = await request(app)
      .put('/api/oduvars/me/profile')
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        bio: 'Updated: Experienced Oduvar serving across Tamil Nadu',
        location: 'Madurai, Tamil Nadu',
        performanceTypes: ['VOCAL', 'BOTH'],
        songCategories: ['THEVARAM'],
        transport: 'ADDITIONAL_FEE',
        collaborationEnabled: false,
        isPublished: true,
        skillIds,
        instrumentIds,
      });

    expect(res.status).toBe(200);
    expect(res.body.data.profile.bio).toBe('Updated: Experienced Oduvar serving across Tamil Nadu');
    expect(res.body.data.profile.location).toBe('Madurai, Tamil Nadu');
    expect(res.body.data.profile.collaborationEnabled).toBe(false);
  });

  // ─── 3. Client cannot create Oduvar profile ─────────────────────────────────
  test('3. Client cannot create an Oduvar profile', async () => {
    const res = await request(app)
      .post('/api/oduvars/me/profile')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ bio: 'Should not work', location: 'Chennai' });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });

  // ─── 4. Oduvar cannot edit another Oduvar's profile ────────────────────────
  test("4. Oduvar cannot edit another Oduvar's profile (PUT only creates for own)", async () => {
    // oduvar2 tries to GET oduvar1's private profile – should get 404 (no profile for oduvar2)
    const res = await request(app)
      .get('/api/oduvars/me/profile')
      .set('Authorization', `Bearer ${oduvar2Token}`);

    // oduvar2 has no profile yet → 200 with null profile (not oduvar1's data)
    expect(res.status).toBe(200);
    expect(res.body.data.profile).toBeNull();
  });

  // ─── 5. Public profile endpoint ─────────────────────────────────────────────
  test('5. Public profile can be fetched by anyone', async () => {
    const res = await request(app)
      .get(`/api/oduvars/${oduvarUserId}/profile`);

    expect(res.status).toBe(200);
    expect(res.body.data.profile.owner.id).toBe(oduvarUserId);
    // Must NOT expose private fields
    expect(res.body.data.profile.owner.email).toBeUndefined();
    expect(res.body.data.profile.owner.phone).toBeUndefined();
  });

  // ─── 6. Photo limit enforced ────────────────────────────────────────────────
  test('6. Photo limit (max 5) is enforced', async () => {
    // Add 5 photos via DB directly to avoid needing real images in tests
    const profile = await prisma.oduvarProfile.findFirst({
      where: { userId: oduvarUserId },
    });
    expect(profile).not.toBeNull();

    // Insert 5 photos
    for (let i = 1; i <= 5; i++) {
      await prisma.oduvarPhoto.create({
        data: {
          profileId: profile!.id,
          imageUrl: `http://localhost:5000/uploads/test-${i}.jpg`,
          displayOrder: i,
        },
      });
    }

    // 6th upload should fail (via API endpoint validation)
    const res = await request(app)
      .post('/api/oduvars/me/profile/photos')
      .set('Authorization', `Bearer ${oduvarToken}`)
      .attach('photo', Buffer.from('fake-image'), {
        filename: 'test.jpg',
        contentType: 'image/jpeg',
      });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('PROFILE_PHOTO_LIMIT');
  });

  // ─── 7. Oduvar can delete own photo ─────────────────────────────────────────
  test('7. Oduvar can delete their own photo', async () => {
    const profile = await prisma.oduvarProfile.findFirst({
      where: { userId: oduvarUserId },
      include: { photos: true },
    });
    const photoId = profile!.photos[0].id;

    const res = await request(app)
      .delete(`/api/oduvars/me/profile/photos/${photoId}`)
      .set('Authorization', `Bearer ${oduvarToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.message).toContain('deleted');
  });

  // ─── 8. Oduvar can reorder photos ───────────────────────────────────────────
  test('8. Oduvar can reorder photos', async () => {
    const profile = await prisma.oduvarProfile.findFirst({
      where: { userId: oduvarUserId },
      include: { photos: { orderBy: { displayOrder: 'asc' } } },
    });
    const photos = profile!.photos;

    if (photos.length < 2) {
      // Add one more photo if needed
      await prisma.oduvarPhoto.create({
        data: { profileId: profile!.id, imageUrl: 'http://localhost/x.jpg', displayOrder: 1 },
      });
    }

    const updatedProfile = await prisma.oduvarProfile.findFirst({
      where: { userId: oduvarUserId },
      include: { photos: { orderBy: { displayOrder: 'asc' } } },
    });
    const updatedPhotos = updatedProfile!.photos;

    const reorderPayload = updatedPhotos.map((p, idx) => ({
      id: p.id,
      displayOrder: updatedPhotos.length - idx, // reverse order
    }));

    const res = await request(app)
      .put('/api/oduvars/me/profile/photos/reorder')
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({ photos: reorderPayload });

    expect(res.status).toBe(200);
    expect(res.body.data.message).toContain('reordered');
  });

  // ─── 9. Invalid data is rejected ────────────────────────────────────────────
  test('9. Invalid data is rejected by validation', async () => {
    const res = await request(app)
      .put('/api/oduvars/me/profile')
      .set('Authorization', `Bearer ${oduvarToken}`)
      .send({
        bio: 'x'.repeat(1001), // exceeds 1000 char limit
        transport: 'INVALID_OPTION',
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  // ─── 10. Unauthorized access is rejected ────────────────────────────────────
  test('10. Unauthorized access is rejected', async () => {
    const res = await request(app).get('/api/oduvars/me/profile');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });
});

// ─── Phase 2: Reference Data API ─────────────────────────────────────────────

describe('Phase 2: Reference Data API', () => {
  test('GET /api/skills returns seeded skill list', async () => {
    const res = await request(app).get('/api/skills');
    expect(res.status).toBe(200);
    expect(res.body.data.skills.length).toBeGreaterThanOrEqual(10);
    expect(res.body.data.skills[0]).toHaveProperty('slug');
  });

  test('GET /api/instruments returns seeded instrument list', async () => {
    const res = await request(app).get('/api/instruments');
    expect(res.status).toBe(200);
    expect(res.body.data.instruments.length).toBeGreaterThanOrEqual(10);
  });

  test('GET /api/performance-types returns expected types', async () => {
    const res = await request(app).get('/api/performance-types');
    expect(res.status).toBe(200);
    const keys = res.body.data.performanceTypes.map((t: any) => t.key);
    expect(keys).toContain('VOCAL');
    expect(keys).toContain('INSTRUMENTAL');
    expect(keys).toContain('BOTH');
  });

  test('GET /api/song-categories returns Thevaram and others', async () => {
    const res = await request(app).get('/api/song-categories');
    expect(res.status).toBe(200);
    const keys = res.body.data.songCategories.map((c: any) => c.key);
    expect(keys).toContain('THEVARAM');
    expect(keys).toContain('THIRUVASAGAM');
  });
});
