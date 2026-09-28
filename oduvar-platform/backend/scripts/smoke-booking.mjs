// End-to-end smoke test for the booking flow against a RUNNING backend over real HTTP.
//   1. start the API:   npm run build && node dist/server.js
//   2. run this:        node scripts/smoke-booking.mjs            (BASE_URL defaults to http://localhost:5000)
// It registers throw-away users, walks the whole client -> Oduvar -> client journey through the public API,
// prints each step, and deletes everything it created. Exit code 1 on the first failed expectation.
import { PrismaClient } from '@prisma/client';

const BASE = process.env.BASE_URL ?? 'http://localhost:5000';
const prisma = new PrismaClient();
const stamp = Date.now();
const PASSWORD = 'SmokeTest#2026!';
let step = 0;

const log = (msg) => console.log(`  ${String(++step).padStart(2, '0')}. ${msg}`);
function expect(cond, msg) {
  if (!cond) {
    console.error(`  ✗ FAILED: ${msg}`);
    throw new Error(msg);
  }
}

async function api(method, path, { token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, body: json, data: json.data, error: json.error };
}

/** A Monday at least 30 days out (so it is never "past" and matches the weekly rule we set). */
function futureMonday() {
  const d = new Date(Date.now() + 30 * 86400000);
  while (d.getUTCDay() !== 1) d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

async function register(role, key) {
  const email = `smoke.${key}.${stamp}@oduvar.local`;
  const r = await api('POST', '/api/auth/register', {
    body: { name: `Smoke ${key} ${stamp}`, email, phone: '+919800000000', password: PASSWORD, role },
  });
  expect(r.status === 201 || r.status === 200, `register ${key}: ${r.status} ${JSON.stringify(r.error)}`);
  const l = await api('POST', '/api/auth/login', { body: { email, password: PASSWORD } });
  expect(l.status === 200, `login ${key}`);
  return { email, token: l.data.accessToken, id: l.data.user.id };
}

async function main() {
  console.log(`Booking smoke test against ${BASE}`);
  const health = await api('GET', '/health');
  expect(health.status === 200, 'server is not reachable: start it with `node dist/server.js` first');
  log(`backend up (${health.data.version})`);

  // ── Arrange: an Oduvar with a published profile, a priced service and a Monday schedule ──
  const oduvar = await register('ODUVAR', 'oduvar');
  const client1 = await register('CLIENT', 'client1');
  const client2 = await register('CLIENT', 'client2');

  const profile = await api('POST', '/api/oduvars/me/profile', {
    token: oduvar.token,
    body: { bio: 'Smoke test Oduvar', location: 'Salem', performanceTypes: ['VOCAL'], songCategories: ['THEVARAM'], transport: 'ADDITIONAL_FEE', isPublished: true },
  });
  expect(profile.status === 200 || profile.status === 201, `profile: ${JSON.stringify(profile.error)}`);

  const catalogue = await api('GET', '/api/services');
  const thevaram = catalogue.data.services.find((s) => s.category === 'Thevaram');
  const svc = await api('POST', '/api/oduvars/me/services', {
    token: oduvar.token,
    body: { serviceId: thevaram.id, transport: 'ADDITIONAL_FEE', transportFee: 300, pricings: [{ durationMinutes: 60, amount: 900 }, { durationMinutes: 120, amount: 1700 }] },
  });
  expect(svc.status === 201, `service: ${JSON.stringify(svc.error)}`);
  const oduvarService = svc.data.service;
  const pricing60 = oduvarService.pricings.find((p) => p.durationMinutes === 60);

  const monday = futureMonday();
  const weekly = await api('PUT', '/api/oduvars/me/availability/weekly', {
    token: oduvar.token,
    body: { days: [{ dayOfWeek: 'MONDAY', isActive: true, windows: [{ startTime: '09:00', endTime: '18:00' }] }], minimumDurationMinutes: 30, maximumDurationMinutes: 180, bufferMinutes: 30 },
  });
  expect(weekly.status === 200, `weekly: ${JSON.stringify(weekly.error)}`);

  // ── Client journey ─────────────────────────────────────────────────────────
  const found = await api('GET', `/api/oduvars?search=${encodeURIComponent(`Smoke oduvar ${stamp}`)}`);
  expect(found.data.items.some((i) => i.id === oduvar.id), 'oduvar appears in discovery');
  log('client browses: Oduvar found in discovery search');

  const pub = await api('GET', `/api/oduvars/${oduvar.id}/profile`);
  expect(pub.status === 200 && pub.data.profile.location === 'Salem', 'public profile');
  log('client opens the public profile');

  const pubServices = await api('GET', `/api/oduvars/${oduvar.id}/services`);
  expect(pubServices.data.services.length === 1 && pubServices.data.services[0].pricings.length === 2, 'public services');
  log('client sees active services + prices: 1 service, 60 min ₹900 / 120 min ₹1,700');

  const before = await api('GET', `/api/oduvars/${oduvar.id}/availability?date=${monday}&duration=60`);
  expect(before.data.day.slots.includes('10:00'), '10:00 offered before booking');
  log(`client views availability for ${monday} (60 min): ${before.data.day.slots.slice(0, 4).join(', ')} …`);

  const payload = {
    oduvarId: oduvar.id, oduvarServiceId: oduvarService.id, servicePricingId: pricing60.id,
    date: monday, startTime: '10:00', durationMinutes: 60, eventType: 'TEMPLE',
    description: 'Smoke test kumbabishekam', eventLocation: 'Test Temple, Salem', phone1: '+91 98765 43210', transport: 'ADDITIONAL_FEE',
  };

  const tampered = await api('POST', '/api/bookings', { token: client1.token, body: { ...payload, totalAmount: 1 } });
  expect(tampered.status === 400, `manipulated price must be refused (got ${tampered.status})`);
  log('a client-supplied price is refused (400)');

  const created = await api('POST', '/api/bookings', { token: client1.token, body: payload });
  expect(created.status === 201, `create booking: ${created.status} ${JSON.stringify(created.error)}`);
  const booking = created.data.booking;
  expect(booking.status === 'PENDING', 'starts PENDING');
  expect(booking.price.serviceAmount === 900 && booking.price.transportFee === 300 && booking.price.totalAmount === 1200, `price ${JSON.stringify(booking.price)}`);
  log(`client submits: booking ${booking.id.slice(0, 8)} is PENDING, server priced it ₹900 + ₹300 = ₹1,200`);

  const pendingSlots = await api('GET', `/api/oduvars/${oduvar.id}/availability?date=${monday}&duration=60`);
  expect(pendingSlots.data.day.slots.includes('10:00'), 'a PENDING booking must not block the slot');
  log('while PENDING the slot is still open');

  // ── Oduvar ─────────────────────────────────────────────────────────────────
  const inbox = await api('GET', '/api/oduvars/me/bookings?status=PENDING', { token: oduvar.token });
  expect(inbox.data.items.some((b) => b.id === booking.id && b.phone1 === '+919876543210'), 'oduvar sees the request with contact details');
  log('Oduvar logs in and sees the pending request (with client contact)');

  const bogus = await api('POST', `/api/oduvars/me/bookings/${booking.id}/accept`, { token: client1.token });
  expect(bogus.status === 403, 'a client cannot accept');
  const accepted = await api('POST', `/api/oduvars/me/bookings/${booking.id}/accept`, { token: oduvar.token });
  expect(accepted.status === 200 && accepted.data.booking.status === 'CONFIRMED', `accept: ${JSON.stringify(accepted.error)}`);
  log('Oduvar accepts -> CONFIRMED');

  // ── Back to the client ─────────────────────────────────────────────────────
  const mine = await api('GET', `/api/bookings/${booking.id}`, { token: client1.token });
  expect(mine.data.booking.status === 'CONFIRMED', 'client sees CONFIRMED');
  log('client sees the booking as CONFIRMED');

  const after = await api('GET', `/api/oduvars/${oduvar.id}/availability?date=${monday}&duration=60`);
  for (const t of ['09:00', '09:30', '10:00', '10:30', '11:00']) expect(!after.data.day.slots.includes(t), `${t} should be blocked`);
  expect(after.data.day.slots.includes('11:30'), '11:30 (after the 30 min buffer) is the next start');
  log(`slot is gone: 10:00-11:00 (+30 min buffer) blocked; next start ${after.data.day.slots.find((s) => s >= '11:00')}`);

  const conflict = await api('POST', '/api/bookings', { token: client2.token, body: { ...payload, startTime: '10:30' } });
  expect(conflict.status === 409 && conflict.error.code === 'BOOKING_CONFLICT', `overlap must be refused: ${conflict.status}`);
  log('a conflicting second booking (10:30) is rejected with 409 BOOKING_CONFLICT');

  const buffer = await api('POST', '/api/bookings', { token: client2.token, body: { ...payload, startTime: '11:00' } });
  expect(buffer.status === 409, 'buffer violation (11:00) must be refused');
  log('a booking inside the 30 min buffer (11:00) is rejected with 409');

  const ok2 = await api('POST', '/api/bookings', { token: client2.token, body: { ...payload, startTime: '11:30' } });
  expect(ok2.status === 201, 'first buffer-respecting time is accepted as a request');
  log('a request at 11:30 is accepted as PENDING');

  const notes = await api('GET', '/api/notifications', { token: client1.token });
  expect(notes.data.items.some((n) => n.type === 'BOOKING_CONFIRMED'), 'client got a BOOKING_CONFIRMED notification');
  log('client has an in-app "Booking confirmed" notification');

  console.log('\n✅ Smoke test passed');
}

let failed = false;
try {
  await main();
} catch (e) {
  failed = true;
  console.error('\n❌ Smoke test failed:', e.message);
} finally {
  await prisma.user.deleteMany({ where: { email: { contains: `.${stamp}@oduvar.local` } } });
  await prisma.$disconnect();
}
process.exit(failed ? 1 : 0);
