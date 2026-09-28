// LIVE end-to-end test: runs the app's real repositories and state classes (the same code the booking
// screens use) against a RUNNING backend over real HTTP. Skipped unless E2E_BASE_URL is provided:
//
//   (backend)  npm run build && node dist/server.js
//   (mobile)   flutter test test/e2e/booking_live_e2e_test.dart --dart-define=E2E_BASE_URL=http://localhost:5000
//
// It does not render widgets in a browser; see the Phase 6 report for what that leaves untested.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oduvar_mobile/core/network/api_client.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/bookings/data/booking_repository.dart';
import 'package:oduvar_mobile/features/bookings/models/booking_model.dart';
import 'package:oduvar_mobile/features/bookings/presentation/booking_flow_state.dart';
import 'package:oduvar_mobile/features/bookings/presentation/booking_state.dart';
import 'package:oduvar_mobile/features/discovery/data/discovery_repository.dart';
import 'package:oduvar_mobile/features/oduvar/data/oduvar_profile_repository.dart';
import 'package:oduvar_mobile/features/services/data/oduvar_service_repository.dart';

const _base = String.fromEnvironment('E2E_BASE_URL');

void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  const password = 'E2eTest#2026!';

  setUpAll(() {
    HttpOverrides.global = null; // allow real network inside flutter_test
  });

  late ApiClient api;

  Future<({String token, String id})> register(String role, String key) async {
    final email = 'e2e.$key.$stamp@oduvar.local';
    await api.post('/auth/register', body: {'name': 'E2E $key $stamp', 'email': email, 'phone': '+919800000000', 'password': password, 'role': role});
    final login = await api.post('/auth/login', body: {'email': email, 'password': password});
    return (token: login['accessToken'] as String, id: (login['user'] as Map)['id'] as String);
  }

  String futureMonday() {
    var d = DateTime.now().add(const Duration(days: 45));
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  test('client books, Oduvar accepts, calendar updates, conflict is refused (live backend)', () async {
    api = ApiClient(baseUrl: '$_base/api');
    final oduvar = await register('ODUVAR', 'oduvar');
    final client = await register('CLIENT', 'client1');
    final other = await register('CLIENT', 'client2');

    // ── arrange (raw API): published Oduvar with a priced service and a Monday schedule ──
    await api.post('/oduvars/me/profile', token: oduvar.token, body: {
      'bio': 'E2E', 'location': 'Salem', 'performanceTypes': ['VOCAL'], 'songCategories': ['THEVARAM'],
      'transport': 'ADDITIONAL_FEE', 'isPublished': true,
    });
    final catalogue = await api.get('/services');
    final thevaram = (catalogue['services'] as List).firstWhere((s) => s['category'] == 'Thevaram');
    await api.post('/oduvars/me/services', token: oduvar.token, body: {
      'serviceId': thevaram['id'], 'transport': 'ADDITIONAL_FEE', 'transportFee': 300,
      'pricings': [{'durationMinutes': 60, 'amount': 900}, {'durationMinutes': 120, 'amount': 1700}],
    });
    await api.put('/oduvars/me/availability/weekly', token: oduvar.token, body: {
      'days': [{'dayOfWeek': 'MONDAY', 'isActive': true, 'windows': [{'startTime': '09:00', 'endTime': '18:00'}]}],
      'minimumDurationMinutes': 30, 'maximumDurationMinutes': 180, 'bufferMinutes': 30,
    });

    // ── client: browse, open profile, view services ──
    final discovery = OduvarDiscoveryRepository(client: api);
    final found = await discovery.search(search: 'E2E oduvar $stamp');
    expect(found.items.map((i) => i.id), contains(oduvar.id));
    final profile = await OduvarProfileRepository(client: api).getPublicProfile(oduvar.id);
    expect(profile.location, 'Salem');
    final services = await OduvarServiceRepository(client: api).getPublicOduvarServices(oduvar.id);
    expect(services, hasLength(1));

    // ── client: the guided flow, driven through the real BookingFlowState ──
    final monday = futureMonday();
    final availability = AvailabilityRepository(client: api);
    final bookingRepo = BookingRepository(client: api);
    BookingFlowState newFlow(String date) => BookingFlowState(
          oduvarId: oduvar.id,
          oduvarName: profile.owner.name,
          allServices: services,
          bookingRepository: bookingRepo,
          availabilityRepository: availability,
          initialMonth: DateTime.parse(date),
        );

    Future<BookingFlowState> fillFlow(String date, String time) async {
      final flow = newFlow(date);
      flow.selectService(flow.services.single);
      expect(await flow.next(), isTrue);
      expect(flow.durationOptions.map((p) => p.durationMinutes), [60, 120]); // exactly the priced durations
      flow.selectPricing(flow.durationOptions.first);
      expect(await flow.next(), isTrue);
      expect(flow.step, BookingStep.date);
      expect(flow.timezone, 'Asia/Kolkata');
      expect(flow.monthDays(flow.currentMonthKey).firstWhere((d) => d.date == date).status.name, 'available'); // backend says so
      await flow.selectDate(date);
      expect(flow.day!.slots, contains(time)); // slots come from the backend
      expect(await flow.next(), isTrue);
      flow.selectTime(time);
      expect(await flow.next(), isTrue);
      flow.setEventType('TEMPLE');
      flow.setDescription('E2E kumbabishekam');
      expect(await flow.next(), isTrue);
      flow.setLocation('Test Temple, Salem');
      flow.setPhone1('+91 98765 43210');
      expect(await flow.next(), isTrue);
      expect(await flow.next(), isTrue); // transport
      expect(flow.step, BookingStep.review);
      return flow;
    }

    final flow = await fillFlow(monday, '10:00');
    expect(flow.toPayload().keys, isNot(contains('totalAmount')));
    final created = await flow.submit(client.token);
    expect(flow.submitError, isNull);
    expect(created, isNotNull);
    expect(created!.status, BookingStatus.pending);
    expect(created.price.totalAmount, 1200); // ₹900 + ₹300, priced by the server
    expect(created.price.totalKnown, isTrue);

    // ── Oduvar: sees the request and accepts ──
    final oduvarBookings = BookingState(repository: bookingRepo);
    await oduvarBookings.loadForOduvar(oduvar.token);
    expect(oduvarBookings.pending.map((b) => b.id), contains(created.id));
    expect(oduvarBookings.pending.first.phone1, '+919876543210');
    final accepted = await oduvarBookings.accept(oduvar.token, created.id);
    expect(accepted!.status, BookingStatus.confirmed);

    // ── client: sees CONFIRMED; calendar reflects it ──
    final clientBookings = BookingState(repository: bookingRepo);
    await clientBookings.loadForClient(client.token);
    expect(clientBookings.items.single.status, BookingStatus.confirmed);
    final day = await availability.getDay(oduvarId: oduvar.id, date: monday, durationMinutes: 60);
    expect(day.slots, isNot(contains('10:00')));
    expect(day.slots, isNot(contains('11:00'))); // inside the 30 minute buffer
    expect(day.slots, contains('11:30'));

    // ── a conflicting second booking is refused by the server ──
    final second = newFlow(monday);
    second.selectService(second.services.single);
    await second.next();
    second.selectPricing(second.durationOptions.first);
    await second.next();
    await second.selectDate(monday);
    second.selectTime('10:30'); // NOT offered any more, but force it to prove the server re-validates
    second.setEventType('TEMPLE');
    second.setDescription('Overlap attempt');
    second.setLocation('Elsewhere, Salem');
    second.setPhone1('9876543210');
    await second.goTo(BookingStep.review);
    final refused = await second.submit(other.token);
    expect(refused, isNull);
    expect(second.submitErrorKind, BookingErrorKind.conflict);

    // ── wrong-role access is reported as unauthorized ──
    final wrong = BookingState(repository: bookingRepo);
    await wrong.loadForOduvar(client.token);
    expect(wrong.errorKind, BookingErrorKind.unauthorized);
  }, skip: _base.isEmpty ? 'set --dart-define=E2E_BASE_URL=http://localhost:5000 to run against a live backend' : false, timeout: const Timeout(Duration(minutes: 2)));
}
