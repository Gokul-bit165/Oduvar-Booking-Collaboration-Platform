import request from 'supertest';
import { createApp } from '../src/app';
import { prisma } from '../src/config/database';
import { Role } from '@prisma/client';
import bcrypt from 'bcryptjs';

const app = createApp();

// Far-future dates so "past" filtering never interferes.
const MONDAY = '2035-01-01';
const TUESDAY = '2035-01-02';
const SUNDAY = '2035-01-07';

async function createTestUser(role: Role, suffix: string) {
  const hash = await bcrypt.hash('TestPass#2026!', 10);
  return prisma.user.create({
    data: {
      name: `Test ${role} ${suffix}`,
      email: `test.avail.${role.toLowerCase()}.${suffix}@oduvar.test`,
      phone: '+919988776655',
      passwordHash: hash,
      role,
    },
  });
}

async function login(email: string): Promise<string> {
  const res = await request(app).post('/api/auth/login').send({ email, password: 'TestPass#2026!' });
  return res.body.data.accessToken;
}

async function cleanup() {
  await prisma.oduvarProfile.deleteMany({ where: { user: { email: { contains: 'test.avail.' } } } });
  await prisma.user.deleteMany({ where: { email: { contains: 'test.avail.' } } });
}

const weekdayDay = (dayOfWeek: string, windows: [string, string][], isActive = true) => ({
  dayOfWeek,
  isActive,
  windows: windows.map(([startTime, endTime]) => ({ startTime, endTime })),
});

describe('Phase 4: Availability API', () => {
  let tok: string;
  let tok2: string;
  let clientTok: string;
  let userId: string;
  let overrideId: string;

  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  const put = (t: string, body: unknown) => request(app).put('/api/oduvars/me/availability/weekly').set(auth(t)).send(body as object);
  const addOverride = (t: string, body: unknown) =>
    request(app).post('/api/oduvars/me/availability/overrides').set(auth(t)).send(body as object);
  const day = (date: string, duration?: number) =>
    request(app).get(`/api/oduvars/${userId}/availability?date=${date}${duration ? `&duration=${duration}` : ''}`);

  beforeAll(async () => {
    await cleanup();
    const o1 = await createTestUser(Role.ODUVAR, 'one');
    userId = o1.id;
    tok = await login(o1.email);
    const o2 = await createTestUser(Role.ODUVAR, 'two');
    tok2 = await login(o2.email);
    const c = await createTestUser(Role.CLIENT, 'client');
    clientTok = await login(c.email);
    // Profiles: publish oduvar one (public endpoint requires published)
    await request(app).get('/api/oduvars/me/availability').set(auth(tok)); // lazily creates profile
    await request(app).get('/api/oduvars/me/availability').set(auth(tok2));
    await prisma.oduvarProfile.update({ where: { userId }, data: { isPublished: true } });
  });

  afterAll(async () => {
    await cleanup();
    await prisma.$disconnect();
  });

  test('1. Oduvar can create weekly availability', async () => {
    const res = await put(tok, {
      days: [
        weekdayDay('MONDAY', [['09:00', '18:00']]),
        weekdayDay('TUESDAY', [['09:00', '12:00'], ['17:00', '20:00']]),
        weekdayDay('WEDNESDAY', [['09:00', '18:00']], false),
      ],
      minimumDurationMinutes: 30,
      maximumDurationMinutes: 120,
      bufferMinutes: 30,
    });
    expect(res.status).toBe(200);
    const mon = res.body.data.weekly.find((d: any) => d.dayOfWeek === 'MONDAY');
    expect(mon.isActive).toBe(true);
    expect(mon.windows).toEqual([{ startTime: '09:00', endTime: '18:00' }]);
    expect(res.body.data.rules).toMatchObject({ maximumDurationMinutes: 120, bufferMinutes: 30, timezone: 'Asia/Kolkata' });
  });

  test('2. Oduvar can update weekly availability', async () => {
    const res = await put(tok, { days: [weekdayDay('MONDAY', [['10:00', '17:00']])] });
    expect(res.status).toBe(200);
    const mon = res.body.data.weekly.find((d: any) => d.dayOfWeek === 'MONDAY');
    expect(mon.windows).toEqual([{ startTime: '10:00', endTime: '17:00' }]);
    // Other days untouched
    const tue = res.body.data.weekly.find((d: any) => d.dayOfWeek === 'TUESDAY');
    expect(tue.windows).toHaveLength(2);
    // Disabled day keeps its hours but is inactive
    const wed = res.body.data.weekly.find((d: any) => d.dayOfWeek === 'WEDNESDAY');
    expect(wed.isActive).toBe(false);
    expect(wed.windows).toHaveLength(1);
  });

  test('3. Client cannot modify availability', async () => {
    expect((await put(clientTok, { bufferMinutes: 10 })).status).toBe(403);
    expect((await addOverride(clientTok, { date: MONDAY, type: 'UNAVAILABLE' })).status).toBe(403);
    expect((await request(app).get('/api/oduvars/me/availability').set(auth(clientTok))).status).toBe(403);
    expect((await request(app).put('/api/oduvars/me/availability/weekly').send({})).status).toBe(401);
  });

  test('4. Oduvar cannot modify another Oduvar\'s availability', async () => {
    const created = await addOverride(tok, { date: '2035-03-05', type: 'UNAVAILABLE' });
    const id = created.body.data.override.id;
    const upd = await request(app)
      .put(`/api/oduvars/me/availability/overrides/${id}`)
      .set(auth(tok2))
      .send({ date: '2035-03-05', type: 'UNAVAILABLE', reason: 'hijack' });
    expect(upd.status).toBe(404);
    const del = await request(app).delete(`/api/oduvars/me/availability/overrides/${id}`).set(auth(tok2));
    expect(del.status).toBe(404);
    // Two's weekly schedule is independent of one's
    const two = await request(app).get('/api/oduvars/me/availability').set(auth(tok2));
    expect(two.body.data.weekly.every((d: any) => d.windows.length === 0)).toBe(true);
    await request(app).delete(`/api/oduvars/me/availability/overrides/${id}`).set(auth(tok));
  });

  test('5. Invalid start/end time is rejected', async () => {
    expect((await put(tok, { days: [weekdayDay('MONDAY', [['18:00', '09:00']])] })).status).toBe(400);
    expect((await put(tok, { days: [weekdayDay('MONDAY', [['09:00', '09:00']])] })).status).toBe(400);
    expect((await put(tok, { days: [weekdayDay('MONDAY', [['9am', '5pm']])] })).status).toBe(400);
    expect((await put(tok, { days: [weekdayDay('MONDAY', [['09:00', '12:00'], ['11:00', '13:00']])] })).status).toBe(400);
    expect((await addOverride(tok, { date: MONDAY, type: 'UNAVAILABLE', startTime: '16:00', endTime: '14:00' })).status).toBe(400);
  });

  test('6. Minimum duration below 30 is rejected', async () => {
    const res = await put(tok, { minimumDurationMinutes: 15 });
    expect(res.status).toBe(400);
  });

  test('7. Maximum duration below minimum is rejected', async () => {
    expect((await put(tok, { minimumDurationMinutes: 60, maximumDurationMinutes: 30 })).status).toBe(400);
    // Also against the persisted minimum (30) when only max is sent
    expect((await put(tok, { minimumDurationMinutes: 60 })).status).toBe(200);
    expect((await put(tok, { maximumDurationMinutes: 45 })).status).toBe(400);
    expect((await put(tok, { minimumDurationMinutes: 30 })).status).toBe(200);
  });

  test('8. Negative buffer is rejected', async () => {
    expect((await put(tok, { bufferMinutes: -5 })).status).toBe(400);
  });

  test('9. Oduvar can create an unavailable date', async () => {
    const res = await addOverride(tok, { date: '2035-01-08', type: 'UNAVAILABLE', reason: 'Festival' });
    expect(res.status).toBe(201);
    expect(res.body.data.override).toMatchObject({ date: '2035-01-08', type: 'UNAVAILABLE', startTime: null, reason: 'Festival' });
    // Monday 2035-01-08 is blocked all day
    const d = await day('2035-01-08');
    expect(d.body.data.day.isAvailable).toBe(false);
    expect(d.body.data.day.slots).toEqual([]);
  });

  test('10. Oduvar can create an unavailable time range', async () => {
    const res = await addOverride(tok, { date: '2035-01-15', type: 'UNAVAILABLE', startTime: '12:00', endTime: '14:00' });
    expect(res.status).toBe(201);
    const d = await day('2035-01-15', 60);
    expect(d.body.data.day.workingWindows).toEqual([
      { start: '10:00', end: '12:00' },
      { start: '14:00', end: '17:00' },
    ]);
    expect(d.body.data.day.slots).not.toContain('11:30');
    expect(d.body.data.day.slots).toContain('11:00');
  });

  test('11. Oduvar can create an available override (on a day off)', async () => {
    const res = await addOverride(tok, { date: SUNDAY, type: 'AVAILABLE', startTime: '18:00', endTime: '21:00' });
    expect(res.status).toBe(201);
    const d = await day(SUNDAY, 60);
    expect(d.body.data.day.isAvailable).toBe(true);
    expect(d.body.data.day.slots).toEqual(['18:00', '18:30', '19:00', '19:30', '20:00']);
    // AVAILABLE without a time range is invalid
    expect((await addOverride(tok, { date: SUNDAY, type: 'AVAILABLE' })).status).toBe(400);
  });

  test('12. Oduvar can update an override', async () => {
    const created = await addOverride(tok, { date: '2035-02-05', type: 'UNAVAILABLE' });
    overrideId = created.body.data.override.id;
    const res = await request(app)
      .put(`/api/oduvars/me/availability/overrides/${overrideId}`)
      .set(auth(tok))
      .send({ date: '2035-02-05', type: 'UNAVAILABLE', startTime: '10:00', endTime: '11:00', reason: 'Dentist' });
    expect(res.status).toBe(200);
    expect(res.body.data.override).toMatchObject({ startTime: '10:00', endTime: '11:00', reason: 'Dentist' });
  });

  test('13. Oduvar can delete an override', async () => {
    const res = await request(app).delete(`/api/oduvars/me/availability/overrides/${overrideId}`).set(auth(tok));
    expect(res.status).toBe(200);
    const list = await request(app).get('/api/oduvars/me/availability/overrides').set(auth(tok));
    expect(list.body.data.overrides.find((o: any) => o.id === overrideId)).toBeUndefined();
  });

  test('14. Public availability endpoint works (read-only, month + day)', async () => {
    const month = await request(app).get(`/api/oduvars/${userId}/availability?month=2035-01&duration=60`);
    expect(month.status).toBe(200);
    expect(month.body.data.timezone).toBe('Asia/Kolkata');
    expect(month.body.data.days).toHaveLength(31);
    const byDate = Object.fromEntries(month.body.data.days.map((d: any) => [d.date, d.status]));
    expect(byDate['2035-01-01']).toBe('AVAILABLE'); // Monday
    expect(byDate['2035-01-03']).toBe('UNAVAILABLE'); // Wednesday (off)
    expect(byDate['2035-01-08']).toBe('UNAVAILABLE'); // blocked Monday
    expect(byDate['2035-01-07']).toBe('AVAILABLE'); // Sunday available override
    // Public payload must not leak the owner's override reasons
    expect(month.body.data.overrides).toBeUndefined();
    // Read-only
    expect((await request(app).put(`/api/oduvars/${userId}/availability`).send({})).status).toBe(404);
    // Unpublished / unknown profile
    expect((await request(app).get('/api/oduvars/00000000-0000-0000-0000-000000000000/availability')).status).toBe(404);
    // Bad query
    expect((await request(app).get(`/api/oduvars/${userId}/availability?date=nope`)).status).toBe(400);
  });

  test('15. Weekly availability is correctly resolved', async () => {
    const d = await day(MONDAY, 30);
    expect(d.body.data.day.workingWindows).toEqual([{ start: '10:00', end: '17:00' }]);
    expect(d.body.data.day.slots[0]).toBe('10:00');
    expect(d.body.data.day.slots[d.body.data.day.slots.length - 1]).toBe('16:30');
    const wed = await day('2035-01-03');
    expect(wed.body.data.day.isAvailable).toBe(false); // inactive day
  });

  test('16. Date override takes precedence over weekly', async () => {
    // Weekly Mon 10-17 replaced by an AVAILABLE 19-21 override on one Monday
    await addOverride(tok, { date: '2035-01-22', type: 'AVAILABLE', startTime: '19:00', endTime: '21:00' });
    const d = await day('2035-01-22', 60);
    expect(d.body.data.day.workingWindows).toEqual([{ start: '19:00', end: '21:00' }]);
    // UNAVAILABLE all-day beats an AVAILABLE window on the same date
    await addOverride(tok, { date: '2035-01-22', type: 'UNAVAILABLE' });
    const d2 = await day('2035-01-22', 60);
    expect(d2.body.data.day.isAvailable).toBe(false);
  });

  test('17. Fully unavailable dates return no slots', async () => {
    const d = await day('2035-01-08', 30);
    expect(d.body.data.day.slots).toEqual([]);
    expect(d.body.data.day.workingWindows).toEqual([]);
  });

  test('18. Requested duration is respected (and bounded by min/max)', async () => {
    const one = await day(TUESDAY, 60);
    const two = await day(TUESDAY, 120);
    expect(one.body.data.day.slots).toContain('11:00');
    expect(two.body.data.day.slots).not.toContain('11:00'); // 11-13 would exceed 12:00
    expect(two.body.data.day.slots).toContain('09:00');
    // Above the configured maximum (120) => rejected; below minimum => rejected
    expect((await day(TUESDAY, 180)).status).toBe(400);
    expect((await day(TUESDAY, 15)).status).toBe(400);
  });

  test('19. Slots never extend beyond working hours', async () => {
    for (const dur of [30, 60, 90, 120]) {
      const d = await day(MONDAY, dur);
      for (const s of d.body.data.day.slots as string[]) {
        const [h, m] = s.split(':').map(Number);
        expect(h * 60 + m + dur).toBeLessThanOrEqual(17 * 60);
        expect(h * 60 + m).toBeGreaterThanOrEqual(10 * 60);
      }
    }
  });

  test('20. Multiple working windows are handled independently', async () => {
    const d = await day(TUESDAY, 60);
    expect(d.body.data.day.workingWindows).toEqual([
      { start: '09:00', end: '12:00' },
      { start: '17:00', end: '20:00' },
    ]);
    expect(d.body.data.day.slots).toEqual([
      '09:00', '09:30', '10:00', '10:30', '11:00',
      '17:00', '17:30', '18:00', '18:30', '19:00',
    ]);
  });

  test('timezone is persisted and validated', async () => {
    expect((await put(tok, { timezone: 'Mars/Olympus' })).status).toBe(400);
    const ok = await put(tok, { timezone: 'Asia/Kolkata' });
    expect(ok.body.data.rules.timezone).toBe('Asia/Kolkata');
  });

  test('no booking endpoints exist in this phase', async () => {
    expect((await request(app).post('/api/bookings').set(auth(clientTok)).send({})).status).toBe(404);
  });
});
