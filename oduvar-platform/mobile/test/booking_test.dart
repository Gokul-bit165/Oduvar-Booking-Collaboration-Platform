import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import 'package:oduvar_mobile/core/storage/secure_storage_service.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/data/auth_repository.dart';
import 'package:oduvar_mobile/features/auth/data/auth_service.dart';
import 'package:oduvar_mobile/features/auth/models/auth_response_model.dart';
import 'package:oduvar_mobile/features/auth/models/user_model.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/availability/models/availability_model.dart';
import 'package:oduvar_mobile/features/bookings/data/booking_repository.dart';
import 'package:oduvar_mobile/features/bookings/models/booking_model.dart';
import 'package:oduvar_mobile/features/bookings/presentation/booking_details_screen.dart';
import 'package:oduvar_mobile/features/bookings/presentation/booking_flow_screen.dart';
import 'package:oduvar_mobile/features/bookings/presentation/booking_summary_screen.dart';
import 'package:oduvar_mobile/features/bookings/presentation/client_bookings_screen.dart';
import 'package:oduvar_mobile/features/bookings/presentation/oduvar_booking_requests_screen.dart';
import 'package:oduvar_mobile/features/bookings/widgets/booking_status_badge.dart';
import 'package:oduvar_mobile/features/services/models/service_model.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _AuthRepo implements AuthRepository {
  UserModel get _u => UserModel(
      id: 'client-1', name: 'Sundar Devotee', email: 'c@test.com', phone: '+919876543210',
      role: UserRole.client, createdAt: DateTime.now());
  @override
  Future<AuthResponseModel> login({required String email, required String password}) async =>
      AuthResponseModel(user: _u, accessToken: 't', refreshToken: 'r');
  @override
  Future<AuthResponseModel> register({required name, required email, required phone, required password, required UserRole role}) async =>
      AuthResponseModel(user: _u, accessToken: 't', refreshToken: 'r');
  @override
  Future<UserModel> getMe({required String accessToken}) async => _u;
  @override
  Future<Map<String, String>> refreshToken({required String refreshToken}) async => {'accessToken': 't', 'refreshToken': 'r'};
  @override
  Future<void> logout({required String accessToken}) async {}
}

class _Storage extends SecureStorageService {
  @override Future<void> saveTokens({required accessToken, required refreshToken}) async {}
  @override Future<String?> getAccessToken() async => 't';
  @override Future<String?> getRefreshToken() async => null;
  @override Future<void> saveUserJson(String jsonString) async {}
  @override Future<String?> getUserJson() async => null;
  @override Future<void> clearAll() async {}
}

BookingModel mk(
  String id,
  BookingStatus status, {
  String date = '2026-10-20',
  String start = '10:00',
  String client = 'Ravi Client',
  String oduvar = 'Ravi Kumar Oduvar',
  String service = 'Thevaram Recital',
  double? total = 1200,
  double? fee = 300,
  String transport = 'ADDITIONAL_FEE',
  String? reason,
}) =>
    BookingModel(
      id: id,
      status: status,
      statusReason: reason,
      oduvarId: 'oduvar-1',
      oduvarName: oduvar,
      clientId: 'client-1',
      clientName: client,
      serviceName: service,
      date: date,
      startTime: start,
      endTime: '11:00',
      durationMinutes: 60,
      eventType: 'TEMPLE',
      songType: 'Thevaram',
      description: 'Kumbabishekam at the sanctum',
      eventLocation: 'Kapaleeshwarar Temple, Mylapore, Chennai',
      phone1: '+919876543210',
      phone2: '+919876543211',
      transportOption: transport,
      price: BookingPriceModel(serviceAmount: 900, transportFee: fee, totalAmount: total, totalKnown: total != null),
    );

class MockBookingRepository extends BookingRepository {
  List<BookingModel> store;
  final List<Map<String, dynamic>> created = [];
  final List<String> calls = [];
  Object? failure;
  Completer<void>? gate;

  MockBookingRepository([List<BookingModel>? initial]) : store = initial ?? [];

  Future<void> _guard() async {
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
  }

  BookingModel _set(String id, BookingStatus s, {String? reason}) {
    final i = store.indexWhere((b) => b.id == id);
    store[i] = store[i].copyWithStatus(s, reason: reason);
    return store[i];
  }

  @override
  Future<BookingModel> createBooking(String token, Map<String, dynamic> payload) async {
    calls.add('create');
    await _guard();
    created.add(payload);
    final b = mk('new-1', BookingStatus.pending, date: payload['date'] as String, start: payload['startTime'] as String);
    store.insert(0, b);
    return b;
  }

  @override
  Future<BookingPage> listMine(String token, {List<BookingStatus>? statuses}) async {
    calls.add('listMine');
    await _guard();
    return BookingPage(items: List.of(store), total: store.length);
  }

  @override
  Future<BookingPage> listForOduvar(String token, {List<BookingStatus>? statuses}) async {
    calls.add('listForOduvar');
    await _guard();
    return BookingPage(items: List.of(store), total: store.length);
  }

  @override
  Future<BookingModel> getMine(String token, String id) async => store.firstWhere((b) => b.id == id);
  @override
  Future<BookingModel> getForOduvar(String token, String id) async => store.firstWhere((b) => b.id == id);

  @override
  Future<BookingModel> accept(String token, String id) async {
    calls.add('accept:$id');
    await _guard();
    return _set(id, BookingStatus.confirmed);
  }

  @override
  Future<BookingModel> reject(String token, String id, {String? reason}) async {
    calls.add('reject:$id');
    await _guard();
    return _set(id, BookingStatus.rejected, reason: reason);
  }

  @override
  Future<BookingModel> complete(String token, String id) async {
    calls.add('complete:$id');
    await _guard();
    return _set(id, BookingStatus.completed);
  }

  @override
  Future<BookingModel> cancel(String token, String id, {String? reason}) async {
    calls.add('cancel:$id');
    await _guard();
    return _set(id, BookingStatus.cancelled);
  }
}

class MockAvail extends AvailabilityRepository {
  final List<int?> monthDurations = [];
  final List<int?> dayDurations = [];
  @override
  Future<AvailabilityModel> getAvailability({String? token, String? oduvarId}) async => AvailabilityModel.empty();

  @override
  Future<MonthAvailability> getMonth({String? token, String? oduvarId, required String month, int? durationMinutes}) async {
    monthDurations.add(durationMinutes);
    final y = int.parse(month.substring(0, 4));
    final m = int.parse(month.substring(5, 7));
    final n = DateTime(y, m + 1, 0).day;
    return MonthAvailability(month: month, days: [
      for (var d = 1; d <= n; d++)
        CalendarDayModel(
          date: '$month-${d.toString().padLeft(2, '0')}',
          status: DateTime(y, m, d).weekday == DateTime.sunday ? DayStatus.unavailable : DayStatus.available,
        ),
    ]);
  }

  @override
  Future<DayAvailabilityModel> getDay({String? token, String? oduvarId, required String date, int? durationMinutes}) async {
    dayDurations.add(durationMinutes);
    return DayAvailabilityModel(
      date: date,
      isAvailable: true,
      durationMinutes: durationMinutes,
      workingWindows: const [TimeWindowModel(startTime: '09:00', endTime: '18:00')],
      slots: const ['09:00', '09:30', '10:00', '11:30'],
    );
  }
}

List<OduvarServiceModel> services() => const [
      OduvarServiceModel(
        id: 'os-thev', profileId: 'p', serviceId: 'b1', name: 'Thevaram Recital', category: 'Thevaram',
        transport: 'ADDITIONAL_FEE', transportFee: 300, isActive: true,
        pricings: [
          PricingModel(id: 'pr-30', oduvarServiceId: 'os-thev', durationMinutes: 30, amount: 500),
          PricingModel(id: 'pr-60', oduvarServiceId: 'os-thev', durationMinutes: 60, amount: 900),
          PricingModel(id: 'pr-90', oduvarServiceId: 'os-thev', durationMinutes: 90, amount: 1300, isActive: false),
          PricingModel(id: 'pr-120', oduvarServiceId: 'os-thev', durationMinutes: 120, amount: 1700),
        ],
      ),
      OduvarServiceModel(
        id: 'os-thiru', profileId: 'p', serviceId: 'b2', name: 'Thiruvasagam Recital', category: 'Thiruvasagam',
        transport: 'INCLUDED', isActive: true,
        pricings: [PricingModel(id: 'pr-t60', oduvarServiceId: 'os-thiru', durationMinutes: 60, amount: 1000)],
      ),
      OduvarServiceModel(
        id: 'os-tbd', profileId: 'p', serviceId: 'b3', name: 'Thirupugazh Rendition', category: 'Thirupugazh',
        transport: 'TO_BE_DISCUSSED', isActive: true,
        pricings: [PricingModel(id: 'pr-p60', oduvarServiceId: 'os-tbd', durationMinutes: 60, amount: 800)],
      ),
      OduvarServiceModel(
        id: 'os-off', profileId: 'p', serviceId: 'b4', name: 'Hidden Inactive Service', category: 'Other',
        transport: 'INCLUDED', isActive: false,
        pricings: [PricingModel(id: 'pr-o60', oduvarServiceId: 'os-off', durationMinutes: 60, amount: 1)],
      ),
    ];

// ─── Helpers ──────────────────────────────────────────────────────────────────

MaterialApp app(Widget home) => MaterialApp(theme: AppTheme.lightTheme, home: home);

void tall(WidgetTester tester, {double height = 5000}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) => tapKey(tester, 'book_next');

void main() {
  late AuthState auth;
  late MockBookingRepository bookings;
  late MockAvail avail;

  setUp(() {
    auth = AuthState(authService: AuthService(repository: _AuthRepo(), storage: _Storage()));
    auth.login(email: 'c@test.com', password: 'Password123!');
    bookings = MockBookingRepository();
    avail = MockAvail();
  });

  Future<void> pumpFlow(WidgetTester tester, {List<OduvarServiceModel>? svc}) async {
    tall(tester);
    await tester.pumpWidget(app(BookingFlowScreen(
      oduvarId: 'oduvar-1',
      oduvarName: 'Ravi Kumar Oduvar',
      services: svc ?? services(),
      authState: auth,
      bookingRepository: bookings,
      availabilityRepository: avail,
      initialMonth: DateTime(2026, 10, 1),
    )));
    await tester.pumpAndSettle();
  }

  /// Walks Service -> ... -> Review with valid data.
  Future<void> toReview(WidgetTester tester, {String service = 'os-thev', String pricing = 'pr-60'}) async {
    await tapKey(tester, 'book_service_$service');
    await next(tester);
    await tapKey(tester, 'book_duration_$pricing');
    await next(tester);
    await tapKey(tester, 'cal_day_2026-10-20');
    await next(tester);
    await tapKey(tester, 'slot_10:00');
    await next(tester);
    await tapKey(tester, 'book_event_TEMPLE');
    await tester.enterText(find.byKey(const Key('book_description')), 'Kumbabishekam at the sanctum');
    await next(tester);
    await tester.enterText(find.byKey(const Key('book_location')), 'Kapaleeshwarar Temple, Mylapore');
    await tester.enterText(find.byKey(const Key('book_phone1')), '+91 98765 43210');
    await next(tester);
    await next(tester); // transport
  }

  // 1 ─────────────────────────────────────────────────────────────────────────
  testWidgets('1. Service selection lists only active services and gates Continue', (tester) async {
    await pumpFlow(tester);
    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.byKey(const Key('book_service_os-thev')), findsOneWidget);
    expect(find.byKey(const Key('book_service_os-thiru')), findsOneWidget);
    expect(find.byKey(const Key('book_service_os-off')), findsNothing); // inactive service: not bookable
    expect(find.text('Hidden Inactive Service'), findsNothing);
    await next(tester); // nothing selected: stays on step 1
    expect(find.text('Step 1 of 8'), findsOneWidget);
    await tapKey(tester, 'book_service_os-thev');
    await next(tester);
    expect(find.text('Step 2 of 8'), findsOneWidget);
  });

  // 2 ─────────────────────────────────────────────────────────────────────────
  testWidgets('2. Duration options are exactly the service\'s priced durations', (tester) async {
    await pumpFlow(tester);
    await tapKey(tester, 'book_service_os-thev');
    await next(tester);
    expect(find.text('30 min — ₹500'), findsOneWidget);
    expect(find.text('1 hour — ₹900'), findsOneWidget);
    expect(find.text('2 hours — ₹1,700'), findsOneWidget);
    expect(find.byKey(const Key('book_duration_pr-90')), findsNothing); // inactive price: not offered
    expect(find.textContaining('1h 30m'), findsNothing);
    expect(find.byType(TextField), findsNothing); // no price input
  });

  // 3 ─────────────────────────────────────────────────────────────────────────
  testWidgets('3. Date step uses the backend calendar for the chosen duration', (tester) async {
    await pumpFlow(tester);
    await tapKey(tester, 'book_service_os-thev');
    await next(tester);
    await tapKey(tester, 'book_duration_pr-120');
    await next(tester);
    expect(find.text('Step 3 of 8'), findsOneWidget);
    expect(find.byKey(const Key('availability_calendar')), findsOneWidget);
    expect(avail.monthDurations.last, 120); // availability requested for THIS duration
    expect(find.text('October 2026'), findsOneWidget);
    // an unavailable (Sunday) date cannot be picked
    await tester.tap(find.byKey(const Key('cal_day_2026-10-18')), warnIfMissed: false); // Sunday
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.text('Step 3 of 8'), findsOneWidget);
    await tapKey(tester, 'cal_day_2026-10-20');
    await next(tester);
    expect(find.text('Step 4 of 8'), findsOneWidget);
  });

  // 4 ─────────────────────────────────────────────────────────────────────────
  testWidgets('4. Time slots come from the backend for the selected date and duration', (tester) async {
    await pumpFlow(tester);
    await tapKey(tester, 'book_service_os-thev');
    await next(tester);
    await tapKey(tester, 'book_duration_pr-60');
    await next(tester);
    await tapKey(tester, 'cal_day_2026-10-20');
    await next(tester);
    expect(avail.dayDurations.last, 60);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('11:30 AM'), findsOneWidget);
    expect(find.text('10:30 AM'), findsNothing); // not returned by the backend, so not shown
    await next(tester); // no slot chosen yet
    expect(find.text('Step 4 of 8'), findsOneWidget);
    await tapKey(tester, 'slot_10:00');
    await next(tester);
    expect(find.text('Step 5 of 8'), findsOneWidget);
  });

  // 5 + 6 ─────────────────────────────────────────────────────────────────────
  testWidgets('5/6. Event type is required and the description is validated', (tester) async {
    await pumpFlow(tester);
    await tapKey(tester, 'book_service_os-thev');
    await next(tester);
    await tapKey(tester, 'book_duration_pr-60');
    await next(tester);
    await tapKey(tester, 'cal_day_2026-10-20');
    await next(tester);
    await tapKey(tester, 'slot_10:00');
    await next(tester);

    for (final label in ['Hospital', 'Bedridden Patient', 'General', 'Function', 'Temple', 'Funeral', 'Other']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await next(tester); // nothing filled in
    expect(find.text('Step 5 of 8'), findsOneWidget);
    expect(find.byKey(const Key('event_type_error')), findsOneWidget);
    expect(find.text('Please describe the event (at least 3 characters)'), findsOneWidget);

    await tapKey(tester, 'book_event_FUNERAL');
    await tester.enterText(find.byKey(const Key('book_description')), 'ab');
    await next(tester);
    expect(find.text('Step 5 of 8'), findsOneWidget); // too short
    await tester.enterText(find.byKey(const Key('book_description')), 'Antim yatra bhajan');
    await next(tester);
    expect(find.text('Step 6 of 8'), findsOneWidget);
  });

  // 7 + 8 ─────────────────────────────────────────────────────────────────────
  testWidgets('7/8. Location and phone numbers are validated', (tester) async {
    await pumpFlow(tester);
    await toReview(tester); // fill everything once, then walk back to contact
    await tapKey(tester, 'book_back'); // transport -> contact
    await tapKey(tester, 'book_back'); // contact must still hold its values
    expect(find.text('Step 6 of 8'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Kapaleeshwarar Temple, Mylapore'), findsOneWidget); // retained

    await tester.enterText(find.byKey(const Key('book_location')), 'x');
    await tester.enterText(find.byKey(const Key('book_phone1')), '12345');
    await tester.enterText(find.byKey(const Key('book_phone2')), 'abc');
    await next(tester);
    expect(find.text('Step 6 of 8'), findsOneWidget);
    expect(find.text('Please enter the event location'), findsOneWidget);
    expect(find.text('Enter a valid phone number (10-15 digits)'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('book_location')), 'Sri Ram Hall, Salem');
    await tester.enterText(find.byKey(const Key('book_phone1')), '98765 43210');
    await tester.enterText(find.byKey(const Key('book_phone2')), '');
    await next(tester);
    expect(find.text('Step 7 of 8'), findsOneWidget); // alternate phone is optional
  });

  // 9 ─────────────────────────────────────────────────────────────────────────
  testWidgets('9. Transport step shows the Oduvar\'s terms (read-only)', (tester) async {
    await pumpFlow(tester);
    await toReview(tester);
    await tapKey(tester, 'book_back'); // review -> transport
    expect(find.text('Step 7 of 8'), findsOneWidget);
    expect(find.byKey(const Key('book_transport_card')), findsOneWidget);
    expect(find.text('Transport: ₹300'), findsOneWidget);
    expect(find.text('Transport included'), findsNothing);
  });

  // 10 + 11 ───────────────────────────────────────────────────────────────────
  testWidgets('10/11. Booking summary shows exact prices: service + transport = total', (tester) async {
    await pumpFlow(tester);
    await toReview(tester);
    expect(find.text('Step 8 of 8'), findsOneWidget);
    expect(find.text('Booking Summary'), findsOneWidget);
    expect(find.text('Ravi Kumar Oduvar'), findsWidgets);
    expect(find.text('Thevaram Recital'), findsOneWidget);
    expect(find.text('20 October 2026'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('Temple'), findsOneWidget);
    expect(find.text('Kapaleeshwarar Temple, Mylapore'), findsOneWidget);
    String textOf(String key) => tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).last).data!;
    expect(textOf('sum_service_amount'), '₹900');
    expect(textOf('sum_transport'), '₹300');
    expect(textOf('sum_total'), '₹1,200');
    expect(textOf('sum_status'), 'Ready to Send');
    expect(find.text('Send Booking Request'), findsOneWidget);
  });

  testWidgets('10b. Transport included: no fee row value, total equals the service amount', (tester) async {
    await pumpFlow(tester);
    await toReview(tester, service: 'os-thiru', pricing: 'pr-t60');
    String textOf(String key) => tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).last).data!;
    expect(textOf('sum_service_amount'), '₹1,000');
    expect(textOf('sum_transport'), 'Included');
    expect(textOf('sum_total'), '₹1,000');
  });

  // 12 ────────────────────────────────────────────────────────────────────────
  testWidgets('12. To Be Discussed: total is never invented', (tester) async {
    await pumpFlow(tester);
    await toReview(tester, service: 'os-tbd', pricing: 'pr-p60');
    String textOf(String key) => tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).last).data!;
    expect(textOf('sum_service_amount'), '₹800');
    expect(textOf('sum_transport'), 'To Be Discussed');
    expect(textOf('sum_total'), 'To Be Discussed');
  });

  // 13 ────────────────────────────────────────────────────────────────────────
  testWidgets('13. Submit sends a payload with NO amounts and opens the pending confirmation', (tester) async {
    await pumpFlow(tester);
    await toReview(tester);
    await tapKey(tester, 'book_submit');
    expect(bookings.created, hasLength(1));
    final p = bookings.created.single;
    expect(p, {
      'oduvarId': 'oduvar-1',
      'oduvarServiceId': 'os-thev',
      'servicePricingId': 'pr-60',
      'date': '2026-10-20',
      'startTime': '10:00',
      'durationMinutes': 60,
      'eventType': 'TEMPLE',
      'description': 'Kumbabishekam at the sanctum',
      'eventLocation': 'Kapaleeshwarar Temple, Mylapore',
      'phone1': '+919876543210', // normalised
      'transport': 'ADDITIONAL_FEE',
    });
    for (final k in ['amount', 'serviceAmount', 'totalAmount', 'transportFee', 'price']) {
      expect(p.containsKey(k), isFalse, reason: k);
    }
    expect(find.text('Booking request sent'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('13b. A slot conflict on submit offers to pick another time', (tester) async {
    bookings.failure = ApiException(code: 'BOOKING_CONFLICT', message: 'That time is no longer available', statusCode: 409);
    await pumpFlow(tester);
    await toReview(tester);
    await tapKey(tester, 'book_submit');
    expect(find.text('That time is no longer available'), findsOneWidget);
    expect(find.text('Step 8 of 8'), findsOneWidget); // nothing lost, still on review
    await tapKey(tester, 'choose_another_time');
    expect(find.text('Step 4 of 8'), findsOneWidget);
    expect(find.byKey(const Key('slot_list')), findsOneWidget);
  });

  // 14 ────────────────────────────────────────────────────────────────────────
  testWidgets('14. Pending booking confirmation screen', (tester) async {
    tall(tester);
    await tester.pumpWidget(app(BookingSummaryScreen(
      booking: mk('b1', BookingStatus.pending), authState: auth, bookingRepository: bookings)));
    await tester.pumpAndSettle();
    expect(find.text('Request Sent'), findsOneWidget);
    expect(find.byKey(const Key('request_sent_banner')), findsOneWidget);
    expect(find.textContaining('Waiting for Ravi Kumar Oduvar'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget); // status row of the summary
    expect(find.text('₹1,200'), findsOneWidget);
    expect(find.textContaining('Nothing is charged online'), findsOneWidget);
    expect(find.byKey(const Key('view_booking_button')), findsOneWidget);
  });

  // 15 + 16 + 17 ──────────────────────────────────────────────────────────────
  testWidgets('15. Oduvar sees pending requests with client, event, location and amount', (tester) async {
    tall(tester);
    bookings.store = [
      mk('p1', BookingStatus.pending, client: 'Ravi Client'),
      mk('p2', BookingStatus.pending, client: 'Meena Client', date: '2026-10-22'),
      mk('c1', BookingStatus.confirmed, date: '2026-10-19', client: 'Today Client'),
      mk('c2', BookingStatus.confirmed, date: '2026-10-25', client: 'Later Client'),
    ];
    await tester.pumpWidget(app(OduvarBookingRequestsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pumpAndSettle();
    expect(find.text('Pending Requests (2)'), findsOneWidget);
    expect(find.text('Ravi Client'), findsOneWidget);
    expect(find.text('Meena Client'), findsOneWidget);
    expect(find.text('Kapaleeshwarar Temple, Mylapore, Chennai'), findsWidgets);
    expect(find.text('₹1,200'), findsWidgets);
    expect(find.byKey(const Key('accept_p1')), findsOneWidget);
    expect(find.byKey(const Key('reject_p1')), findsOneWidget);
    expect(find.text("Today's Bookings (1)"), findsOneWidget);
    expect(find.text('Today Client'), findsOneWidget);
    expect(find.text('Upcoming Confirmed (1)'), findsOneWidget);
    expect(find.text('Later Client'), findsOneWidget);
  });

  testWidgets('16. Accept confirms the booking through the API', (tester) async {
    tall(tester);
    bookings.store = [mk('p1', BookingStatus.pending, date: '2026-10-25'), mk('p2', BookingStatus.pending, date: '2026-10-26', client: 'Second')];
    await tester.pumpWidget(app(OduvarBookingRequestsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'accept_p1');
    expect(bookings.calls, contains('accept:p1'));
    expect(find.text('Pending Requests (1)'), findsOneWidget);
    expect(find.text('Upcoming Confirmed (1)'), findsOneWidget);
    expect(find.byKey(const Key('status_badge_confirmed')), findsOneWidget);
  });

  testWidgets('16b. A refused accept (409 conflict) shows the reason and leaves the request pending', (tester) async {
    tall(tester);
    final refusing = _RefusingAccept([mk('p1', BookingStatus.pending, date: '2026-10-25')]);
    await tester.pumpWidget(app(OduvarBookingRequestsScreen(authState: auth, bookingRepository: refusing, today: '2026-10-19')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'accept_p1');
    expect(find.text('This time is no longer available'), findsOneWidget);
    expect(find.byKey(const Key('status_badge_pending')), findsOneWidget);
    expect(find.byKey(const Key('accept_p1')), findsOneWidget); // still actionable
  });

  testWidgets('17. Reject declines the request', (tester) async {
    tall(tester);
    bookings.store = [mk('p1', BookingStatus.pending, date: '2026-10-25')];
    await tester.pumpWidget(app(OduvarBookingRequestsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'reject_p1');
    expect(bookings.calls, contains('reject:p1'));
    expect(bookings.store.single.status, BookingStatus.rejected);
    expect(find.byKey(const Key('bookings_empty')), findsOneWidget); // nothing left to act on
    expect(find.byKey(const Key('accept_p1')), findsNothing);
  });

  // 18 ────────────────────────────────────────────────────────────────────────
  testWidgets('18. Booking details (Oduvar view): full details, contact numbers, snapshot price, actions', (tester) async {
    tall(tester);
    bookings.store = [mk('p1', BookingStatus.pending, date: '2026-10-25')];
    await tester.pumpWidget(app(BookingDetailsScreen(
      bookingId: 'p1', initial: bookings.store.single, viewer: BookingViewer.oduvar, authState: auth, bookingRepository: bookings)));
    await tester.pumpAndSettle();
    expect(find.text('Thevaram Recital'), findsOneWidget);
    expect(find.text('Ravi Client'), findsOneWidget);
    expect(find.byKey(const Key('details_phone1')), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('+919876543211'), findsOneWidget);
    expect(find.text('25 October 2026'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.text('11:00 AM'), findsOneWidget);
    expect(find.text('Kapaleeshwarar Temple, Mylapore, Chennai'), findsOneWidget);
    expect(find.text('Kumbabishekam at the sanctum'), findsOneWidget);
    expect(find.text('₹900'), findsOneWidget);
    expect(find.text('₹300'), findsOneWidget);
    expect(find.text('₹1,200'), findsOneWidget);
    expect(find.byKey(const Key('details_accept')), findsOneWidget);
    expect(find.byKey(const Key('details_cancel')), findsNothing); // client-only action

    await tapKey(tester, 'details_accept');
    expect(find.byKey(const Key('details_complete')), findsOneWidget); // now CONFIRMED
    await tapKey(tester, 'details_complete');
    expect(bookings.store.single.status, BookingStatus.completed);
  });

  testWidgets('18b. Booking details (client view): own contact, cancel with confirmation, no Oduvar actions', (tester) async {
    tall(tester);
    bookings.store = [mk('b1', BookingStatus.confirmed, date: '2026-10-25', total: null, fee: null, transport: 'TO_BE_DISCUSSED')];
    await tester.pumpWidget(app(BookingDetailsScreen(
      bookingId: 'b1', initial: bookings.store.single, viewer: BookingViewer.client, authState: auth, bookingRepository: bookings)));
    await tester.pumpAndSettle();
    expect(find.text('Your phone'), findsOneWidget);
    expect(find.text('Client'), findsNothing);
    expect(find.byKey(const Key('details_accept')), findsNothing);
    expect(find.byKey(const Key('details_complete')), findsNothing);
    expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('details_total')), matching: find.byType(Text)).last).data, 'To Be Discussed');

    await tapKey(tester, 'details_cancel');
    expect(find.text('Cancel this booking?'), findsOneWidget);
    await tapKey(tester, 'cancel_no');
    expect(bookings.calls.where((c) => c.startsWith('cancel')), isEmpty);
    await tapKey(tester, 'details_cancel');
    await tapKey(tester, 'cancel_yes');
    expect(bookings.calls, contains('cancel:b1'));
    expect(find.byKey(const Key('status_badge_cancelled')), findsOneWidget);
    expect(find.byKey(const Key('details_cancel')), findsNothing); // terminal
  });

  // 19 ────────────────────────────────────────────────────────────────────────
  testWidgets('19. Status badges: label + icon for each status', (tester) async {
    await tester.pumpWidget(app(Scaffold(
      body: Column(children: [for (final s in BookingStatus.values) BookingStatusBadge(status: s)]),
    )));
    for (final s in BookingStatus.values) {
      expect(find.byKey(Key('status_badge_${s.name}')), findsOneWidget);
      expect(find.text(s.label), findsOneWidget);
    }
    expect(find.byType(Icon), findsNWidgets(5));
    expect(bookingStatusFrom('CONFIRMED'), BookingStatus.confirmed);
    expect(bookingStatusFrom('COMPLETED').apiValue, 'COMPLETED');
  });

  // 20 ────────────────────────────────────────────────────────────────────────
  testWidgets('20. Client booking list groups Upcoming / Pending / Completed / Cancelled', (tester) async {
    tall(tester);
    bookings.store = [
      mk('u1', BookingStatus.confirmed, date: '2026-10-25', oduvar: 'Ravi Oduvar'),
      mk('u2', BookingStatus.confirmed, date: '2026-10-30', oduvar: 'Second Oduvar'),
      mk('p1', BookingStatus.pending, date: '2026-11-02', oduvar: 'Pending Oduvar'),
      mk('d1', BookingStatus.completed, date: '2026-09-01', oduvar: 'Done Oduvar'),
      mk('x1', BookingStatus.cancelled, date: '2026-10-28', oduvar: 'Cancelled Oduvar'),
      mk('x2', BookingStatus.rejected, date: '2026-10-29', oduvar: 'Rejected Oduvar'),
    ];
    await tester.pumpWidget(app(ClientBookingsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming (2)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Cancelled (2)'), findsOneWidget); // cancelled + rejected
    expect(find.text('Ravi Oduvar'), findsOneWidget);
    expect(find.text('Pending Oduvar'), findsNothing);
    await tapKey(tester, 'tab_pending');
    expect(find.text('Pending Oduvar'), findsOneWidget);
    // each card: oduvar, service, date, time, duration, amount, status
    expect(find.text('Thevaram Recital'), findsOneWidget);
    expect(find.text('2 November 2026'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('₹1,200'), findsOneWidget);
    expect(find.byKey(const Key('status_badge_pending')), findsOneWidget);
    await tapKey(tester, 'tab_cancelled');
    expect(find.text('Cancelled Oduvar'), findsOneWidget);
    expect(find.text('Rejected Oduvar'), findsOneWidget);
    // clicking a card opens details
    await tapKey(tester, 'booking_open_x1');
    expect(find.text('Booking Details'), findsOneWidget);
  });

  // 21 ────────────────────────────────────────────────────────────────────────
  testWidgets('21. Oduvar list is empty-state aware', (tester) async {
    tall(tester);
    await tester.pumpWidget(app(OduvarBookingRequestsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookings_empty')), findsOneWidget);
    expect(find.text('No booking requests yet'), findsOneWidget);
  });

  // 22 ────────────────────────────────────────────────────────────────────────
  testWidgets('22. Loading state', (tester) async {
    tall(tester);
    bookings.gate = Completer<void>();
    await tester.pumpWidget(app(ClientBookingsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('bookings_loading')), findsOneWidget);
    bookings.store = [mk('u1', BookingStatus.confirmed, date: '2026-10-25')];
    bookings.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookings_loading')), findsNothing);
    expect(find.byKey(const Key('booking_card_u1')), findsOneWidget);
  });

  // 23 ────────────────────────────────────────────────────────────────────────
  testWidgets('23. Error state with retry', (tester) async {
    tall(tester);
    bookings.failure = NetworkException();
    await tester.pumpWidget(app(ClientBookingsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookings_error')), findsOneWidget);
    bookings.failure = null;
    bookings.store = [mk('u1', BookingStatus.confirmed, date: '2026-10-25')];
    await tester.tap(find.byKey(const Key('bookings_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookings_error')), findsNothing);
    expect(find.byKey(const Key('booking_card_u1')), findsOneWidget);
  });

  // 24 ────────────────────────────────────────────────────────────────────────
  testWidgets('24. Unauthorized state (wrong role / expired session) has no retry loop', (tester) async {
    tall(tester);
    bookings.failure = ForbiddenException();
    await tester.pumpWidget(app(OduvarBookingRequestsScreen(authState: auth, bookingRepository: bookings, today: '2026-10-19')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookings_unauthorized')), findsOneWidget);
    expect(find.text('Not authorised'), findsOneWidget);
    expect(find.byKey(const Key('bookings_retry')), findsNothing);
  });

  // extras ────────────────────────────────────────────────────────────────────
  testWidgets('Changing the duration clears the date/time (availability depends on it) but keeps event details', (tester) async {
    await pumpFlow(tester);
    await toReview(tester);
    await tapKey(tester, 'book_back'); // transport
    await tapKey(tester, 'book_back'); // contact
    await tapKey(tester, 'book_back'); // event
    await tapKey(tester, 'book_back'); // time
    await tapKey(tester, 'book_back'); // date
    await tapKey(tester, 'book_back'); // duration
    expect(find.text('Step 2 of 8'), findsOneWidget);
    await tapKey(tester, 'book_duration_pr-120');
    await next(tester); // date: previous selection was for 60 minutes and is gone
    expect(find.text('Step 3 of 8'), findsOneWidget);
    await next(tester);
    expect(find.text('Step 3 of 8'), findsOneWidget); // must pick a date again
    expect(avail.monthDurations.last, 120);
  });

  test('flow state builds the payload without prices and formats money exactly', () {
    expect(formatMoney(1200), '₹1,200');
    expect(formatMoney(1234567), '₹1,234,567');
    expect(formatMoney(99.5), '₹99.50');
    expect(formatBookingDate('2026-10-05'), '5 October 2026');
    expect(formatBookingTime('00:30'), '12:30 AM');
    expect(formatBookingTime('12:00'), '12:00 PM');
    expect(bookingDurationLabel(90), '1h 30m');
  });
}

/// Repository whose accept is always refused by the "server" (409), everything else works.
class _RefusingAccept extends MockBookingRepository {
  _RefusingAccept(List<BookingModel> super.initial);

  @override
  Future<BookingModel> accept(String token, String id) async =>
      throw ApiException(code: 'BOOKING_CONFLICT', message: 'This time is no longer available', statusCode: 409);
}
