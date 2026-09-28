import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/core/storage/secure_storage_service.dart';
import 'package:oduvar_mobile/features/auth/data/auth_repository.dart';
import 'package:oduvar_mobile/features/auth/data/auth_service.dart';
import 'package:oduvar_mobile/features/auth/models/auth_response_model.dart';
import 'package:oduvar_mobile/features/auth/models/user_model.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/availability/models/availability_model.dart';
import 'package:oduvar_mobile/features/client/presentation/client_home_screen.dart';
import 'package:oduvar_mobile/features/discovery/data/discovery_repository.dart';
import 'package:oduvar_mobile/features/discovery/models/discovery_model.dart';
import 'package:oduvar_mobile/features/discovery/presentation/discovery_state.dart';
import 'package:oduvar_mobile/features/discovery/presentation/oduvar_discovery_screen.dart';
import 'package:oduvar_mobile/features/discovery/presentation/widgets/oduvar_card.dart';
import 'package:oduvar_mobile/features/oduvar/data/oduvar_profile_repository.dart';
import 'package:oduvar_mobile/features/oduvar/models/oduvar_profile_model.dart';
import 'package:oduvar_mobile/features/services/data/oduvar_service_repository.dart';
import 'package:oduvar_mobile/features/services/models/service_model.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthRepo implements AuthRepository {
  UserModel get _u => UserModel(
        id: 'client-1', name: 'Sundar Devotee', email: 'client@test.com', phone: '+919876543210',
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

class _MockStorage extends SecureStorageService {
  @override Future<void> saveTokens({required accessToken, required refreshToken}) async {}
  @override Future<String?> getAccessToken() async => 't';
  @override Future<String?> getRefreshToken() async => null;
  @override Future<void> saveUserJson(String jsonString) async {}
  @override Future<String?> getUserJson() async => null;
  @override Future<void> clearAll() async {}
}

class SearchCall {
  final String search;
  final OduvarSearchFilters filters;
  final DiscoverySort sort;
  final int page;
  final int pageSize;
  SearchCall(this.search, this.filters, this.sort, this.page, this.pageSize);
}

OduvarDiscoveryModel makeOduvar(int i, {double? rating, int reviews = 0}) => OduvarDiscoveryModel(
      id: 'oduvar-$i',
      profileId: 'profile-$i',
      name: 'Oduvar Number $i',
      location: i.isEven ? 'Chennai' : 'Salem',
      skills: const [
        DiscoveryTag(id: 's1', name: 'Thevaram'),
        DiscoveryTag(id: 's2', name: 'Thiruvasagam'),
        DiscoveryTag(id: 's3', name: 'Thirupugazh'),
        DiscoveryTag(id: 's4', name: 'Functions'),
      ],
      performanceTypes: const ['VOCAL'],
      services: const [DiscoveryTag(id: 'sv1', name: 'Thevaram Recital', category: 'Thevaram')],
      transport: 'ADDITIONAL_FEE',
      collaborationEnabled: true,
      rating: rating,
      reviewCount: reviews,
    );

class MockDiscoveryRepository extends OduvarDiscoveryRepository {
  List<OduvarDiscoveryModel> all;
  final List<SearchCall> calls = [];
  bool shouldFail = false;
  Completer<void>? gate;
  int optionsCalls = 0;
  bool optionsFail = false;

  MockDiscoveryRepository(this.all);

  @override
  Future<SearchPage> search({
    String search = '',
    OduvarSearchFilters filters = OduvarSearchFilters.empty,
    DiscoverySort sort = DiscoverySort.relevance,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add(SearchCall(search, filters, sort, page, pageSize));
    if (gate != null) await gate!.future;
    if (shouldFail) throw NetworkException();
    final start = (page - 1) * pageSize;
    final items = all.skip(start).take(pageSize).toList();
    return SearchPage(items: items, page: page, pageSize: pageSize, total: all.length, hasNext: start + pageSize < all.length);
  }

  @override
  Future<DiscoveryFilterOptions> getFilterOptions() async {
    optionsCalls++;
    if (optionsFail) throw NetworkException();
    return const DiscoveryFilterOptions(
      services: [OptionItem('Thevaram', 'Thevaram'), OptionItem('Thiruvasagam', 'Thiruvasagam'), OptionItem('Thirupugazh', 'Thirupugazh')],
      eventTypes: [OptionItem('TEMPLE', 'Temple'), OptionItem('FUNERAL', 'Funeral'), OptionItem('HOSPITAL', 'Hospital')],
      instruments: [OptionItem('flute', 'Flute'), OptionItem('mridangam', 'Mridangam')],
      performanceTypes: [OptionItem('VOCAL', 'Vocal'), OptionItem('INSTRUMENTAL', 'Instrumental'), OptionItem('BOTH', 'Both')],
    );
  }
}

class MockProfileRepository extends OduvarProfileRepository {
  final List<String> requested = [];
  Completer<void>? gate;
  @override
  Future<OduvarProfileModel> getPublicProfile(String oduvarId) async {
    requested.add(oduvarId);
    if (gate != null) await gate!.future;
    return OduvarProfileModel.fromJson({
      'id': 'profile-1',
      'isPublished': true,
      'bio': 'Devoted singer of the Thirumurai.',
      'location': 'Salem',
      'performanceTypes': ['VOCAL'],
      'songCategories': ['THEVARAM'],
      'eventTypes': ['TEMPLE'],
      'transport': 'ADDITIONAL_FEE',
      'collaborationEnabled': true,
      'owner': {'id': oduvarId, 'name': 'Ravi Kumar Oduvar'},
      'photos': [],
      'skills': [{'id': 's1', 'name': 'Thevaram', 'slug': 'thevaram'}],
      'instruments': [{'id': 'i1', 'name': 'Flute', 'slug': 'flute'}],
    });
  }
}

class MockServiceRepository extends OduvarServiceRepository {
  @override
  Future<List<OduvarServiceModel>> getPublicOduvarServices(String oduvarId) async => [
        const OduvarServiceModel(
          id: 'svc-1', profileId: 'p', serviceId: 'b1', name: 'Thevaram Recital', category: 'Thevaram',
          transport: 'ADDITIONAL_FEE', transportFee: 300, isActive: true,
          pricings: [
            PricingModel(id: 'a', oduvarServiceId: 'svc-1', durationMinutes: 30, amount: 500),
            PricingModel(id: 'b', oduvarServiceId: 'svc-1', durationMinutes: 60, amount: 900),
          ],
        ),
        const OduvarServiceModel(
          id: 'svc-2', profileId: 'p', serviceId: 'b2', name: 'Hidden Inactive Service', category: 'Other',
          transport: 'INCLUDED', isActive: false,
          pricings: [PricingModel(id: 'c', oduvarServiceId: 'svc-2', durationMinutes: 60, amount: 4242)],
        ),
      ];
}

class MockAvailabilityRepository extends AvailabilityRepository {
  final List<String> publicLoads = [];
  @override
  Future<AvailabilityModel> getAvailability({String? token, String? oduvarId}) async {
    publicLoads.add(oduvarId ?? 'me');
    return AvailabilityModel.empty();
  }

  @override
  Future<MonthAvailability> getMonth({String? token, String? oduvarId, required String month, int? durationMinutes}) async =>
      MonthAvailability(month: month, days: const []);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

MaterialApp app(Widget home) => MaterialApp(theme: AppTheme.lightTheme, home: home);

void tallScreen(WidgetTester tester, {double height = 6000}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpDiscovery(
  WidgetTester tester,
  MockDiscoveryRepository repo, {
  DiscoveryState? state,
  MockProfileRepository? profiles,
  MockAvailabilityRepository? availability,
  double height = 6000,
}) async {
  tallScreen(tester, height: height);
  final s = state ?? DiscoveryState(repository: repo, pageSize: 2);
  await tester.pumpWidget(app(OduvarDiscoveryScreen(
    state: s,
    profileRepository: profiles ?? MockProfileRepository(),
    serviceRepository: MockServiceRepository(),
    availabilityRepository: availability ?? MockAvailabilityRepository(),
  )));
  await tester.pumpAndSettle();
}

void main() {
  late AuthState authState;

  setUp(() {
    authState = AuthState(authService: AuthService(repository: _MockAuthRepo(), storage: _MockStorage()));
    authState.login(email: 'client@test.com', password: 'Password123!');
  });

  // ─── 1 ─────────────────────────────────────────────────────────────────────
  testWidgets('1. Client Home renders search, popular services, event types and Oduvar cards', (tester) async {
    tallScreen(tester);
    final repo = MockDiscoveryRepository([for (var i = 1; i <= 7; i++) makeOduvar(i)]);
    await tester.pumpWidget(app(ClientHomeScreen(
      authState: authState,
      discoveryRepository: repo,
      profileRepository: MockProfileRepository(),
      serviceRepository: MockServiceRepository(),
      availabilityRepository: MockAvailabilityRepository(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Devotee Sanctuary'), findsOneWidget);
    expect(find.text('Find an Oduvar'), findsOneWidget);
    expect(find.byKey(const Key('home_search_field')), findsOneWidget);
    expect(find.text('Popular Services'), findsOneWidget);
    expect(find.byKey(const Key('home_service_Thevaram')), findsOneWidget);
    expect(find.text('Event Types'), findsOneWidget);
    expect(find.byKey(const Key('home_event_TEMPLE')), findsOneWidget);
    expect(find.text('Discover Oduvars'), findsOneWidget);
    // preview shows the first 5 only; the rest lives behind "See all"
    expect(find.byKey(const Key('oduvar_card_oduvar-5')), findsOneWidget);
    expect(find.byKey(const Key('oduvar_card_oduvar-6')), findsNothing);
    expect(find.byKey(const Key('see_all_button')), findsOneWidget);
    expect(repo.calls.first.pageSize, 5);
  });

  // ─── 2 ─────────────────────────────────────────────────────────────────────
  testWidgets('2. Search field renders on the discovery screen', (tester) async {
    await pumpDiscovery(tester, MockDiscoveryRepository([makeOduvar(1)]));
    expect(find.byKey(const Key('discovery_search_field')), findsOneWidget);
    expect(find.text('Search Oduvar name or location'), findsOneWidget);
    expect(find.byKey(const Key('filter_button')), findsOneWidget);
    expect(find.byKey(const Key('sort_button')), findsOneWidget);
  });

  // ─── 3 ─────────────────────────────────────────────────────────────────────
  testWidgets('3. Search is debounced: typing R-Ra-Rav-Ravi sends one request', (tester) async {
    final repo = MockDiscoveryRepository([makeOduvar(1)]);
    await pumpDiscovery(tester, repo);
    expect(repo.calls, hasLength(1)); // initial load

    final field = find.byKey(const Key('discovery_search_field'));
    for (final t in ['R', 'Ra', 'Rav', 'Ravi']) {
      await tester.enterText(field, t);
      await tester.pump(const Duration(milliseconds: 100)); // shorter than the debounce
    }
    expect(repo.calls, hasLength(1)); // nothing sent while typing

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(2));
    expect(repo.calls.last.search, 'Ravi');
    expect(repo.calls.last.page, 1);

    // Keyboard submit skips the debounce
    await tester.enterText(field, 'Salem');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.calls.last.search, 'Salem');
  });

  // ─── 4 ─────────────────────────────────────────────────────────────────────
  testWidgets('4. Search results render from the server response', (tester) async {
    final repo = MockDiscoveryRepository([for (var i = 1; i <= 2; i++) makeOduvar(i)]);
    await pumpDiscovery(tester, repo);
    expect(find.text('Oduvar Number 1'), findsOneWidget);
    expect(find.text('Oduvar Number 2'), findsOneWidget);
    expect(find.text('2 Oduvars'), findsOneWidget);
    expect(find.byKey(const Key('load_more_button')), findsNothing);
  });

  // ─── 5 ─────────────────────────────────────────────────────────────────────
  testWidgets('5. Oduvar card shows public info, real ratings, and "No reviews yet" otherwise', (tester) async {
    final repo = MockDiscoveryRepository([makeOduvar(1, rating: 4.5, reviews: 2), makeOduvar(2)]);
    await pumpDiscovery(tester, repo);

    final c1 = find.byKey(const Key('oduvar_card_oduvar-1'));
    expect(find.descendant(of: c1, matching: find.text('Oduvar Number 1')), findsOneWidget);
    expect(find.descendant(of: c1, matching: find.text('Salem')), findsOneWidget);
    expect(find.descendant(of: c1, matching: find.text('4.5 (2)')), findsOneWidget);
    // 3 skill tags + "+1" collapsed
    expect(find.descendant(of: c1, matching: find.text('Thevaram')), findsWidgets);
    expect(find.descendant(of: c1, matching: find.text('+1')), findsOneWidget);
    expect(find.descendant(of: c1, matching: find.text('Functions')), findsNothing);
    expect(find.descendant(of: c1, matching: find.text('Vocal')), findsOneWidget);
    expect(find.descendant(of: c1, matching: find.text('Transport: Additional Fee')), findsOneWidget);
    expect(find.descendant(of: c1, matching: find.text('Open to collaboration')), findsOneWidget);
    expect(find.descendant(of: c1, matching: find.text('View Profile')), findsOneWidget);

    // Oduvar 2 has no reviews: text, and not a star rating
    final c2 = find.byKey(const Key('oduvar_card_oduvar-2'));
    expect(find.descendant(of: c2, matching: find.text('No reviews yet')), findsOneWidget);
    expect(find.descendant(of: c2, matching: find.byIcon(Icons.star_rounded)), findsNothing);
    // no private contact data
    expect(find.textContaining('+91'), findsNothing);
  });

  // ─── 6 ─────────────────────────────────────────────────────────────────────
  testWidgets('6. Filter sheet renders all filter sections', (tester) async {
    await pumpDiscovery(tester, MockDiscoveryRepository([makeOduvar(1)]));
    await tester.tap(find.byKey(const Key('filter_button')));
    await tester.pumpAndSettle();
    for (final t in ['Filters', 'Location', 'Service / Song', 'Event type', 'Instrument', 'Performance type', 'Transport', 'Available on', 'Available for']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.byKey(const Key('filter_location')), findsOneWidget);
    expect(find.byKey(const Key('filter_service_Thevaram')), findsOneWidget);
    expect(find.byKey(const Key('filter_event_TEMPLE')), findsOneWidget);
    expect(find.byKey(const Key('filter_instrument_flute')), findsOneWidget);
    expect(find.byKey(const Key('filter_perf_VOCAL')), findsOneWidget);
    expect(find.byKey(const Key('filter_transport_INCLUDED')), findsOneWidget);
    expect(find.byKey(const Key('filter_date_button')), findsOneWidget);
    expect(find.byKey(const Key('filter_apply')), findsOneWidget);
    expect(find.byKey(const Key('filter_clear_all')), findsOneWidget);
    // duration needs a date first
    expect(find.byKey(const Key('duration_hint')), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('filter_duration_60'))).onSelected, isNull);
  });

  // ─── 7 ─────────────────────────────────────────────────────────────────────
  testWidgets('7. Filter chips can be selected and deselected without applying', (tester) async {
    final repo = MockDiscoveryRepository([makeOduvar(1)]);
    await pumpDiscovery(tester, repo);
    await tester.tap(find.byKey(const Key('filter_button')));
    await tester.pumpAndSettle();

    bool selected(String k) => tester.widget<ChoiceChip>(find.byKey(Key(k))).selected;
    await tester.tap(find.byKey(const Key('filter_service_Thevaram')));
    await tester.pumpAndSettle();
    expect(selected('filter_service_Thevaram'), isTrue);
    await tester.tap(find.byKey(const Key('filter_service_Thiruvasagam')));
    await tester.pumpAndSettle();
    expect(selected('filter_service_Thevaram'), isFalse); // single-select per group
    expect(selected('filter_service_Thiruvasagam'), isTrue);
    await tester.tap(find.byKey(const Key('filter_service_Thiruvasagam')));
    await tester.pumpAndSettle();
    expect(selected('filter_service_Thiruvasagam'), isFalse); // tap again to deselect
    expect(repo.calls, hasLength(1)); // nothing applied yet
  });

  // ─── 8 ─────────────────────────────────────────────────────────────────────
  testWidgets('8. Apply sends the filters to the server, resets to page 1 and shows the count', (tester) async {
    final repo = MockDiscoveryRepository([for (var i = 1; i <= 5; i++) makeOduvar(i)]);
    await pumpDiscovery(tester, repo);
    await tester.tap(find.byKey(const Key('load_more_button'))); // move to page 2 first
    await tester.pumpAndSettle();
    expect(repo.calls.last.page, 2);

    await tester.tap(find.byKey(const Key('filter_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('filter_location')), 'Salem');
    await tester.tap(find.byKey(const Key('filter_service_Thevaram')));
    await tester.tap(find.byKey(const Key('filter_transport_INCLUDED')));
    await tester.tap(find.byKey(const Key('filter_instrument_flute')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();

    final last = repo.calls.last;
    expect(last.page, 1);
    expect(last.filters.location, 'Salem');
    expect(last.filters.service, 'Thevaram');
    expect(last.filters.transport, 'INCLUDED');
    expect(last.filters.instrument, 'flute');
    expect(last.filters.toQuery(), {'location': 'Salem', 'service': 'Thevaram', 'transport': 'INCLUDED', 'instrument': 'flute'});
    expect(find.text('Filters (4)'), findsOneWidget);
  });

  // ─── 9 ─────────────────────────────────────────────────────────────────────
  testWidgets('9. Clear All (sheet) and Clear (bar) remove filters', (tester) async {
    final repo = MockDiscoveryRepository([makeOduvar(1)]);
    final state = DiscoveryState(repository: repo, pageSize: 2);
    await pumpDiscovery(tester, repo, state: state);

    state.applyFilters(const OduvarSearchFilters(service: 'Thevaram', transport: 'INCLUDED'));
    await tester.pumpAndSettle();
    expect(find.text('Filters (2)'), findsOneWidget);

    // Clear All inside the sheet then Apply
    await tester.tap(find.byKey(const Key('filter_button')));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('filter_service_Thevaram'))).selected, isTrue); // persisted in session
    await tester.tap(find.byKey(const Key('filter_clear_all')));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('filter_service_Thevaram'))).selected, isFalse);
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();
    expect(state.filters.isEmpty, isTrue);
    expect(find.text('Filters'), findsOneWidget);
    expect(repo.calls.last.filters.toQuery(), isEmpty);

    // "Clear" on the bar
    state.applyFilters(const OduvarSearchFilters(eventType: 'TEMPLE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clear_filters_button')));
    await tester.pumpAndSettle();
    expect(state.activeFilterCount, 0);
  });

  // ─── 10 ────────────────────────────────────────────────────────────────────
  testWidgets('10. Load more appends the next page; the button disappears on the last page', (tester) async {
    final repo = MockDiscoveryRepository([for (var i = 1; i <= 5; i++) makeOduvar(i)]);
    await pumpDiscovery(tester, repo); // pageSize 2
    expect(find.byType(OduvarCardSkeleton), findsNothing);
    expect(find.byKey(const Key('oduvar_card_oduvar-2')), findsOneWidget);
    expect(find.byKey(const Key('oduvar_card_oduvar-3')), findsNothing);

    await tester.tap(find.byKey(const Key('load_more_button')));
    await tester.pumpAndSettle();
    expect(repo.calls.last.page, 2);
    expect(find.byKey(const Key('oduvar_card_oduvar-1')), findsOneWidget); // still there: appended, not replaced
    expect(find.byKey(const Key('oduvar_card_oduvar-4')), findsOneWidget);

    await tester.tap(find.byKey(const Key('load_more_button')));
    await tester.pumpAndSettle();
    expect(repo.calls.last.page, 3);
    expect(find.byKey(const Key('oduvar_card_oduvar-5')), findsOneWidget);
    expect(find.byKey(const Key('load_more_button')), findsNothing);
    expect(find.text('5 Oduvars'), findsOneWidget);
  });

  // ─── 11 ────────────────────────────────────────────────────────────────────
  testWidgets('11. Pull to refresh reloads page 1 while keeping results visible', (tester) async {
    final repo = MockDiscoveryRepository([makeOduvar(1), makeOduvar(2)]);
    await pumpDiscovery(tester, repo, height: 1200); // pull threshold is relative to the viewport height
    expect(repo.calls, hasLength(1));

    await tester.drag(find.byKey(const Key('discovery_list')), const Offset(0, 900));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('oduvar_card_oduvar-1')), findsOneWidget); // results stay on screen while refreshing
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(2));
    expect(repo.calls.last.page, 1);
  });

  // ─── 12 ────────────────────────────────────────────────────────────────────
  testWidgets('12. Empty state offers guidance and a way to clear filters', (tester) async {
    final repo = MockDiscoveryRepository([]);
    final state = DiscoveryState(repository: repo, pageSize: 2);
    await pumpDiscovery(tester, repo, state: state);
    expect(find.byKey(const Key('discovery_empty')), findsOneWidget);
    expect(find.text('No Oduvars found'), findsOneWidget);
    expect(find.text('No Oduvars have published a profile yet. Please check back soon.'), findsOneWidget);

    state.applyFilters(const OduvarSearchFilters(location: 'Nowhere'));
    await tester.pumpAndSettle();
    expect(find.text('Try changing your location or filters.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('empty_clear_filters')));
    await tester.pumpAndSettle();
    expect(state.activeFilterCount, 0);
  });

  // ─── 13 ────────────────────────────────────────────────────────────────────
  testWidgets('13. Error state with retry; load-more failure keeps existing results', (tester) async {
    final repo = MockDiscoveryRepository([for (var i = 1; i <= 4; i++) makeOduvar(i)])..shouldFail = true;
    final state = DiscoveryState(repository: repo, pageSize: 2);
    await pumpDiscovery(tester, repo, state: state);
    expect(find.byKey(const Key('discovery_error')), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);

    repo.shouldFail = false;
    await tester.tap(find.byKey(const Key('discovery_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('discovery_error')), findsNothing);
    expect(find.byKey(const Key('oduvar_card_oduvar-1')), findsOneWidget);

    repo.shouldFail = true;
    await tester.tap(find.byKey(const Key('load_more_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('load_more_retry')), findsOneWidget);
    expect(find.byKey(const Key('oduvar_card_oduvar-1')), findsOneWidget); // still visible
    repo.shouldFail = false;
    await tester.tap(find.byKey(const Key('load_more_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('oduvar_card_oduvar-3')), findsOneWidget);
  });

  // ─── 14 ────────────────────────────────────────────────────────────────────
  testWidgets('14. View Profile opens the public profile loaded from the API', (tester) async {
    final profiles = MockProfileRepository()..gate = Completer<void>();
    await pumpDiscovery(tester, MockDiscoveryRepository([makeOduvar(1)]), profiles: profiles);
    await tester.tap(find.byKey(const Key('view_profile_oduvar-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('profile_loading'), skipOffstage: false), findsOneWidget); // skeleton while loading
    profiles.gate!.complete();
    await tester.pumpAndSettle();

    expect(profiles.requested, ['oduvar-1']); // the Oduvar's USER id is what the public API expects
    expect(find.text('Ravi Kumar Oduvar'), findsWidgets);
    expect(find.text('Devoted singer of the Thirumurai.'), findsOneWidget);
    expect(find.text('GOOD AT'), findsOneWidget);
    expect(find.text('EVENTS SERVED'), findsOneWidget);
    expect(find.text('Temple'), findsOneWidget);
    expect(find.byKey(const Key('view_availability_button')), findsOneWidget);
  });

  // ─── 15 ────────────────────────────────────────────────────────────────────
  testWidgets('15. Public profile lists active services with backend prices only', (tester) async {
    await pumpDiscovery(tester, MockDiscoveryRepository([makeOduvar(1)]));
    await tester.tap(find.byKey(const Key('view_profile_oduvar-1')));
    await tester.pumpAndSettle();
    expect(find.text('Services & Pricing'), findsOneWidget);
    expect(find.text('Thevaram Recital'), findsWidgets);
    expect(find.text('₹500'), findsOneWidget);
    expect(find.text('₹900'), findsOneWidget);
    expect(find.text('Hidden Inactive Service'), findsNothing);
    expect(find.text('₹4,242'), findsNothing);
    expect(find.byType(TextField), findsNothing); // no price input anywhere
  });

  // ─── 16 ────────────────────────────────────────────────────────────────────
  testWidgets('16. Profile links to the real public availability calendar', (tester) async {
    final availability = MockAvailabilityRepository();
    await pumpDiscovery(tester, MockDiscoveryRepository([makeOduvar(1)]), availability: availability);
    await tester.tap(find.byKey(const Key('view_profile_oduvar-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('view_availability_button')));
    await tester.tap(find.byKey(const Key('view_availability_button')));
    await tester.pumpAndSettle();
    expect(availability.publicLoads, ['oduvar-1']); // the public endpoint for this Oduvar
    expect(find.byKey(const Key('availability_calendar')), findsOneWidget);
    expect(find.byKey(const Key('duration_selector')), findsOneWidget);
    expect(find.text('Booked'), findsNothing); // nothing fabricated
    expect(find.text('Pending'), findsNothing);
  });

  // ─── 17 ────────────────────────────────────────────────────────────────────
  test('17. Active filter count and query building', () {
    expect(OduvarSearchFilters.empty.activeCount, 0);
    const f = OduvarSearchFilters(location: 'Salem', service: 'Thevaram', transport: 'INCLUDED');
    expect(f.activeCount, 3);
    expect(f.copyWith(eventType: 'TEMPLE').activeCount, 4);
    expect(f.copyWith(clearService: true).activeCount, 2);
    // date + duration each count; clearing the date clears the duration with it
    final d = f.copyWith(availableDate: '2026-10-20', availableDuration: 60);
    expect(d.activeCount, 5);
    expect(d.copyWith(clearAvailableDate: true).availableDuration, isNull);
    // a duration without a date is never sent (the API would reject it)
    expect(const OduvarSearchFilters(availableDuration: 60).toQuery(), isEmpty);
    expect(d.toQuery()['availableDate'], '2026-10-20');
    expect(d.toQuery()['availableDuration'], '60');
    // blank location is ignored
    expect(const OduvarSearchFilters(location: '  ').toQuery(), isEmpty);
  });

  // ─── 18 ────────────────────────────────────────────────────────────────────
  testWidgets('18. Loading state shows card skeletons, then results', (tester) async {
    final repo = MockDiscoveryRepository([makeOduvar(1)])..gate = Completer<void>();
    tallScreen(tester);
    final state = DiscoveryState(repository: repo, pageSize: 2);
    await tester.pumpWidget(app(OduvarDiscoveryScreen(state: state)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('discovery_loading')), findsOneWidget);
    expect(find.byType(OduvarCardSkeleton), findsNWidgets(3));
    expect(find.byKey(const Key('discovery_empty')), findsNothing);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(OduvarCardSkeleton), findsNothing);
    expect(find.byKey(const Key('oduvar_card_oduvar-1')), findsOneWidget);
  });

  // ─── Extra: state behaviour ────────────────────────────────────────────────
  test('changing search, filters or sort resets pagination; stale responses are ignored', () async {
    final repo = MockDiscoveryRepository([for (var i = 1; i <= 5; i++) makeOduvar(i)]);
    final state = DiscoveryState(repository: repo, pageSize: 2, debounce: Duration.zero);
    await state.reload();
    await state.loadMore();
    expect(state.items, hasLength(4));
    expect(state.page, 2);

    state.applyFilters(const OduvarSearchFilters(transport: 'INCLUDED'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(state.page, 1);
    expect(state.items, hasLength(2));

    state.setSort(DiscoverySort.name);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls.last.sort, DiscoverySort.name);
    expect(repo.calls.last.page, 1);

    // stale response: a slow first request must not overwrite a newer, faster one
    final slow = MockDiscoveryRepository([makeOduvar(1)]);
    final gate = Completer<void>();
    slow.gate = gate;
    final s2 = DiscoveryState(repository: slow, pageSize: 2);
    final first = s2.reload(); // will resolve LAST, with oduvar-1
    slow.gate = null;
    slow.all = [makeOduvar(9)];
    await s2.reload(); // newer request resolves first, with oduvar-9
    expect(s2.items.single.id, 'oduvar-9');
    gate.complete();
    await first;
    expect(s2.items.single.id, 'oduvar-9'); // the stale response was discarded
    state.dispose();
    s2.dispose();
  });

  test('filter options load from the reference endpoints and failures are tolerated', () async {
    final repo = MockDiscoveryRepository([])..optionsFail = true;
    final state = DiscoveryState(repository: repo);
    await state.loadOptions();
    expect(state.optionsFailed, isTrue);
    expect(state.options.isEmpty, isTrue);
    repo.optionsFail = false;
    await state.loadOptions(force: true);
    expect(state.options.services.map((o) => o.key), ['Thevaram', 'Thiruvasagam', 'Thirupugazh']);
    await state.loadOptions(); // cached: no second call
    expect(repo.optionsCalls, 2);
    state.dispose();
  });
}
