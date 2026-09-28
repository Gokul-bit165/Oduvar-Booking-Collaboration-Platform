import request from 'supertest';
import bcrypt from 'bcryptjs';
import { Role, TransportOption } from '@prisma/client';
import { createApp } from '../src/app';
import { prisma } from '../src/config/database';
import { availabilityService } from '../src/availability/availability.service';

const app = createApp();

// Far-future Monday / Tuesday so "past" filtering never interferes.
const MONDAY = '2035-01-01';
const TUESDAY = '2035-01-02';
const MARK = 'zqxdisc'; // unique marker in test names so other DB data never interferes

async function cleanup() {
  await prisma.user.deleteMany({ where: { email: { contains: 'test.disc.' } } });
}

async function makeOduvar(opts: {
  key: string;
  name: string;
  location: string;
  published: boolean;
  performanceTypes: string[];
  songCategories?: string[];
  eventTypes?: string[];
  transport: TransportOption;
  instrumentSlug?: string;
  services?: { category: string; isActive: boolean }[];
  weekly?: [string, string];
}) {
  const user = await prisma.user.create({
    data: {
      name: opts.name,
      email: `test.disc.${opts.key}@oduvar.test`,
      phone: '+919900000000',
      passwordHash: await bcrypt.hash('TestPass#2026!', 4),
      role: Role.ODUVAR,
    },
  });
  const profile = await prisma.oduvarProfile.create({
    data: {
      userId: user.id,
      bio: 'A'.repeat(300),
      location: opts.location,
      isPublished: opts.published,
      performanceTypes: opts.performanceTypes,
      songCategories: opts.songCategories ?? [],
      eventTypes: opts.eventTypes ?? [],
      transport: opts.transport,
    },
  });
  if (opts.instrumentSlug) {
    const ins = await prisma.instrument.findUnique({ where: { slug: opts.instrumentSlug } });
    await prisma.oduvarProfileInstrument.create({ data: { profileId: profile.id, instrumentId: ins!.id } });
  }
  for (const s of opts.services ?? []) {
    const base = await prisma.service.findFirst({ where: { category: s.category } });
    await prisma.oduvarService.create({ data: { profileId: profile.id, serviceId: base!.id, isActive: s.isActive } });
  }
  if (opts.weekly) {
    await prisma.oduvarWeeklyAvailability.create({
      data: { oduvarId: profile.id, dayOfWeek: 'MONDAY', startTime: opts.weekly[0], endTime: opts.weekly[1] },
    });
  }
  return { user, profile };
}

describe('Phase 5: Oduvar discovery API', () => {
  let A: Awaited<ReturnType<typeof makeOduvar>>;
  let B: Awaited<ReturnType<typeof makeOduvar>>;
  let C: Awaited<ReturnType<typeof makeOduvar>>;
  let D: Awaited<ReturnType<typeof makeOduvar>>;
  let E: Awaited<ReturnType<typeof makeOduvar>>;

  const search = (qs: string) => request(app).get(`/api/oduvars?${qs}`);
  const ids = (res: request.Response) => res.body.data.items.map((i: any) => i.id).sort();
  const expectIds = (res: request.Response, ...oduvars: { user: { id: string } }[]) =>
    expect(ids(res)).toEqual(oduvars.map((o) => o.user.id).sort());

  beforeAll(async () => {
    await cleanup();
    A = await makeOduvar({
      key: 'a', name: `${MARK} Ravi Kumar`, location: 'Salem', published: true,
      performanceTypes: ['VOCAL'], songCategories: ['THEVARAM'], eventTypes: ['TEMPLE'],
      transport: TransportOption.INCLUDED, instrumentSlug: 'flute',
      services: [{ category: 'Thevaram', isActive: true }], weekly: ['09:00', '12:00'],
    });
    B = await makeOduvar({
      key: 'b', name: `${MARK} Ravi Shankar`, location: 'Chennai', published: true,
      performanceTypes: ['BOTH'], transport: TransportOption.ADDITIONAL_FEE, instrumentSlug: 'mridangam',
      services: [{ category: 'Thevaram', isActive: false }, { category: 'Thiruvasagam', isActive: true }],
      weekly: ['09:00', '10:00'],
    });
    C = await makeOduvar({
      key: 'c', name: `${MARK} Meena`, location: 'Salem', published: true,
      performanceTypes: ['INSTRUMENTAL'], transport: TransportOption.TO_BE_DISCUSSED,
    });
    D = await makeOduvar({
      key: 'd', name: `${MARK} Hidden Ravi`, location: 'Salem', published: false,
      performanceTypes: ['VOCAL'], transport: TransportOption.INCLUDED, instrumentSlug: 'flute',
      services: [{ category: 'Thevaram', isActive: true }], weekly: ['09:00', '18:00'],
    });
    E = await makeOduvar({
      key: 'e', name: `${MARK} Blocked`, location: 'Madurai', published: true,
      performanceTypes: ['VOCAL'], transport: TransportOption.NOT_INCLUDED, weekly: ['09:00', '18:00'],
    });
    await prisma.oduvarAvailabilityOverride.create({
      data: { oduvarId: E.profile.id, date: new Date(`${MONDAY}T00:00:00Z`), type: 'UNAVAILABLE' },
    });
  });

  afterAll(async () => {
    await cleanup();
    await prisma.$disconnect();
  });

  test('1. GET /oduvars returns published Oduvars (public, no auth)', async () => {
    const res = await search(`search=${MARK}`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expectIds(res, A, B, C, E);
    expect(res.body.data).toMatchObject({ page: 1, pageSize: 20, total: 4, hasNext: false });
  });

  test('2. Unpublished Oduvars are excluded from every search path', async () => {
    for (const qs of [`search=${MARK}`, `search=Hidden`, `location=salem&search=${MARK}`, `instrument=flute&search=${MARK}`, `service=Thevaram&search=${MARK}`]) {
      const res = await search(qs);
      expect(ids(res)).not.toContain(D.user.id);
    }
    // even the availability path
    const res = await search(`search=${MARK}&availableDate=${MONDAY}`);
    expect(ids(res)).not.toContain(D.user.id);
  });

  test('3. Search by name (partial, case-insensitive)', async () => {
    expectIds(await search(`search=${encodeURIComponent(`${MARK} ravi`)}`), A, B);
    expectIds(await search(`search=${encodeURIComponent(`${MARK.toUpperCase()} RAVI`)}`), A, B);
    expectIds(await search(`search=${encodeURIComponent(`${MARK} mee`)}`), C);
  });

  test('4. Search / filter by location', async () => {
    expectIds(await search(`search=${MARK}&location=salem`), A, C);
    expectIds(await search(`search=${MARK}&location=CHEN`), B);
    // free-text search also matches location
    const res = await search('search=Madurai');
    expect(ids(res)).toContain(E.user.id);
    expect(ids(res)).not.toContain(A.user.id);
  });

  test('5. Filter by service (category, name and id all resolve through Phase 3 data)', async () => {
    expectIds(await search(`search=${MARK}&service=Thevaram`), A);
    expectIds(await search(`search=${MARK}&service=thiruvasagam`), B);
    const base = await prisma.service.findFirst({ where: { category: 'Thiruvasagam' } });
    expectIds(await search(`search=${MARK}&service=${base!.id}`), B);
    expectIds(await search(`search=${MARK}&songCategory=thevaram`), A);
  });

  test('6. Filter by instrument (slug, name or id)', async () => {
    expectIds(await search(`search=${MARK}&instrument=flute`), A);
    expectIds(await search(`search=${MARK}&instrument=Mridangam`), B);
    const ins = await prisma.instrument.findUnique({ where: { slug: 'flute' } });
    expectIds(await search(`search=${MARK}&instrument=${ins!.id}`), A);
  });

  test('7. Filter by performance type (BOTH-profiles satisfy Vocal and Instrumental)', async () => {
    expectIds(await search(`search=${MARK}&performanceType=VOCAL`), A, B, E);
    expectIds(await search(`search=${MARK}&performanceType=instrumental`), B, C);
    expectIds(await search(`search=${MARK}&performanceType=BOTH`), B);
  });

  test('8. Filter by transport (only values configured by the Oduvar)', async () => {
    expectIds(await search(`search=${MARK}&transport=INCLUDED`), A);
    expectIds(await search(`search=${MARK}&transport=ADDITIONAL_FEE`), B);
    expectIds(await search(`search=${MARK}&transport=TO_BE_DISCUSSED`), C);
    expectIds(await search(`search=${MARK}&transport=NOT_INCLUDED`), E);
  });

  test('9. Pagination', async () => {
    const p1 = await search(`search=${MARK}&pageSize=2&page=1&sort=name`);
    const p2 = await search(`search=${MARK}&pageSize=2&page=2&sort=name`);
    const p3 = await search(`search=${MARK}&pageSize=2&page=3&sort=name`);
    expect(p1.body.data).toMatchObject({ page: 1, pageSize: 2, total: 4, hasNext: true });
    expect(p1.body.data.items).toHaveLength(2);
    expect(p2.body.data).toMatchObject({ page: 2, total: 4, hasNext: false });
    expect(p2.body.data.items).toHaveLength(2);
    expect(p3.body.data.items).toEqual([]);
    const all = [...p1.body.data.items, ...p2.body.data.items].map((i: any) => i.name);
    expect(new Set(all).size).toBe(4);
    expect(all).toEqual([...all].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })));
  });

  test('10. Empty results', async () => {
    const res = await search(`search=${MARK}-no-such-oduvar`);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ items: [], page: 1, pageSize: 20, total: 0, hasNext: false });
  });

  test('11. Public DTO does not expose private data', async () => {
    const res = await search(`search=${MARK}`);
    const raw = JSON.stringify(res.body);
    for (const forbidden of ['passwordHash', 'password', 'phone', '+9199', 'email', '@oduvar.test', 'tokenVersion', 'token', 'role']) {
      expect(raw).not.toContain(forbidden);
    }
    const item = res.body.data.items.find((i: any) => i.id === A.user.id);
    expect(Object.keys(item).sort()).toEqual([
      'bioPreview', 'collaborationEnabled', 'eventTypes', 'id', 'instruments', 'location', 'name',
      'performanceTypes', 'profileId', 'profilePhoto', 'rating', 'reviewCount', 'services',
      'skills', 'songCategories', 'transport',
    ]);
    expect(item.bioPreview.length).toBeLessThanOrEqual(141); // 140 + ellipsis
    expect(item.services).toEqual([expect.objectContaining({ category: 'Thevaram' })]);
    expect(item.instruments[0].slug).toBe('flute');
  });

  test('12. Multiple filters together', async () => {
    expectIds(await search(`search=${MARK}&location=salem&transport=INCLUDED&instrument=flute&performanceType=VOCAL&service=Thevaram`), A);
    expectIds(await search(`search=${MARK}&location=chennai&transport=INCLUDED`)); // conflicting => none
    expectIds(await search(`search=${MARK}&eventType=temple`), A); // only the Oduvar who declared it
    expectIds(await search(`search=${MARK}&eventType=FUNERAL`)); // nobody has declared this; nothing invented
  });

  test('13. Inactive services do not qualify (and re-activating restores the match)', async () => {
    // B has an INACTIVE Thevaram offering
    expect(ids(await search(`search=${MARK}&service=Thevaram`))).not.toContain(B.user.id);
    // Deactivate A's Thevaram: A drops out
    await prisma.oduvarService.updateMany({ where: { profileId: A.profile.id }, data: { isActive: false } });
    expectIds(await search(`search=${MARK}&service=Thevaram`));
    expect((await search(`search=${MARK}&service=Thevaram`)).body.data.total).toBe(0);
    await prisma.oduvarService.updateMany({ where: { profileId: A.profile.id }, data: { isActive: true } });
    expectIds(await search(`search=${MARK}&service=Thevaram`), A);
    // inactive services are also hidden from the card
    const card = (await search(`search=${MARK}`)).body.data.items.find((i: any) => i.id === B.user.id);
    expect(card.services.map((s: any) => s.category)).toEqual(['Thiruvasagam']);
  });

  test('14. Available-date filter uses real availability (not merely a weekly schedule)', async () => {
    // Monday: A (09-12) and B (09-10) work; E has a weekly window but an all-day override; C has no schedule
    expectIds(await search(`search=${MARK}&availableDate=${MONDAY}`), A, B);
    // Tuesday: nobody has a weekly rule
    expectIds(await search(`search=${MARK}&availableDate=${TUESDAY}`));
    // an AVAILABLE override on Tuesday makes C bookable that day
    await prisma.oduvarAvailabilityOverride.create({
      data: { oduvarId: C.profile.id, date: new Date(`${TUESDAY}T00:00:00Z`), type: 'AVAILABLE', startTime: '18:00', endTime: '20:00' },
    });
    expectIds(await search(`search=${MARK}&availableDate=${TUESDAY}`), C);
    // dates in the past never match
    expectIds(await search(`search=${MARK}&availableDate=2020-01-06`));
  });

  test('15. Available-duration filter respects window length and each Oduvar\'s max duration', async () => {
    expectIds(await search(`search=${MARK}&availableDate=${MONDAY}&availableDuration=60`), A, B);
    expectIds(await search(`search=${MARK}&availableDate=${MONDAY}&availableDuration=120`), A);
    expectIds(await search(`search=${MARK}&availableDate=${MONDAY}&availableDuration=240`)); // > everyone's max (180)
    // combined with another filter
    expectIds(await search(`search=${MARK}&availableDate=${MONDAY}&availableDuration=60&transport=ADDITIONAL_FEE`), B);
    // pagination applies after the availability filter
    const res = await search(`search=${MARK}&availableDate=${MONDAY}&pageSize=1&sort=name`);
    expect(res.body.data).toMatchObject({ total: 2, hasNext: true });
    expect(res.body.data.items).toHaveLength(1);
  });

  test('16. Invalid query parameters are rejected with 400', async () => {
    for (const qs of [
      'page=0', 'page=abc', 'pageSize=0', 'pageSize=1000', 'sort=bogus', 'transport=BOGUS',
      'eventType=BOGUS', 'performanceType=BOGUS', 'songCategory=BOGUS', 'minRating=9',
      'availableDate=2035-13-40', 'availableDate=tomorrow', 'availableDuration=60',
      'availableDate=2035-01-01&availableDuration=10', `search=${'x'.repeat(101)}`,
    ]) {
      const res = await search(qs);
      expect([qs, res.status]).toEqual([qs, 400]);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
    // blank params are simply ignored
    expect((await search(`search=&location=&page=&sort=`)).status).toBe(200);
  });

  test('17. Availability is computed in one batch, never per result, and only when asked for', async () => {
    const weeklySpy = jest.spyOn(prisma.oduvarWeeklyAvailability, 'findMany');
    const overrideSpy = jest.spyOn(prisma.oduvarAvailabilityOverride, 'findMany');
    const batchSpy = jest.spyOn(availabilityService, 'filterAvailableProfiles');
    const perProfileSpy = jest.spyOn(availabilityService, 'getAvailableSlots');
    try {
      // No availability filter => availability code is never touched
      await search(`search=${MARK}`);
      expect(batchSpy).not.toHaveBeenCalled();
      expect(weeklySpy).not.toHaveBeenCalled();
      expect(overrideSpy).not.toHaveBeenCalled();

      // With the filter: 5 candidate profiles share ONE batch call and one query per table
      await search(`search=${MARK}&availableDate=${MONDAY}&availableDuration=60`);
      expect(batchSpy).toHaveBeenCalledTimes(1);
      expect((batchSpy.mock.calls[0][0] as unknown[]).length).toBeGreaterThanOrEqual(4);
      expect(weeklySpy).toHaveBeenCalledTimes(1);
      expect(overrideSpy).toHaveBeenCalledTimes(1);
      expect(perProfileSpy).not.toHaveBeenCalled();
    } finally {
      jest.restoreAllMocks();
    }
  });

  test('18. Public access: no auth needed, garbage tokens do not matter, discovery is read-only', async () => {
    expect((await request(app).get('/api/oduvars')).status).toBe(200);
    expect((await request(app).get('/api/oduvars').set('Authorization', 'Bearer not-a-token')).status).toBe(200);
    for (const method of ['post', 'put', 'delete'] as const) {
      const res = await request(app)[method]('/api/oduvars').send({});
      expect(res.status).toBeGreaterThanOrEqual(400);
    }
    const ev = await request(app).get('/api/event-types');
    expect(ev.body.data.eventTypes.map((e: any) => e.key)).toEqual([
      'HOSPITAL', 'BEDRIDDEN_PATIENT', 'GENERAL', 'FUNCTION', 'TEMPLE', 'FUNERAL', 'OTHER',
    ]);
  });

  test('19. Ratings: null / 0 when no reviews; real aggregates and minRating filter when reviews exist', async () => {
    // No reviews yet
    let res = await search(`search=${MARK}`);
    for (const item of res.body.data.items) {
      expect(item.rating).toBeNull();
      expect(item.reviewCount).toBe(0);
    }
    expectIds(await search(`search=${MARK}&minRating=1`)); // nobody has a rating: nothing matches, nothing invented

    // Insert real review rows directly (the booking feature does not exist yet).
    const client = await prisma.user.create({
      data: {
        name: 'Disc Client', email: 'test.disc.client@oduvar.test', phone: '+919911111111',
        passwordHash: 'x', role: Role.CLIENT,
      },
    });
    const mk = async (oduvarId: string, rating: number) => {
      const booking = await prisma.booking.create({
        data: {
          clientId: client.id, oduvarId, date: new Date(`${MONDAY}T00:00:00Z`), startTime: '09:00', duration: 60,
          songType: 'THEVARAM', eventType: 'TEMPLE', description: 'x', location: 'x', phone1: '1', transport: 'INCLUDED',
        },
      });
      await prisma.review.create({ data: { bookingId: booking.id, clientId: client.id, oduvarId, rating, review: 'ok' } });
    };
    await mk(A.user.id, 5);
    await mk(A.user.id, 4);
    await mk(B.user.id, 3);

    res = await search(`search=${MARK}&sort=rating`);
    const items = res.body.data.items;
    expect(items[0]).toMatchObject({ id: A.user.id, rating: 4.5, reviewCount: 2 });
    expect(items[1]).toMatchObject({ id: B.user.id, rating: 3, reviewCount: 1 });
    expect(items.slice(2).every((i: any) => i.rating === null && i.reviewCount === 0)).toBe(true);

    expectIds(await search(`search=${MARK}&minRating=4`), A);
    expectIds(await search(`search=${MARK}&minRating=3`), A, B);
    expectIds(await search(`search=${MARK}&minRating=5`));
  });

  test('20. Oduvar can declare event types via the profile API; omitting them later keeps them', async () => {
    const login = await request(app).post('/api/auth/login').send({ email: 'test.disc.c@oduvar.test', password: 'x' });
    expect(login.status).toBeGreaterThanOrEqual(400); // sanity: wrong password rejected
    await prisma.user.update({
      where: { id: C.user.id },
      data: { passwordHash: await bcrypt.hash('TestPass#2026!', 4) },
    });
    const ok = await request(app).post('/api/auth/login').send({ email: 'test.disc.c@oduvar.test', password: 'TestPass#2026!' });
    const token = ok.body.data.accessToken;
    const put = (body: object) =>
      request(app).put('/api/oduvars/me/profile').set('Authorization', `Bearer ${token}`).send(body);

    let res = await put({ location: 'Salem', performanceTypes: ['INSTRUMENTAL'], isPublished: true, eventTypes: ['FUNERAL', 'HOSPITAL'] });
    expect(res.status).toBe(200);
    expect(res.body.data.profile.eventTypes.sort()).toEqual(['FUNERAL', 'HOSPITAL']);
    expectIds(await search(`search=${MARK}&eventType=funeral`), C);

    res = await put({ location: 'Salem', performanceTypes: ['INSTRUMENTAL'], isPublished: true }); // eventTypes omitted
    expect(res.body.data.profile.eventTypes.sort()).toEqual(['FUNERAL', 'HOSPITAL']);

    expect((await put({ eventTypes: ['NOT_A_TYPE'] })).status).toBe(400);
    const pub = await request(app).get(`/api/oduvars/${C.user.id}/profile`);
    expect(pub.body.data.profile.eventTypes.sort()).toEqual(['FUNERAL', 'HOSPITAL']);
  });
});
