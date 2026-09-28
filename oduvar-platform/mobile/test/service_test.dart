import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/auth/data/auth_service.dart';
import 'package:oduvar_mobile/features/auth/data/auth_repository.dart';
import 'package:oduvar_mobile/features/auth/models/auth_response_model.dart';
import 'package:oduvar_mobile/features/auth/models/user_model.dart';
import 'package:oduvar_mobile/core/storage/secure_storage_service.dart';
import 'package:oduvar_mobile/features/services/models/service_model.dart';
import 'package:oduvar_mobile/features/services/data/oduvar_service_repository.dart';
import 'package:oduvar_mobile/features/services/presentation/oduvar_service_state.dart';
import 'package:oduvar_mobile/features/services/presentation/my_services_screen.dart';
import 'package:oduvar_mobile/features/services/presentation/add_edit_service_screen.dart';
import 'package:oduvar_mobile/features/services/presentation/widgets/price_summary_widget.dart';
import 'package:oduvar_mobile/features/services/presentation/widgets/client_service_selector.dart';
import 'package:oduvar_mobile/features/services/presentation/widgets/public_services_section.dart';

// ─── Mock Helpers ─────────────────────────────────────────────────────────────

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

class MockServiceRepository extends OduvarServiceRepository {
  List<OduvarServiceModel> _services = [];
  List<ServiceModel> _baseServices = [
    const ServiceModel(id: 'base-1', name: 'Thevaram', category: 'Thevaram'),
    const ServiceModel(id: 'base-2', name: 'Thiruvasagam', category: 'Thiruvasagam'),
    const ServiceModel(id: 'base-3', name: 'Thirupugazh', category: 'Thirupugazh'),
  ];
  bool shouldFail = false;

  void seedServices(List<OduvarServiceModel> services) => _services = services;
  void seedBaseServices(List<ServiceModel> baseServices) => _baseServices = baseServices;

  @override
  Future<List<ServiceModel>> getBaseServices() async => _baseServices;

  @override
  Future<List<OduvarServiceModel>> getMyServices(String token) async {
    if (shouldFail) throw Exception('Network error');
    return _services;
  }

  @override
  Future<OduvarServiceModel> createService(String token, Map<String, dynamic> payload) async {
    if (shouldFail) throw Exception('Failed to create service');
    final base = _baseServices.firstWhere((b) => b.id == payload['serviceId']);
    final rawPricings = payload['pricings'] as List? ?? [];
    final pricings = rawPricings
        .map((p) => PricingModel(
              id: 'pricing-${p['durationMinutes']}',
              oduvarServiceId: 'svc-new',
              durationMinutes: p['durationMinutes'] as int,
              amount: (p['amount'] as num).toDouble(),
            ))
        .toList();

    final created = OduvarServiceModel(
      id: 'svc-${DateTime.now().millisecondsSinceEpoch}',
      profileId: 'profile-1',
      serviceId: base.id,
      name: base.name,
      category: base.category,
      customDescription: payload['customDescription'] as String?,
      transport: payload['transport'] as String? ?? 'TO_BE_DISCUSSED',
      transportFee: payload['transportFee'] != null ? (payload['transportFee'] as num).toDouble() : null,
      isActive: true,
      pricings: pricings,
    );
    _services.add(created);
    return created;
  }

  @override
  Future<OduvarServiceModel> updateService(String token, String serviceId, Map<String, dynamic> payload) async {
    final idx = _services.indexWhere((s) => s.id == serviceId);
    if (idx == -1) throw Exception('Service not found');
    final existing = _services[idx];
    final updated = OduvarServiceModel(
      id: existing.id,
      profileId: existing.profileId,
      serviceId: existing.serviceId,
      name: existing.name,
      category: existing.category,
      customDescription: payload.containsKey('customDescription')
          ? payload['customDescription'] as String?
          : existing.customDescription,
      transport: payload.containsKey('transport') ? payload['transport'] as String : existing.transport,
      transportFee: payload.containsKey('transportFee')
          ? (payload['transportFee'] != null ? (payload['transportFee'] as num).toDouble() : null)
          : existing.transportFee,
      isActive: payload.containsKey('isActive') ? payload['isActive'] as bool : existing.isActive,
      pricings: existing.pricings,
    );
    _services[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteService(String token, String serviceId) async {
    _services.removeWhere((s) => s.id == serviceId);
  }

  @override
  Future<PricingModel> createPricing(String token, String serviceId, Map<String, dynamic> payload) async {
    return PricingModel(
      id: 'pricing-${DateTime.now().millisecondsSinceEpoch}',
      oduvarServiceId: serviceId,
      durationMinutes: payload['durationMinutes'] as int,
      amount: (payload['amount'] as num).toDouble(),
    );
  }

  @override
  Future<List<OduvarServiceModel>> getPublicOduvarServices(String oduvarId) async {
    return _services.where((s) => s.isActive).toList();
  }
}

// ─── Test Helpers ─────────────────────────────────────────────────────────────

MaterialApp createTestApp(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: home,
    );

void setMobileScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

OduvarServiceModel _makeOduvarService({
  String id = 'svc-1',
  String name = 'Thevaram',
  String category = 'Thevaram',
  bool isActive = true,
  String transport = 'INCLUDED',
  double? transportFee,
  List<PricingModel>? pricings,
}) =>
    OduvarServiceModel(
      id: id,
      profileId: 'profile-1',
      serviceId: 'base-1',
      name: name,
      category: category,
      customDescription: 'Sacred pann rendering for auspicious celebrations',
      transport: transport,
      transportFee: transportFee,
      isActive: isActive,
      pricings: pricings ??
          [
            const PricingModel(id: 'p-1', oduvarServiceId: 'svc-1', durationMinutes: 30, amount: 500),
            const PricingModel(id: 'p-2', oduvarServiceId: 'svc-1', durationMinutes: 60, amount: 900),
            const PricingModel(id: 'p-3', oduvarServiceId: 'svc-1', durationMinutes: 120, amount: 1700),
          ],
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late AuthState authState;

  setUp(() {
    final storage = MockStorage();
    final repo = MockAuthRepo();
    authState = AuthState(authService: AuthService(repository: repo, storage: storage));
    authState.login(email: 'oduvar@test.com', password: 'Password123!');
  });

  // ─── 1. My Services renders ───────────────────────────────────────────────
  testWidgets('1. My Services renders service cards with status and duration prices', (tester) async {
    setMobileScreen(tester);
    final mockRepo = MockServiceRepository();
    final service = _makeOduvarService();
    mockRepo.seedServices([service]);

    final state = OduvarServiceState(repository: mockRepo);
    await state.loadMyServices('tok');

    await tester.pumpWidget(createTestApp(
      MyServicesScreen(serviceState: state, authState: authState),
    ));
    await tester.pumpAndSettle();

    expect(find.text('My Services & Pricing'), findsOneWidget);
    expect(find.text('Thevaram'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('₹900'), findsOneWidget);
    expect(find.text('2 hours'), findsOneWidget);
    expect(find.text('₹1,700'), findsOneWidget);
    expect(find.byKey(const Key('add_service_fab')), findsOneWidget);
  });

  // ─── 2. Add Service form ───────────────────────────────────────────────────
  testWidgets('2. Add Service form renders all required sections', (tester) async {
    setMobileScreen(tester);
    final mockRepo = MockServiceRepository();
    final state = OduvarServiceState(repository: mockRepo);
    await state.loadBaseServices();

    await tester.pumpWidget(createTestApp(
      AddEditServiceScreen(serviceState: state, authState: authState),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Add Service'), findsOneWidget);
    expect(find.byKey(const Key('service_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('service_description_input')), findsOneWidget);
    expect(find.byKey(const Key('add_duration_button')), findsOneWidget);
    expect(find.byKey(const Key('save_service_button')), findsOneWidget);
  });

  // ─── 3. Duration selector ──────────────────────────────────────────────────
  testWidgets('3. Duration selector supports multiple duration options (min 30 min)', (tester) async {
    setMobileScreen(tester);
    final mockRepo = MockServiceRepository();
    final state = OduvarServiceState(repository: mockRepo);
    await state.loadBaseServices();

    await tester.pumpWidget(createTestApp(
      AddEditServiceScreen(serviceState: state, authState: authState),
    ));
    await tester.pumpAndSettle();

    // Default has 1 row
    expect(find.byKey(const Key('duration_dropdown_0')), findsOneWidget);

    // Tap Add Duration
    await tester.tap(find.byKey(const Key('add_duration_button')));
    await tester.pumpAndSettle();

    // Now has 2 rows
    expect(find.byKey(const Key('duration_dropdown_1')), findsOneWidget);
  });

  // ─── 4. Amount validation ──────────────────────────────────────────────────
  testWidgets('4. Amount validation rejects empty and zero amounts', (tester) async {
    setMobileScreen(tester);
    final mockRepo = MockServiceRepository();
    final state = OduvarServiceState(repository: mockRepo);
    await state.loadBaseServices();

    await tester.pumpWidget(createTestApp(
      AddEditServiceScreen(serviceState: state, authState: authState),
    ));
    await tester.pumpAndSettle();

    // Clear the default amount
    await tester.enterText(find.byKey(const Key('amount_input_0')), '');
    await tester.tap(find.byKey(const Key('save_service_button')));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
  });

  // ─── 5. Transport selector ─────────────────────────────────────────────────
  testWidgets('5. Transport selector toggles fee input when ADDITIONAL_FEE chosen', (tester) async {
    setMobileScreen(tester);
    final mockRepo = MockServiceRepository();
    final state = OduvarServiceState(repository: mockRepo);
    await state.loadBaseServices();

    await tester.pumpWidget(createTestApp(
      AddEditServiceScreen(serviceState: state, authState: authState),
    ));
    await tester.pumpAndSettle();

    // Transport fee input shouldn't exist initially (default is TO_BE_DISCUSSED)
    expect(find.byKey(const Key('transport_fee_input')), findsNothing);

    // Tap Additional Fee radio option
    await tester.tap(find.byKey(const Key('transport_option_ADDITIONAL_FEE')));
    await tester.pumpAndSettle();

    // Transport fee input is now visible
    expect(find.byKey(const Key('transport_fee_input')), findsOneWidget);
  });

  // ─── 6. Pricing display ───────────────────────────────────────────────────
  testWidgets('6. Pricing display formats currency and duration accurately', (tester) async {
    const pricing = PricingModel(
      id: 'p-1',
      oduvarServiceId: 'svc-1',
      durationMinutes: 90,
      amount: 1250,
    );

    expect(pricing.durationLabel, '1.5 hours');
    expect(pricing.formattedAmount, '₹1,250');

    const pricingShort = PricingModel(
      id: 'p-2',
      oduvarServiceId: 'svc-1',
      durationMinutes: 45,
      amount: 600,
    );
    expect(pricingShort.durationLabel, '45 minutes');
    expect(pricingShort.formattedAmount, '₹600');
  });

  // ─── 7. Public services display ───────────────────────────────────────────
  testWidgets('7. Public services display shows active services and hides inactive', (tester) async {
    setMobileScreen(tester);
    final activeService = _makeOduvarService(id: 'active-1', name: 'Thevaram Recital', isActive: true);
    final inactiveService = _makeOduvarService(id: 'inactive-1', name: 'Private Pooja', isActive: false);

    await tester.pumpWidget(createTestApp(
      Scaffold(
        body: SingleChildScrollView(
          child: PublicServicesSection(services: [activeService, inactiveService]),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Thevaram Recital'), findsOneWidget);
    expect(find.text('Private Pooja'), findsNothing); // Inactive service is hidden
  });

  // ─── 8. Client service selector ───────────────────────────────────────────
  testWidgets('8. Client service selector allows selecting published options and prevents price editing', (tester) async {
    setMobileScreen(tester);
    final service = _makeOduvarService();
    OduvarServiceModel? pickedService;
    PricingModel? pickedPricing;

    await tester.pumpWidget(createTestApp(
      Scaffold(
        body: SingleChildScrollView(
          child: ClientServiceSelector(
            services: [service],
            onSelected: (svc, prc) {
              pickedService = svc;
              pickedPricing = prc;
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Select service
    await tester.tap(find.byKey(Key('service_chip_${service.id}')));
    await tester.pumpAndSettle();

    // Select 1 hour duration
    final oneHourPricing = service.pricings.firstWhere((p) => p.durationMinutes == 60);
    await tester.tap(find.byKey(Key('pricing_option_${oneHourPricing.id}')));
    await tester.pumpAndSettle();

    expect(pickedService, isNotNull);
    expect(pickedService!.name, 'Thevaram');
    expect(pickedPricing, isNotNull);
    expect(pickedPricing!.durationMinutes, 60);

    // Client cannot enter any text: there are no EditableText or TextFormField in the selector!
    expect(find.byType(EditableText), findsNothing);
  });

  // ─── 9. Price summary ─────────────────────────────────────────────────────
  testWidgets('9. Price summary calculates correctly for Included, Additional Fee and To Be Discussed', (tester) async {
    setMobileScreen(tester);

    // Included transport
    await tester.pumpWidget(createTestApp(
      const Scaffold(
        body: PriceSummaryWidget(
          serviceName: 'Thevaram',
          durationLabel: '1 hour',
          serviceAmount: 900,
          transport: 'INCLUDED',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('₹900'), findsNWidgets(2)); // Service Amount and Total
    expect(find.text('Included'), findsOneWidget);

    // Additional Fee transport
    await tester.pumpWidget(createTestApp(
      const Scaffold(
        body: PriceSummaryWidget(
          serviceName: 'Thevaram',
          durationLabel: '1 hour',
          serviceAmount: 900,
          transport: 'ADDITIONAL_FEE',
          transportFee: 300,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('₹900'), findsOneWidget);
    expect(find.text('₹300'), findsOneWidget);
    expect(find.text('₹1,200'), findsOneWidget); // 900 + 300 = 1,200

    // To Be Discussed transport
    await tester.pumpWidget(createTestApp(
      const Scaffold(
        body: PriceSummaryWidget(
          serviceName: 'Thevaram',
          durationLabel: '1 hour',
          serviceAmount: 900,
          transport: 'TO_BE_DISCUSSED',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('To Be Discussed'), findsNWidgets(2)); // Transport and Total
  });

  // ─── 10. Loading and Error states ─────────────────────────────────────────
  testWidgets('10. My Services handles empty state and error state correctly', (tester) async {
    setMobileScreen(tester);
    final mockRepo = MockServiceRepository();
    final state = OduvarServiceState(repository: mockRepo);

    // Empty state
    await tester.pumpWidget(createTestApp(
      MyServicesScreen(serviceState: state, authState: authState),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No Services Configured'), findsOneWidget);
    expect(find.byKey(const Key('empty_add_service_button')), findsOneWidget);

    // Error state
    mockRepo.shouldFail = true;
    await state.loadMyServices('tok');
    await tester.pumpWidget(createTestApp(
      MyServicesScreen(serviceState: state, authState: authState),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
}
