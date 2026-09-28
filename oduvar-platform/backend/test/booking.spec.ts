import request from 'supertest';
import bcrypt from 'bcryptjs';
import { Role, TransportOption } from '@prisma/client';
import { createApp } from '../src/app';
import { prisma } from '../src/config/database';
import { computePrice } from '../src/bookings/booking.money';
import { zonedWallTimeToUtc } from '../src/bookings/booking.time';
import { assertTransition } from '../src/bookings/booking.service';

const app = createApp();
const PHONE = '+919876543210';
const SECRET_DESC = 'Kumbabishekam-private-description';

/** k-th Monday from 2035-01-01 (a Monday). Each test uses its own date so tests never interfere. */
const D = (k: number) => new Date(Date.UTC(2035, 0, 1 + 7 * k)).toISOString().slice(0, 10);

async function cleanup() {
  await prisma.user.deleteMany({ where: { email: { contains: 'test.bk.' } } });
}

async function makeUser(role: Role, key: string) {
  return prisma.user.create({
    data: {
      name: `BK ${role} ${key}`,
      email: `test.bk.${key}@oduvar.test`,
      phone: '+919000011111',
      passwordHash: await bcrypt.hash('TestPass#2026!', 4),
      role,
    },
  });
}
async function token(email: string) {
  const res = await request(app).post('/api/auth/login').send({ email, password: 'TestPass#2026!' });
  return res.body.data.accessToken as string;
}

async function makeOduvar(key: string, published = true) {
  const user = await makeUser(Role.ODUVAR, key);
  const profile = await prisma.oduvarProfile.create({
    data: { userId: user.id, isPublished: published, location: 'Salem', bufferMinutes: 30, minimumDurationMinutes: 30, maximumDurationMinutes: 180 },
  });
  await prisma.oduvarWeeklyAvailability.create({ data: { oduvarId: profile.id, dayOfWeek: 'MONDAY', startTime: '09:00', endTime: '18:00' } });
  return { user, profile, token: await token(user.email) };
}

async function addService(
  profileId: string,
  category: string,
  opts: { transport: TransportOption; fee?: number; active?: boolean; pricings: [number, number, boolean?][] }
) {
  const base = await prisma.service.findFirst({ where: { category } });
  const os = await prisma.oduvarService.create({
    data: {
      profileId, serviceId: base!.id, isActive: opts.active ?? true, transport: opts.transport,
      transportFee: opts.fee ?? null,
    },
  });
  const pricings: Record<number, string> = {};
  for (const [duration, amount, active] of opts.pricings) {
    const p = await prisma.servicePricing.create({
      data: { oduvarServiceId: os.id, durationMinutes: duration, amount, isActive: active ?? true },
    });
    pricings[duration] = p.id;
  }
  return { os, pricings, base };
}

describe('Phase 6: bookings', () => {
  let A: Awaited<ReturnType<typeof makeOduvar>>;
  let B: Awaited<ReturnType<typeof makeOduvar>>;
  let U: Awaited<ReturnType<typeof makeOduvar>>;
  let thev: Awaited<ReturnType<typeof addService>>; // ADDITIONAL_FEE 300; 30/60/120 (+ inactive 90)
  let thiru: Awaited<ReturnType<typeof addService>>; // INCLUDED
  let thirup: Awaited<ReturnType<typeof addService>>; // TO_BE_DISCUSSED
  let inactiveSvc: Awaited<ReturnType<typeof addService>>;
  let bSvc: Awaited<ReturnType<typeof addService>>;
  let c1: { user: { id: string; email: string }; token: string };
  let c2: typeof c1;
  let c3: typeof c1;
  const raceClients: (typeof c1)[] = [];

  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

  const body = (over: Record<string, unknown> = {}) => ({
    oduvarId: A.user.id,
    oduvarServiceId: thev.os.id,
    servicePricingId: thev.pricings[60],
    date: D(0),
    startTime: '10:00',
    durationMinutes: 60,
    eventType: 'TEMPLE',
    description: SECRET_DESC,
    eventLocation: 'Sri Kapaleeshwarar Temple, Chennai',
    phone1: PHONE,
    phone2: '',
    transport: 'ADDITIONAL_FEE',
    ...over,
  });
  const book = (t: string, over: Record<string, unknown> = {}) =>
    request(app).post('/api/bookings').set(auth(t.length ? t : 'x')).send(body(over));
  const create = async (t: string, over: Record<string, unknown> = {}) => {
    const res = await book(t, over);
    expect(res.status).toBe(201);
    return res.body.data.booking as any;
  };
  const accept = (id: string, t = A.token) => request(app).post(`/api/oduvars/me/bookings/${id}/accept`).set(auth(t));
  const reject = (id: string, t = A.token) => request(app).post(`/api/oduvars/me/bookings/${id}/reject`).set(auth(t)).send({ reason: 'Busy' });
  const complete = (id: string, t = A.token) => request(app).post(`/api/oduvars/me/bookings/${id}/complete`).set(auth(t));
  const cancel = (id: string, t: string) => request(app).post(`/api/bookings/${id}/cancel`).set(auth(t)).send({});
  const slots = async (date: string, duration = 60) => {
    const r = await request(app).get(`/api/oduvars/${A.user.id}/availability?date=${date}&duration=${duration}`);
    return r.body.data.day.slots as string[];
  };
  /** Move a booking's real-time instants (start, end, end+buffer) so time-dependent rules can be tested. */
  const moveInTime = (id: string, hoursFromNow: number) =>
    prisma.booking.update({
      where: { id },
      data: {
        startsAt: new Date(Date.now() + hoursFromNow * 3_600_000),
        endsAt: new Date(Date.now() + (hoursFromNow + 1) * 3_600_000),
        blocksUntil: new Date(Date.now() + (hoursFromNow + 1.5) * 3_600_000),
      },
    });
  const confirmed = async (t: string, over: Record<string, unknown>) => {
    const b = await create(t, over);
    const r = await accept(b.id);
    expect(r.status).toBe(200);
    return r.body.data.booking;
  };

  beforeAll(async () => {
    await cleanup();
    A = await makeOduvar('oduvar-a');
    B = await makeOduvar('oduvar-b');
    U = await makeOduvar('oduvar-unpublished', false);
    thev = await addService(A.profile.id, 'Thevaram', {
      transport: TransportOption.ADDITIONAL_FEE, fee: 300,
      pricings: [[30, 500], [60, 900], [90, 1300, false], [120, 1700]],
    });
    thiru = await addService(A.profile.id, 'Thiruvasagam', { transport: TransportOption.INCLUDED, pricings: [[60, 1000]] });
    thirup = await addService(A.profile.id, 'Thirupugazh', { transport: TransportOption.TO_BE_DISCUSSED, pricings: [[60, 800]] });
    inactiveSvc = await addService(A.profile.id, 'Other', { transport: TransportOption.INCLUDED, active: false, pricings: [[60, 400]] });
    bSvc = await addService(B.profile.id, 'Thevaram', { transport: TransportOption.INCLUDED, pricings: [[60, 700]] });
    await addService(U.profile.id, 'Thevaram', { transport: TransportOption.INCLUDED, pricings: [[60, 700]] });

    const mkClient = async (key: string) => {
      const user = await makeUser(Role.CLIENT, key);
      return { user, token: await token(user.email) };
    };
    c1 = await mkClient('client1');
    c2 = await mkClient('client2');
    c3 = await mkClient('client3');
    for (let i = 0; i < 5; i++) raceClients.push(await mkClient(`race${i}`));
  });

  afterAll(async () => {
    await cleanup();
    await prisma.$disconnect();
  });

  // ─── Creation & validation ─────────────────────────────────────────────────

  test('1. Client can create a valid booking (starts PENDING)', async () => {
    const res = await book(c1.token, { date: D(0) });
    expect(res.status).toBe(201);
    const b = res.body.data.booking;
    expect(b.status).toBe('PENDING');
    expect(b).toMatchObject({ date: D(0), startTime: '10:00', endTime: '11:00', durationMinutes: 60, eventType: 'TEMPLE' });
    expect(b.service.name).toBe('Thevaram Recital');
    expect(b.oduvar.id).toBe(A.user.id);
    expect(b.eventLocation).toBe('Sri Kapaleeshwarar Temple, Chennai'); // client's event location, not the profile location
  });

  test('2. Unauthenticated / non-client callers cannot create bookings', async () => {
    expect((await request(app).post('/api/bookings').send(body())).status).toBe(401);
    expect((await request(app).post('/api/bookings').set(auth(A.token)).send(body())).status).toBe(403);
    expect((await request(app).get('/api/bookings')).status).toBe(401);
  });

  test('3. Unpublished Oduvar cannot be booked', async () => {
    const res = await book(c1.token, { oduvarId: U.user.id, date: D(1) });
    expect(res.status).toBe(404);
    expect(await prisma.booking.count({ where: { oduvarId: U.user.id } })).toBe(0);
  });

  test('4. Service must belong to the Oduvar', async () => {
    const res = await book(c1.token, { date: D(1), oduvarServiceId: bSvc.os.id, servicePricingId: bSvc.pricings[60] });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('SERVICE_NOT_FOUND');
  });

  test('5. Inactive service is rejected', async () => {
    const res = await book(c1.token, { date: D(1), oduvarServiceId: inactiveSvc.os.id, servicePricingId: inactiveSvc.pricings[60] });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('SERVICE_INACTIVE');
  });

  test('6. Pricing must belong to the selected service', async () => {
    const res = await book(c1.token, { date: D(1), servicePricingId: thiru.pricings[60] });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('PRICING_NOT_FOUND');
    expect((await book(c1.token, { date: D(1), servicePricingId: '00000000-0000-4000-8000-000000000000' })).status).toBe(400);
  });

  test('7. Inactive pricing option is rejected', async () => {
    const res = await book(c1.token, { date: D(1), servicePricingId: thev.pricings[90], durationMinutes: 90 });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('PRICING_INACTIVE');
  });

  test('8. Duration must exactly match the priced option', async () => {
    for (const d of [30, 45, 90, 120]) {
      const res = await book(c1.token, { date: D(1), durationMinutes: d }); // pricing is the 60-minute one
      expect([d, res.status]).toEqual([d, 400]);
    }
    const res = await book(c1.token, { date: D(1), durationMinutes: 120 });
    expect(res.body.error.code).toBe('INVALID_DURATION');
  });

  test('9. Unavailable date is rejected (no weekly rule / override day off)', async () => {
    const tuesday = '2035-01-02';
    let res = await book(c1.token, { date: tuesday });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('SLOT_NOT_AVAILABLE');
    await prisma.oduvarAvailabilityOverride.create({
      data: { oduvarId: A.profile.id, date: new Date(`${D(2)}T00:00:00Z`), type: 'UNAVAILABLE' },
    });
    res = await book(c1.token, { date: D(2) });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('SLOT_NOT_AVAILABLE');
    expect((await book(c1.token, { date: '2020-01-06' })).body.error.code).toBe('PAST_DATE');
  });

  test('10. Unavailable time is rejected (before opening / not on the slot grid)', async () => {
    for (const t of ['08:00', '08:30', '09:15', '23:00']) {
      const res = await book(c1.token, { date: D(3), startTime: t });
      expect([t, res.status, res.body.error.code]).toEqual([t, 400, 'SLOT_NOT_AVAILABLE']);
    }
  });

  test('11. A booking that would extend past working hours is rejected', async () => {
    const res = await book(c1.token, { date: D(3), startTime: '17:30' }); // 17:30 + 60 min > 18:00
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('SLOT_NOT_AVAILABLE');
    expect((await book(c1.token, { date: D(3), startTime: '17:00' })).status).toBe(201); // ends exactly at 18:00
  });

  test('12. Buffer is respected around a confirmed booking', async () => {
    await confirmed(c1.token, { date: D(4), startTime: '10:00' }); // 10:00-11:00, buffer 30
    let res = await book(c2.token, { date: D(4), startTime: '11:00' }); // back-to-back, no buffer
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('BOOKING_CONFLICT');
    res = await book(c2.token, { date: D(4), startTime: '09:00' }); // ends 10:00, no buffer before the booking
    expect(res.status).toBe(409);
    expect((await book(c2.token, { date: D(4), startTime: '11:30' })).status).toBe(201); // first slot that respects the buffer
    const s = await slots(D(4), 60);
    expect(s).not.toContain('11:00');
    expect(s).toContain('11:30');
  });

  test('13. Overlapping a confirmed booking is rejected', async () => {
    await confirmed(c1.token, { date: D(5), startTime: '10:00' });
    for (const t of ['10:00', '10:30', '09:30']) {
      const res = await book(c2.token, { date: D(5), startTime: t });
      expect([t, res.status]).toEqual([t, 409]);
    }
  });

  test('14. A pending booking does not block the slot', async () => {
    await create(c1.token, { date: D(6), startTime: '12:00' });
    expect(await slots(D(6))).toContain('12:00');
    const second = await book(c2.token, { date: D(6), startTime: '12:00' });
    expect(second.status).toBe(201);
    // a client cannot stack duplicate active requests for the same time
    const dup = await book(c1.token, { date: D(6), startTime: '12:30' });
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('DUPLICATE_BOOKING');
  });

  test('15. Manipulated amounts are refused; nothing is created', async () => {
    const before = await prisma.booking.count({ where: { clientId: c3.user.id } });
    for (const extra of [{ totalAmount: 1 }, { serviceAmount: 1 }, { amount: 1 }, { transportFee: 0 }, { price: 1 }, { serviceAmountSnapshot: 1 }]) {
      const res = await book(c3.token, { date: D(7), ...extra });
      expect([JSON.stringify(extra), res.status]).toEqual([JSON.stringify(extra), 400]);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
    expect(await prisma.booking.count({ where: { clientId: c3.user.id } })).toBe(before);
  });

  test('16. Service amount comes from the server-side price option', async () => {
    const cases: [number, number][] = [[30, 500], [60, 900], [120, 1700]];
    for (const [i, [dur, amount]] of cases.entries()) {
      const b = await create([c1, c2, c3][i].token, { date: D(8), startTime: '09:00', servicePricingId: thev.pricings[dur], durationMinutes: dur });
      expect(b.price.serviceAmount).toBe(amount);
    }
  });

  test('17. Transport INCLUDED: total equals the service amount', async () => {
    const b = await create(c1.token, { date: D(9), oduvarServiceId: thiru.os.id, servicePricingId: thiru.pricings[60], transport: 'INCLUDED' });
    expect(b.price).toMatchObject({ serviceAmount: 1000, transportFee: null, totalAmount: 1000, totalKnown: true, currency: 'INR' });
    expect(b.transport.option).toBe('INCLUDED');
  });

  test('18. Transport ADDITIONAL_FEE: total = service + Oduvar transport fee (exact decimal math)', async () => {
    const b = await create(c1.token, { date: D(9), startTime: '15:00' });
    expect(b.price).toMatchObject({ serviceAmount: 900, transportFee: 300, totalAmount: 1200, totalKnown: true });
    // no floating point drift: 0.1 + 0.2 is exactly 0.3
    const p = computePrice('0.10', TransportOption.ADDITIONAL_FEE, '0.20');
    expect(p.totalAmount!.toString()).toBe('0.3');
    expect(Number(p.totalAmount)).toBe(0.3);
    // a stale transport acknowledgement is refused
    const stale = await book(c2.token, { date: D(9), startTime: '15:00', transport: 'INCLUDED' });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('TRANSPORT_TERMS_CHANGED');
  });

  test('19. Transport TO_BE_DISCUSSED: total is unknown, never invented', async () => {
    const b = await create(c1.token, { date: D(10), oduvarServiceId: thirup.os.id, servicePricingId: thirup.pricings[60], transport: 'TO_BE_DISCUSSED' });
    expect(b.price).toMatchObject({ serviceAmount: 800, transportFee: null, totalAmount: null, totalKnown: false });
    expect(computePrice(800, TransportOption.TO_BE_DISCUSSED, null).totalAmount).toBeNull();
    expect(computePrice(800, TransportOption.ADDITIONAL_FEE, null).totalAmount).toBeNull(); // misconfigured fee: no guess
  });

  test('20. Price snapshot is stored and survives later pricing changes', async () => {
    const b = await create(c1.token, { date: D(11) });
    const row = await prisma.booking.findUniqueOrThrow({ where: { id: b.id } });
    expect(row).toMatchObject({ serviceNameSnapshot: 'Thevaram Recital', durationSnapshot: 60, transportSnapshot: 'ADDITIONAL_FEE', currencySnapshot: 'INR' });
    expect(Number(row.serviceAmountSnapshot)).toBe(900);
    expect(Number(row.transportFeeSnapshot)).toBe(300);
    expect(Number(row.totalAmountSnapshot)).toBe(1200);

    // The Oduvar raises prices, changes transport and even deletes the price option
    await prisma.servicePricing.update({ where: { id: thev.pricings[60] }, data: { amount: 1500 } });
    await prisma.oduvarService.update({ where: { id: thev.os.id }, data: { transportFee: 450 } });
    const viewed = await request(app).get(`/api/bookings/${b.id}`).set(auth(c1.token));
    expect(viewed.body.data.booking.price).toMatchObject({ serviceAmount: 900, transportFee: 300, totalAmount: 1200 });
    // ...while a NEW booking uses the new price
    const fresh = await create(c2.token, { date: D(11), startTime: '15:00' });
    expect(fresh.price).toMatchObject({ serviceAmount: 1500, transportFee: 450, totalAmount: 1950 });
    await prisma.servicePricing.update({ where: { id: thev.pricings[60] }, data: { amount: 900 } });
    await prisma.oduvarService.update({ where: { id: thev.os.id }, data: { transportFee: 300 } });
  });

  test('timezone: wall-clock time is interpreted in the Oduvar timezone and stored as UTC instants', async () => {
    const b = await create(c1.token, { date: D(12), startTime: '10:00' });
    const row = await prisma.booking.findUniqueOrThrow({ where: { id: b.id } });
    expect(row.timezone).toBe('Asia/Kolkata');
    expect(row.startsAt!.toISOString()).toBe(`${D(12)}T04:30:00.000Z`); // 10:00 IST = 04:30 UTC
    expect(row.endsAt!.toISOString()).toBe(`${D(12)}T05:30:00.000Z`);
    expect(row.blocksUntil!.toISOString()).toBe(`${D(12)}T06:00:00.000Z`); // + 30 min buffer
    expect(zonedWallTimeToUtc('2035-07-01', 600, 'America/New_York').toISOString()).toBe('2035-07-01T14:00:00.000Z'); // EDT
    expect(zonedWallTimeToUtc('2035-01-01', 600, 'America/New_York').toISOString()).toBe('2035-01-01T15:00:00.000Z'); // EST
  });

  test('required fields and phone numbers are validated', async () => {
    for (const over of [
      { description: '' }, { eventLocation: '' }, { phone1: '12345' }, { phone1: 'abcdefghij' }, { phone2: '999' },
      { eventType: 'PARTY' }, { startTime: '9am' }, { date: 'tomorrow' },
    ]) {
      const res = await book(c3.token, { date: D(13), ...over });
      expect([JSON.stringify(over), res.status]).toEqual([JSON.stringify(over), 400]);
    }
    const ok = await book(c3.token, { date: D(13), phone1: '098765 43210', phone2: '+91 98765-43211' });
    expect(ok.status).toBe(201);
    expect(ok.body.data.booking.phone1).toBe('09876543210'); // normalised
    expect(ok.body.data.booking.phone2).toBe('+919876543211');
  });

  // ─── Reads & authorization ─────────────────────────────────────────────────

  test('21. Client can view their own booking', async () => {
    const b = await create(c1.token, { date: D(14) });
    const one = await request(app).get(`/api/bookings/${b.id}`).set(auth(c1.token));
    expect(one.status).toBe(200);
    expect(one.body.data.booking.phone1).toBe(PHONE);
    const list = await request(app).get('/api/bookings?status=PENDING').set(auth(c1.token));
    expect(list.body.data.items.map((i: any) => i.id)).toContain(b.id);
    expect(list.body.data).toMatchObject({ page: 1 });
  });

  test('22. Client cannot view another client\'s booking', async () => {
    const b = await create(c1.token, { date: D(15) });
    expect((await request(app).get(`/api/bookings/${b.id}`).set(auth(c2.token))).status).toBe(404);
    expect((await cancel(b.id, c2.token)).status).toBe(404);
    const list = await request(app).get('/api/bookings').set(auth(c2.token));
    expect(list.body.data.items.map((i: any) => i.id)).not.toContain(b.id);
  });

  test('23. Oduvar can view bookings addressed to them (with client contact details)', async () => {
    const b = await create(c1.token, { date: D(16) });
    const list = await request(app).get('/api/oduvars/me/bookings?status=PENDING').set(auth(A.token));
    expect(list.status).toBe(200);
    expect(list.body.data.items.map((i: any) => i.id)).toContain(b.id);
    const one = await request(app).get(`/api/oduvars/me/bookings/${b.id}`).set(auth(A.token));
    expect(one.body.data.booking).toMatchObject({ phone1: PHONE, description: SECRET_DESC });
    expect(one.body.data.booking.client.name).toBe('BK CLIENT client1');
    expect(JSON.stringify(one.body)).not.toContain('@oduvar.test'); // no email
  });

  test('24. An Oduvar cannot see or act on another Oduvar\'s bookings', async () => {
    const b = await create(c1.token, { date: D(17) });
    expect((await request(app).get(`/api/oduvars/me/bookings/${b.id}`).set(auth(B.token))).status).toBe(404);
    const list = await request(app).get('/api/oduvars/me/bookings').set(auth(B.token));
    expect(list.body.data.items.map((i: any) => i.id)).not.toContain(b.id);
    expect((await accept(b.id, B.token)).status).toBe(404);
    expect((await reject(b.id, B.token)).status).toBe(404);
    expect((await complete(b.id, B.token)).status).toBe(404);
    // clients cannot use the Oduvar endpoints at all
    expect((await accept(b.id, c1.token)).status).toBe(403);
    expect((await request(app).get('/api/oduvars/me/bookings').set(auth(c1.token))).status).toBe(403);
    expect((await prisma.booking.findUniqueOrThrow({ where: { id: b.id } })).status).toBe('PENDING');
  });

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  test('25. Oduvar can accept a pending booking', async () => {
    const b = await create(c1.token, { date: D(18) });
    const res = await accept(b.id);
    expect(res.status).toBe(200);
    expect(res.body.data.booking.status).toBe('CONFIRMED');
    expect(res.body.data.booking.confirmedAt).toBeTruthy();
  });

  test('26. Oduvar can reject a pending booking', async () => {
    const b = await create(c1.token, { date: D(19) });
    const res = await reject(b.id);
    expect(res.status).toBe(200);
    expect(res.body.data.booking).toMatchObject({ status: 'REJECTED', statusReason: 'Busy' });
    expect(await slots(D(19))).toContain('10:00');
  });

  test('27. A rejected booking cannot be accepted', async () => {
    const b = await create(c1.token, { date: D(20) });
    await reject(b.id);
    const res = await accept(b.id);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('INVALID_STATUS_TRANSITION');
  });

  test('28. A cancelled booking cannot be accepted', async () => {
    const b = await create(c1.token, { date: D(21) });
    expect((await cancel(b.id, c1.token)).status).toBe(200);
    const res = await accept(b.id);
    expect(res.status).toBe(409);
    expect((await prisma.booking.findUniqueOrThrow({ where: { id: b.id } })).status).toBe('CANCELLED');
  });

  test('29. A conflicting pending booking cannot be accepted', async () => {
    const first = await create(c1.token, { date: D(22), startTime: '10:00' });
    const second = await create(c2.token, { date: D(22), startTime: '10:30' }); // overlaps; both pending is fine
    expect((await accept(first.id)).status).toBe(200);
    const res = await accept(second.id);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('BOOKING_CONFLICT');
    expect((await prisma.booking.findUniqueOrThrow({ where: { id: second.id } })).status).toBe('PENDING');
  });

  test('30. Accept re-checks availability inside the confirmation (schedule changed after the request)', async () => {
    const b = await create(c1.token, { date: D(23), startTime: '10:00' });
    const ov = await prisma.oduvarAvailabilityOverride.create({
      data: { oduvarId: A.profile.id, date: new Date(`${D(23)}T00:00:00Z`), type: 'UNAVAILABLE', startTime: '09:00', endTime: '12:00' },
    });
    const res = await accept(b.id);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('BOOKING_CONFLICT');
    expect((await prisma.booking.findUniqueOrThrow({ where: { id: b.id } })).status).toBe('PENDING');
    await prisma.oduvarAvailabilityOverride.delete({ where: { id: ov.id } });
    expect((await accept(b.id)).status).toBe(200); // fine again once the schedule allows it
  });

  test('31. Client cancellation rules: pending anytime, confirmed only outside the 24h window, terminal after', async () => {
    const pending = await create(c1.token, { date: D(24) });
    const r1 = await cancel(pending.id, c1.token);
    expect(r1.status).toBe(200);
    expect(r1.body.data.booking.status).toBe('CANCELLED');

    const conf = await confirmed(c1.token, { date: D(25) });
    expect((await cancel(conf.id, c1.token)).status).toBe(200); // 2035: far outside the window

    const late = await confirmed(c2.token, { date: D(26) });
    await moveInTime(late.id, 2);
    const r3 = await cancel(late.id, c2.token);
    expect(r3.status).toBe(409);
    expect(r3.body.error.code).toBe('CANCELLATION_WINDOW_CLOSED');
    expect((await cancel(pending.id, c1.token)).status).toBe(409); // already cancelled
  });

  test('32. Completed transition: only CONFIRMED bookings, only once the event has started', async () => {
    const b = await confirmed(c1.token, { date: D(27) });
    const early = await complete(b.id);
    expect(early.status).toBe(409);
    expect(early.body.error.code).toBe('EVENT_NOT_STARTED');
    await moveInTime(b.id, -3);
    const res = await complete(b.id);
    expect(res.status).toBe(200);
    expect(res.body.data.booking).toMatchObject({ status: 'COMPLETED' });
    expect(res.body.data.booking.completedAt).toBeTruthy();
  });

  test('33. Invalid status transitions are rejected with 409', async () => {
    const done = await confirmed(c1.token, { date: D(28) });
    await moveInTime(done.id, -6);
    await complete(done.id);
    for (const attempt of [() => cancel(done.id, c1.token), () => accept(done.id), () => reject(done.id), () => complete(done.id)]) {
      const res = await attempt();
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('INVALID_STATUS_TRANSITION');
    }
    const pend = await create(c2.token, { date: D(28) });
    expect((await complete(pend.id)).status).toBe(409); // PENDING -> COMPLETED not allowed
    const rej = await create(c3.token, { date: D(28), startTime: '14:00' });
    await reject(rej.id);
    expect((await complete(rej.id)).status).toBe(409);
    // full table
    expect(() => assertTransition('REJECTED', 'CONFIRMED')).toThrow();
    expect(() => assertTransition('CANCELLED', 'CONFIRMED')).toThrow();
    expect(() => assertTransition('COMPLETED', 'CANCELLED')).toThrow();
    expect(() => assertTransition('COMPLETED', 'CONFIRMED')).toThrow();
    expect(() => assertTransition('PENDING', 'CONFIRMED')).not.toThrow();
    expect(() => assertTransition('CONFIRMED', 'COMPLETED')).not.toThrow();
  });

  // ─── Availability integration ──────────────────────────────────────────────

  test('34. A confirmed booking feeds the Phase 4 availability engine', async () => {
    const before = await slots(D(29));
    expect(before).toEqual(expect.arrayContaining(['10:00', '10:30', '11:00', '11:30']));
    await confirmed(c1.token, { date: D(29), startTime: '10:00' });
    const after = await slots(D(29));
    for (const t of ['09:00', '09:30', '10:00', '10:30', '11:00']) expect(after).not.toContain(t); // occupied + 30 min buffer both sides
    expect(after).toContain('11:30');
    // and month view flags nothing fake: still AVAILABLE (day has other slots)
    const month = await request(app).get(`/api/oduvars/${A.user.id}/availability?month=${D(29).slice(0, 7)}&duration=60`);
    expect(month.body.data.days.find((d: any) => d.date === D(29)).status).toBe('AVAILABLE');
  });

  test('35. A cancelled booking no longer blocks availability', async () => {
    const b = await confirmed(c1.token, { date: D(30), startTime: '10:00' });
    expect(await slots(D(30))).not.toContain('10:00');
    expect((await cancel(b.id, c1.token)).status).toBe(200);
    expect(await slots(D(30))).toContain('10:00');
    // and REJECTED / COMPLETED bookings never block either
    const r = await create(c2.token, { date: D(30), startTime: '12:00' });
    await reject(r.id);
    expect(await slots(D(30))).toContain('12:00');
  });

  test('discovery availability filter sees confirmed bookings via ONE batched query', async () => {
    // Make the whole day taken for A: a day with exactly one 09:00-10:00 window and a confirmed booking in it.
    const d = D(31);
    await prisma.oduvarAvailabilityOverride.create({
      data: { oduvarId: A.profile.id, date: new Date(`${d}T00:00:00Z`), type: 'AVAILABLE', startTime: '09:00', endTime: '10:00' },
    });
    const before = await request(app).get(`/api/oduvars?availableDate=${d}&availableDuration=60&search=BK`);
    expect(before.body.data.items.map((i: any) => i.id)).toContain(A.user.id);
    await confirmed(c1.token, { date: d, startTime: '09:00' });
    const spy = jest.spyOn(prisma.booking, 'findMany');
    const after = await request(app).get(`/api/oduvars?availableDate=${d}&availableDuration=60&search=BK`);
    const bookingQueries = spy.mock.calls.filter(([a]) => JSON.stringify(a?.where ?? {}).includes('CONFIRMED')).length;
    spy.mockRestore();
    expect(after.body.data.items.map((i: any) => i.id)).not.toContain(A.user.id);
    expect(bookingQueries).toBe(1);
  });

  // ─── Privacy ───────────────────────────────────────────────────────────────

  test('36. Public APIs never expose private booking data', async () => {
    await create(c1.token, { date: D(32) });
    const urls = [
      `/api/oduvars?search=BK`,
      `/api/oduvars/${A.user.id}/profile`,
      `/api/oduvars/${A.user.id}/services`,
      `/api/oduvars/${A.user.id}/availability?date=${D(32)}&duration=60`,
      `/api/oduvars/${A.user.id}/availability?month=2035-01`,
    ];
    for (const u of urls) {
      const res = await request(app).get(u);
      expect([u, res.status]).toEqual([u, 200]);
      const raw = JSON.stringify(res.body);
      for (const secret of [PHONE, '9876543210', SECRET_DESC, 'Sri Kapaleeshwarar', 'phone1', 'phone2', 'test.bk.client']) {
        expect([u, secret, raw.includes(secret)]).toEqual([u, secret, false]);
      }
    }
    expect((await request(app).get('/api/bookings')).status).toBe(401);
  });

  // ─── Notifications ─────────────────────────────────────────────────────────

  test('in-app notifications are created for both sides and can be read', async () => {
    const b = await create(c1.token, { date: D(33) });
    await accept(b.id);
    const cl = await request(app).get('/api/notifications').set(auth(c1.token));
    const types = cl.body.data.items.filter((n: any) => n.data?.bookingId === b.id).map((n: any) => n.type);
    expect(types).toEqual(expect.arrayContaining(['BOOKING_REQUEST_SENT', 'BOOKING_CONFIRMED']));
    const od = await request(app).get('/api/notifications').set(auth(A.token));
    expect(od.body.data.items.some((n: any) => n.type === 'BOOKING_REQUESTED' && n.data?.bookingId === b.id)).toBe(true);
    expect(cl.body.data.unreadCount).toBeGreaterThan(0);
    const first = cl.body.data.items[0];
    expect((await request(app).post(`/api/notifications/${first.id}/read`).set(auth(c1.token))).status).toBe(200);
    expect((await request(app).post(`/api/notifications/${first.id}/read`).set(auth(c2.token))).status).toBe(404); // not yours
    const all = await request(app).post('/api/notifications/read-all').set(auth(c1.token));
    expect(all.status).toBe(200);
    expect((await request(app).get('/api/notifications').set(auth(c1.token))).body.data.unreadCount).toBe(0);
    // reject / cancel / complete notify the right people
    const r = await create(c2.token, { date: D(33), startTime: '14:00' });
    await reject(r.id);
    const c2n = await request(app).get('/api/notifications').set(auth(c2.token));
    expect(c2n.body.data.items.some((n: any) => n.type === 'BOOKING_REJECTED')).toBe(true);
    const cx = await create(c3.token, { date: D(33), startTime: '16:00' });
    await cancel(cx.id, c3.token);
    const aN = await request(app).get('/api/notifications').set(auth(A.token));
    expect(aN.body.data.items.some((n: any) => n.type === 'BOOKING_CANCELLED' && n.data?.bookingId === cx.id)).toBe(true);
    expect((await request(app).get('/api/notifications')).status).toBe(401);
  });

  // ─── Concurrency (mandatory) ───────────────────────────────────────────────

  test('RACE: two overlapping requests accepted concurrently — exactly one becomes CONFIRMED', async () => {
    for (const round of [34, 35, 36]) {
      const a = await create(c1.token, { date: D(round), startTime: '10:00' }); // 10:00-11:00
      const b = await create(c2.token, { date: D(round), startTime: '10:30' }); // 10:30-11:30
      const results = await Promise.all([accept(a.id), accept(b.id)]);
      const codes = results.map((r) => r.status).sort();
      expect(codes).toEqual([200, 409]);
      const loser = results.find((r) => r.status === 409)!;
      expect(loser.body.error.code).toBe('BOOKING_CONFLICT');
      const rows = await prisma.booking.findMany({ where: { oduvarId: A.user.id, date: new Date(`${D(round)}T00:00:00Z`) } });
      expect(rows.filter((r) => r.status === 'CONFIRMED')).toHaveLength(1);
      expect(rows.filter((r) => r.status === 'PENDING')).toHaveLength(1); // loser stays pending, untouched
    }
  });

  test('RACE: five simultaneous accepts of mutually overlapping requests confirm exactly one', async () => {
    const d = D(37);
    const offsets = ['10:00', '10:30', '11:00', '10:00', '10:30'];
    // Different clients so the per-client duplicate rule does not interfere
    const created = await Promise.all(raceClients.map((c, i) => create(c.token, { date: d, startTime: offsets[i] })));
    const results = await Promise.all(created.map((b) => accept(b.id)));
    // 10:00-11:00, 10:30-11:30, 11:00-12:00 with a 30-minute buffer: any two of these conflict (every start is within 1h30 of the others)
    const ok = results.filter((r) => r.status === 200);
    expect(ok).toHaveLength(1);
    expect(results.filter((r) => r.status === 409)).toHaveLength(4);
    const confirmedRows = await prisma.booking.findMany({ where: { oduvarId: A.user.id, date: new Date(`${d}T00:00:00Z`), status: 'CONFIRMED' } });
    expect(confirmedRows).toHaveLength(1);
  });

  test('DB constraint: overlapping CONFIRMED rows are impossible even if application logic is bypassed', async () => {
    const d = D(38);
    const a = await create(c1.token, { date: d, startTime: '10:00' });
    const b = await create(c2.token, { date: d, startTime: '10:30' });
    await prisma.booking.update({ where: { id: a.id }, data: { status: 'CONFIRMED' } }); // straight to the DB, no availability check
    await expect(prisma.booking.update({ where: { id: b.id }, data: { status: 'CONFIRMED' } })).rejects.toThrow(/bookings_no_overlapping_confirmed|23P01|conflicting key/i);
    expect((await prisma.booking.findUniqueOrThrow({ where: { id: b.id } })).status).toBe('PENDING');
    // Non-overlapping confirmed rows are fine, and other Oduvars are independent
    const far = await create(c3.token, { date: d, startTime: '15:00' });
    await prisma.booking.update({ where: { id: far.id }, data: { status: 'CONFIRMED' } });
  });
});
