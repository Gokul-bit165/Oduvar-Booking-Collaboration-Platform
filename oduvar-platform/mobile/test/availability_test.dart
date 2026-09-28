import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/auth/data/auth_service.dart';
import 'package:oduvar_mobile/features/auth/data/auth_repository.dart';
import 'package:oduvar_mobile/features/auth/models/auth_response_model.dart';
import 'package:oduvar_mobile/features/auth/models/user_model.dart';
import 'package:oduvar_mobile/core/storage/secure_storage_service.dart';
import 'package:oduvar_mobile/features/availability/models/availability_model.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/availability/presentation/availability_state.dart';
import 'package:oduvar_mobile/features/availability/presentation/availability_settings_screen.dart';
import 'package:oduvar_mobile/features/availability/presentation/blocked_dates_screen.dart';
import 'package:oduvar_mobile/features/availability/presentation/block_date_screen.dart';
import 'package:oduvar_mobile/features/availability/presentation/oduvar_calendar_screen.dart';
import 'package:oduvar_mobile/features/availability/presentation/public_availability_screen.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

UserModel _makeUser() => UserModel(
      id: 'oduvar-user-1',
      name: 'Sivakumar Desikar',
      email: 'oduvar@test.com',
      phone: '+919876543210',
      role: UserRole.oduvar,
      createdAt: DateTime.now(),
    );

class MockAuthRepo implements AuthRepository {
  @override
  Future<AuthResponseModel> login({required String email, required String password}) async =>
      AuthResponseModel(user: _makeUser(), accessToken: 'test-token', refreshToken: 'test-refresh');
  @override
  Future<AuthResponseModel> register({required name, required email, required phone, required password, required UserRole role}) async =>
      AuthResponseModel(user: _makeUser(), accessToken: 'test-token', refreshToken: 'test-refresh');
  @override
  Future<UserModel> getMe({required String accessToken}) async => _makeUser();
  @override
  Future<Map<String, String>> refreshToken({required String refreshToken}) async =>
      {'accessToken': 'new_tok', 'refreshToken': 'new_ref'};
  @override
  Future<void> logout({required String accessToken}) async {}
}

class MockStorage extends SecureStorageService {
  @override Future<void> saveTokens({required accessToken, required refreshToken}) async {}
  @override Future<String?> getAccessToken() async => 'test-token';
  @override Future<String?> getRefreshToken() async => null;
  @override Future<void> saveUserJson(String jsonString) async {}
  @override Future<String?> getUserJson() async => null;
  @override Future<void> clearAll() async {}
}

AvailabilityModel _seedAvailability({List<AvailabilityOverrideModel> overrides = const []}) {
  const win = [TimeWindowModel(startTime: '09:00', endTime: '18:00')];
  return AvailabilityModel(
    rules: const BookingRulesModel(minimumDurationMinutes: 30, maximumDurationMinutes: 180, bufferMinutes: 30),
    weekly: [
      const WeeklyAvailabilityModel(dayOfWeek: 'MONDAY', isActive: true, windows: win),
      const WeeklyAvailabilityModel(dayOfWeek: 'TUESDAY', isActive: true, windows: win),
      const WeeklyAvailabilityModel(dayOfWeek: 'WEDNESDAY', isActive: false),
      const WeeklyAvailabilityModel(dayOfWeek: 'THURSDAY', isActive: true, windows: [TimeWindowModel(startTime: '09:00', endTime: '20:00')]),
      const WeeklyAvailabilityModel(dayOfWeek: 'FRIDAY', isActive: true, windows: win),
      const WeeklyAvailabilityModel(dayOfWeek: 'SATURDAY', isActive: true, windows: [TimeWindowModel(startTime: '10:00', endTime: '16:00')]),
      const WeeklyAvailabilityModel(dayOfWeek: 'SUNDAY', isActive: false),
    ],
    overrides: overrides,
  );
}

class MockAvailabilityRepository extends AvailabilityRepository {
  AvailabilityModel model = _seedAvailability();
  bool shouldFail = false;
  Object failure = Exception('Network error');
  Completer<void>? gate;
  Map<String, dynamic>? lastWeeklyPayload;
  Map<String, dynamic>? lastOverridePayload;
  final List<int?> monthDurations = [];
  final List<int?> dayDurations = [];
  int _seq = 0;

  Future<void> _maybeFail() async {
    if (gate != null) await gate!.future;
    if (shouldFail) throw failure;
  }

  @override
  Future<AvailabilityModel> getAvailability({String? token, String? oduvarId}) async {
    await _maybeFail();
    return model;
  }

  @override
  Future<AvailabilityModel> saveWeekly(String token, Map<String, dynamic> payload) async {
    await _maybeFail();
    lastWeeklyPayload = payload;
    return model;
  }

  @override
  Future<AvailabilityOverrideModel> createOverride(String token, Map<String, dynamic> payload) async {
    await _maybeFail();
    lastOverridePayload = payload;
    return AvailabilityOverrideModel(
      id: 'ov-${++_seq}',
      date: payload['date'] as String,
      type: payload['type'] as String,
      startTime: payload['startTime'] as String?,
      endTime: payload['endTime'] as String?,
      reason: payload['reason'] as String?,
    );
  }

  @override
  Future<AvailabilityOverrideModel> updateOverride(String token, String id, Map<String, dynamic> payload) async {
    await _maybeFail();
    lastOverridePayload = payload;
    return AvailabilityOverrideModel(
      id: id,
      date: payload['date'] as String,
      type: payload['type'] as String,
      startTime: payload['startTime'] as String?,
      endTime: payload['endTime'] as String?,
      reason: payload['reason'] as String?,
    );
  }

  @override
  Future<void> deleteOverride(String token, String id) async {
    await _maybeFail();
  }

  /// October 2026: Wednesdays and Sundays unavailable, everything else available.
  @override
  Future<MonthAvailability> getMonth({String? token, String? oduvarId, required String month, int? durationMinutes}) async {
    await _maybeFail();
    monthDurations.add(durationMinutes);
    final y = int.parse(month.substring(0, 4));
    final m = int.parse(month.substring(5, 7));
    final count = DateTime(y, m + 1, 0).day;
    return MonthAvailability(month: month, days: [
      for (var d = 1; d <= count; d++)
        CalendarDayModel(
          date: '$month-${d.toString().padLeft(2, '0')}',
          status: (DateTime(y, m, d).weekday == DateTime.wednesday || DateTime(y, m, d).weekday == DateTime.sunday)
              ? DayStatus.unavailable
              : DayStatus.available,
        ),
    ]);
  }

  @override
  Future<DayAvailabilityModel> getDay({String? token, String? oduvarId, required String date, int? durationMinutes}) async {
    await _maybeFail();
    dayDurations.add(durationMinutes);
    final slots = (durationMinutes ?? 30) >= 120
        ? ['09:00', '09:30', '10:00']
        : ['09:00', '09:30', '10:00', '10:30'];
    return DayAvailabilityModel(
      date: date,
      isAvailable: true,
      durationMinutes: durationMinutes,
      workingWindows: const [TimeWindowModel(startTime: '09:00', endTime: '18:00')],
      slots: slots,
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

MaterialApp createTestApp(Widget home) => MaterialApp(theme: AppTheme.lightTheme, home: home);

void setMobileScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pickDropdown(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<AvailabilityState> loadedState(MockAvailabilityRepository repo) async {
  final s = AvailabilityState(repository: repo);
  await s.load(token: 'tok');
  return s;
}

void main() {
  late AuthState authState;

  setUp(() {
    authState = AuthState(authService: AuthService(repository: MockAuthRepo(), storage: MockStorage()));
    authState.login(email: 'oduvar@test.com', password: 'Password123!');
  });

  Future<(MockAvailabilityRepository, AvailabilityState)> pumpSettings(WidgetTester tester) async {
    setMobileScreen(tester);
    final repo = MockAvailabilityRepository();
    final state = AvailabilityState(repository: repo);
    await tester.pumpWidget(createTestApp(
      AvailabilitySettingsScreen(availabilityState: state, authState: authState),
    ));
    await tester.pumpAndSettle();
    return (repo, state);
  }

  // ─── 1. Availability Settings renders ────────────────────────────────────
  testWidgets('1. Availability Settings renders', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Availability'), findsOneWidget);
    expect(find.byKey(const Key('timezone_note')), findsOneWidget);
    expect(find.textContaining('Asia/Kolkata'), findsOneWidget);
    expect(find.byKey(const Key('min_duration_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('max_duration_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('buffer_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('open_blocked_dates')), findsOneWidget);
    expect(find.byKey(const Key('open_calendar')), findsOneWidget);
    expect(find.byKey(const Key('save_availability_button')), findsOneWidget);
  });

  // ─── 2. Weekly schedule renders ──────────────────────────────────────────
  testWidgets('2. Weekly schedule renders all seven days with their hours', (tester) async {
    await pumpSettings(tester);
    for (final d in kDaysOfWeek) {
      expect(find.byKey(Key('day_card_$d')), findsOneWidget);
    }
    expect(find.byKey(const Key('day_state_MONDAY')), findsOneWidget);
    final monState = tester.widget<Text>(find.byKey(const Key('day_state_MONDAY')));
    expect(monState.data, 'ON');
    final wedState = tester.widget<Text>(find.byKey(const Key('day_state_WEDNESDAY')));
    expect(wedState.data, 'OFF');
    expect(find.byKey(const Key('start_MONDAY_0')), findsOneWidget);
    expect(find.byKey(const Key('start_WEDNESDAY_0')), findsNothing);
    expect(find.text('Unavailable'), findsNWidgets(2)); // Wednesday, Sunday
  });

  // ─── 3. Day enable/disable ───────────────────────────────────────────────
  testWidgets('3. Day can be enabled and disabled', (tester) async {
    await pumpSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('day_switch_WEDNESDAY')));
    await tester.tap(find.byKey(const Key('day_switch_WEDNESDAY')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('day_state_WEDNESDAY'))).data, 'ON');
    expect(find.byKey(const Key('start_WEDNESDAY_0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('day_switch_MONDAY')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('day_state_MONDAY'))).data, 'OFF');
    expect(find.byKey(const Key('start_MONDAY_0')), findsNothing);
  });

  // ─── 4. Start time selection ─────────────────────────────────────────────
  testWidgets('4. Start time can be selected and is saved', (tester) async {
    final (repo, _) = await pumpSettings(tester);
    await pickDropdown(tester, const Key('start_MONDAY_0'), '10:00 AM');
    await tester.ensureVisible(find.byKey(const Key('save_availability_button')));
    await tester.tap(find.byKey(const Key('save_availability_button')));
    await tester.pumpAndSettle();
    final mon = (repo.lastWeeklyPayload!['days'] as List).firstWhere((d) => d['dayOfWeek'] == 'MONDAY');
    expect(mon['windows'][0]['startTime'], '10:00');
    expect(mon['windows'][0]['endTime'], '18:00');
  });

  // ─── 5. End time selection ───────────────────────────────────────────────
  testWidgets('5. End time can be selected and is saved', (tester) async {
    final (repo, _) = await pumpSettings(tester);
    await pickDropdown(tester, const Key('end_TUESDAY_0'), '5:00 PM');
    await tester.ensureVisible(find.byKey(const Key('save_availability_button')));
    await tester.tap(find.byKey(const Key('save_availability_button')));
    await tester.pumpAndSettle();
    final tue = (repo.lastWeeklyPayload!['days'] as List).firstWhere((d) => d['dayOfWeek'] == 'TUESDAY');
    expect(tue['windows'][0]['endTime'], '17:00');
  });

  // ─── 6. Invalid range validation ─────────────────────────────────────────
  testWidgets('6. Invalid time range shows an error and blocks saving', (tester) async {
    final (repo, _) = await pumpSettings(tester);
    await pickDropdown(tester, const Key('start_MONDAY_0'), '7:00 PM'); // end is 6:00 PM
    expect(find.byKey(const Key('day_error_MONDAY')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('save_availability_button')));
    final btn = tester.widget<ElevatedButton>(find.byKey(const Key('save_availability_button')));
    expect(btn.onPressed, isNull);
    expect(repo.lastWeeklyPayload, isNull);
  });

  // ─── 7. Minimum duration ─────────────────────────────────────────────────
  testWidgets('7. Minimum duration setting (never below 30 min) is saved', (tester) async {
    final (repo, _) = await pumpSettings(tester);
    // Options offered start at 30 minutes; nothing lower is selectable.
    await tester.ensureVisible(find.byKey(const Key('min_duration_dropdown')));
    await tester.tap(find.byKey(const Key('min_duration_dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('15 min'), findsNothing);
    await tester.tap(find.text('1 hour').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_availability_button')));
    await tester.pumpAndSettle();
    expect(repo.lastWeeklyPayload!['minimumDurationMinutes'], 60);
  });

  // ─── 8. Maximum duration ─────────────────────────────────────────────────
  testWidgets('8. Maximum duration setting is saved; max below min is rejected in the UI', (tester) async {
    final (repo, _) = await pumpSettings(tester);
    await pickDropdown(tester, const Key('max_duration_dropdown'), '4 hours');
    await tester.ensureVisible(find.byKey(const Key('save_availability_button')));
    await tester.tap(find.byKey(const Key('save_availability_button')));
    await tester.pumpAndSettle();
    expect(repo.lastWeeklyPayload!['maximumDurationMinutes'], 240);

    // min 2 hours, max 1 hour => inline error, save disabled
    await pickDropdown(tester, const Key('min_duration_dropdown'), '2 hours');
    await pickDropdown(tester, const Key('max_duration_dropdown'), '1 hour');
    expect(find.byKey(const Key('rules_error')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('save_availability_button')));
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('save_availability_button'))).onPressed, isNull);
  });

  // ─── 9. Buffer setting ───────────────────────────────────────────────────
  testWidgets('9. Buffer setting is saved', (tester) async {
    final (repo, _) = await pumpSettings(tester);
    await pickDropdown(tester, const Key('buffer_dropdown'), '45 min');
    await tester.ensureVisible(find.byKey(const Key('save_availability_button')));
    await tester.tap(find.byKey(const Key('save_availability_button')));
    await tester.pumpAndSettle();
    expect(repo.lastWeeklyPayload!['bufferMinutes'], 45);
  });

  // ─── 10. Blocked date creation ───────────────────────────────────────────
  testWidgets('10. Blocked date can be created', (tester) async {
    setMobileScreen(tester);
    final repo = MockAvailabilityRepository();
    final state = await loadedState(repo);
    await tester.pumpWidget(createTestApp(BlockDateScreen(
      availabilityState: state,
      authState: authState,
      initialDate: DateTime(2026, 10, 20),
    )));
    await tester.pumpAndSettle();
    expect(find.text('October 20, 2026'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('override_reason')), 'Festival');
    await tester.tap(find.byKey(const Key('save_override_button')));
    await tester.pumpAndSettle();
    expect(repo.lastOverridePayload, {
      'date': '2026-10-20',
      'type': 'UNAVAILABLE',
      'startTime': null,
      'endTime': null,
      'reason': 'Festival',
    });
    expect(state.overrides.single.date, '2026-10-20');
  });

  // ─── 11. Override editing ────────────────────────────────────────────────
  testWidgets('11. Override can be edited', (tester) async {
    setMobileScreen(tester);
    final repo = MockAvailabilityRepository();
    repo.model = _seedAvailability(overrides: const [
      AvailabilityOverrideModel(id: 'ov-a', date: '2026-10-22', type: 'UNAVAILABLE', startTime: '14:00', endTime: '17:00'),
    ]);
    final state = await loadedState(repo);
    await tester.pumpWidget(createTestApp(BlockedDatesScreen(availabilityState: state, authState: authState)));
    await tester.pumpAndSettle();
    expect(find.text('October 22'), findsOneWidget);
    expect(find.text('Unavailable 2:00 PM – 5:00 PM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit_override_ov-a')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Blocked Time'), findsOneWidget);
    await pickDropdown(tester, const Key('override_end'), '6:00 PM');
    await tester.tap(find.byKey(const Key('save_override_button')));
    await tester.pumpAndSettle();

    expect(repo.lastOverridePayload!['endTime'], '18:00');
    expect(find.text('Unavailable 2:00 PM – 6:00 PM'), findsOneWidget);
  });

  // ─── 12. Override deletion ───────────────────────────────────────────────
  testWidgets('12. Override can be deleted after confirmation', (tester) async {
    setMobileScreen(tester);
    final repo = MockAvailabilityRepository();
    repo.model = _seedAvailability(overrides: const [
      AvailabilityOverrideModel(id: 'ov-a', date: '2026-10-20', type: 'UNAVAILABLE'),
      AvailabilityOverrideModel(id: 'ov-b', date: '2026-10-25', type: 'AVAILABLE', startTime: '18:00', endTime: '21:00'),
    ]);
    final state = await loadedState(repo);
    await tester.pumpWidget(createTestApp(BlockedDatesScreen(availabilityState: state, authState: authState)));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable all day'), findsOneWidget);
    expect(find.text('Available 6:00 PM – 9:00 PM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_override_ov-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('override_card_ov-a')), findsNothing);
    expect(find.byKey(const Key('override_card_ov-b')), findsOneWidget);
  });

  // ─── 13. Calendar rendering ──────────────────────────────────────────────
  testWidgets('13. Calendar renders month, weekday headers and legend', (tester) async {
    setMobileScreen(tester);
    final state = AvailabilityState(repository: MockAvailabilityRepository());
    await tester.pumpWidget(createTestApp(OduvarCalendarScreen(
      availabilityState: state,
      authState: authState,
      initialMonth: DateTime(2026, 10, 1),
    )));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    for (var d = 1; d <= 31; d++) {
      expect(find.byKey(Key('cal_day_2026-10-${d.toString().padLeft(2, '0')}')), findsOneWidget);
    }
    expect(find.byKey(const Key('calendar_legend')), findsOneWidget);
    // Legend labels + BOOKED/PENDING are not faked
    expect(find.text('Booked'), findsNothing);
    expect(find.text('Pending'), findsNothing);
  });

  // ─── 14. Available date rendering ────────────────────────────────────────
  testWidgets('14. Available dates show an icon and accessible label, not just colour', (tester) async {
    setMobileScreen(tester);
    final state = AvailabilityState(repository: MockAvailabilityRepository());
    await tester.pumpWidget(createTestApp(OduvarCalendarScreen(
      availabilityState: state, authState: authState, initialMonth: DateTime(2026, 10, 1))));
    await tester.pumpAndSettle();
    // Oct 20, 2026 is a Tuesday => available
    final cell = find.byKey(const Key('cal_day_2026-10-20'));
    expect(find.descendant(of: cell, matching: find.byIcon(Icons.check_circle_outline)), findsOneWidget);
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('October 20, Available')), findsOneWidget);
    handle.dispose();
  });

  // ─── 15. Unavailable date rendering ──────────────────────────────────────
  testWidgets('15. Unavailable dates show a block icon and accessible label', (tester) async {
    setMobileScreen(tester);
    final state = AvailabilityState(repository: MockAvailabilityRepository());
    await tester.pumpWidget(createTestApp(OduvarCalendarScreen(
      availabilityState: state, authState: authState, initialMonth: DateTime(2026, 10, 1))));
    await tester.pumpAndSettle();
    // Oct 21, 2026 is a Wednesday => unavailable
    final cell = find.byKey(const Key('cal_day_2026-10-21'));
    expect(find.descendant(of: cell, matching: find.byIcon(Icons.block)), findsOneWidget);
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('October 21, Unavailable')), findsOneWidget);
    handle.dispose();
  });

  // ─── 16. Slot rendering ──────────────────────────────────────────────────
  testWidgets('16. Selecting an available date shows backend-generated slots; duration reloads them', (tester) async {
    setMobileScreen(tester);
    final repo = MockAvailabilityRepository();
    final state = AvailabilityState(repository: repo);
    String? picked;
    await tester.pumpWidget(createTestApp(PublicAvailabilityScreen(
      oduvarId: 'oduvar-user-1',
      availabilityState: state,
      initialMonth: DateTime(2026, 10, 1),
      onSlotSelected: (date, time, d) => picked = '$date $time $d',
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('duration_selector')), findsOneWidget);
    expect(find.byKey(const Key('duration_30')), findsOneWidget);
    expect(find.byKey(const Key('duration_180')), findsOneWidget);
    expect(find.byKey(const Key('duration_210')), findsNothing); // above the Oduvar's maximum
    expect(find.byKey(const Key('public_timezone_note')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cal_day_2026-10-20')));
    await tester.pumpAndSettle();
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('10:30 AM'), findsOneWidget);
    expect(repo.dayDurations.last, 30);

    // Unavailable day is not selectable in the client flow
    await tester.tap(find.byKey(const Key('cal_day_2026-10-21')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.dayDurations.length, 1);

    // Longer duration re-requests slots from the backend
    await tester.tap(find.byKey(const Key('duration_120')));
    await tester.pumpAndSettle();
    expect(repo.dayDurations.last, 120);
    expect(find.text('10:30 AM'), findsNothing);
    expect(repo.monthDurations.last, 120);

    await tester.tap(find.byKey(const Key('slot_09:30')));
    await tester.pumpAndSettle();
    expect(picked, '2026-10-20 09:30 120');
  });

  // ─── 17. Loading state ───────────────────────────────────────────────────
  testWidgets('17. Loading state is shown while availability loads', (tester) async {
    setMobileScreen(tester);
    final repo = MockAvailabilityRepository()..gate = Completer<void>();
    final state = AvailabilityState(repository: repo);
    await tester.pumpWidget(createTestApp(
      AvailabilitySettingsScreen(availabilityState: state, authState: authState)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('availability_loading')), findsOneWidget);
    expect(find.byKey(const Key('save_availability_button')), findsNothing);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('availability_loading')), findsNothing);
    expect(find.byKey(const Key('save_availability_button')), findsOneWidget);
  });

  // ─── 18. Error state ─────────────────────────────────────────────────────
  testWidgets('18. Error states: network failure with retry, unauthorized without', (tester) async {
    setMobileScreen(tester);
    final repo = MockAvailabilityRepository()
      ..shouldFail = true
      ..failure = NetworkException();
    final state = AvailabilityState(repository: repo);
    await tester.pumpWidget(createTestApp(
      AvailabilitySettingsScreen(availabilityState: state, authState: authState)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('availability_error')), findsOneWidget);
    expect(state.errorKind, AvailabilityErrorKind.network);
    expect(find.byKey(const Key('availability_retry')), findsOneWidget);

    repo.shouldFail = false;
    await tester.tap(find.byKey(const Key('availability_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('availability_error')), findsNothing);
    expect(find.byKey(const Key('save_availability_button')), findsOneWidget);

    // Unauthorized / validation kinds are classified, unauthorized has no retry
    final repo2 = MockAvailabilityRepository()
      ..shouldFail = true
      ..failure = UnauthorizedException();
    final s2 = AvailabilityState(repository: repo2);
    await tester.pumpWidget(createTestApp(
      AvailabilitySettingsScreen(key: UniqueKey(), availabilityState: s2, authState: authState)));
    await tester.pumpAndSettle();
    expect(s2.errorKind, AvailabilityErrorKind.unauthorized);
    expect(find.byKey(const Key('availability_retry')), findsNothing);

    final s3 = AvailabilityState(repository: MockAvailabilityRepository()
      ..shouldFail = true
      ..failure = ApiException(code: 'VALIDATION_ERROR', message: 'Buffer cannot be negative', statusCode: 400));
    await s3.saveWeekly('tok', days: _seedAvailability().weekly, rules: const BookingRulesModel());
    expect(s3.errorKind, AvailabilityErrorKind.validation);
    expect(s3.errorMessage, 'Buffer cannot be negative');
  });

  // ─── Model helpers ───────────────────────────────────────────────────────
  test('time and duration formatting helpers', () {
    expect(formatTime12('00:00'), '12:00 AM');
    expect(formatTime12('12:30'), '12:30 PM');
    expect(formatTime12('18:00'), '6:00 PM');
    expect(durationLabel(30), '30 min');
    expect(durationLabel(90), '1h 30m');
    expect(durationLabel(120), '2 hours');
    expect(const BookingRulesModel(minimumDurationMinutes: 30, maximumDurationMinutes: 120).durationOptions,
        [30, 60, 90, 120]);
  });
}
