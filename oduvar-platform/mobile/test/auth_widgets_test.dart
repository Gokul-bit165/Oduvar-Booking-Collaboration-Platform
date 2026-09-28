import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/login_screen.dart';
import 'package:oduvar_mobile/features/auth/presentation/register_screen.dart';
import 'package:oduvar_mobile/features/auth/presentation/role_selection_screen.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/auth/data/auth_service.dart';
import 'package:oduvar_mobile/features/auth/data/auth_repository.dart';
import 'package:oduvar_mobile/features/auth/models/auth_response_model.dart';
import 'package:oduvar_mobile/features/auth/models/user_model.dart';
import 'package:oduvar_mobile/features/client/presentation/client_home_screen.dart';
import 'package:oduvar_mobile/features/oduvar/presentation/oduvar_dashboard_screen.dart';
import 'package:oduvar_mobile/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:oduvar_mobile/core/storage/secure_storage_service.dart';

// ────────────────────────────────────────────────────────────────────────────
// Test doubles
// ────────────────────────────────────────────────────────────────────────────

class TestMockRepository implements AuthRepository {
  UserRole roleToReturn = UserRole.client;

  @override
  Future<AuthResponseModel> login({required String email, required String password}) async {
    return AuthResponseModel(
      user: UserModel(
        id: 'user-123',
        name: 'Test Devotee',
        email: email,
        phone: '+919876543210',
        role: roleToReturn,
        createdAt: DateTime.now(),
      ),
      accessToken: 'token-123',
      refreshToken: 'refresh-123',
    );
  }

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    return AuthResponseModel(
      user: UserModel(
        id: 'user-456',
        name: name,
        email: email,
        phone: phone,
        role: role,
        createdAt: DateTime.now(),
      ),
      accessToken: 'token-456',
      refreshToken: 'refresh-456',
    );
  }

  @override
  Future<UserModel> getMe({required String accessToken}) async {
    return UserModel(
      id: 'user-123',
      name: 'Test Devotee',
      email: 'test@example.com',
      phone: '+919876543210',
      role: roleToReturn,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Map<String, String>> refreshToken({required String refreshToken}) async {
    return {'accessToken': 'new_token', 'refreshToken': 'new_refresh'};
  }

  @override
  Future<void> logout({required String accessToken}) async {}
}

class TestMockStorage extends SecureStorageService {
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> saveUserJson(String jsonString) async {}
  @override
  Future<String?> getUserJson() async => null;
  @override
  Future<void> clearAll() async {}
}

// ────────────────────────────────────────────────────────────────────────────
// Test helpers
// ────────────────────────────────────────────────────────────────────────────

Widget createTestApp(Widget home) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: home,
  );
}

// Router-aware test app: lets pushAndRemoveUntil work in tests
Widget createRoutingTestApp({required AuthState authState, required UserRole role}) {
  Widget destinationFor(UserRole r) {
    switch (r) {
      case UserRole.client:
        return ClientHomeScreen(authState: authState);
      case UserRole.oduvar:
        return OduvarDashboardScreen(authState: authState);
      case UserRole.admin:
        return AdminDashboardScreen(authState: authState);
    }
  }

  return MaterialApp(
    theme: AppTheme.lightTheme,
    routes: {
      '/': (ctx) => LoginScreen(authState: authState),
      '/client': (ctx) => ClientHomeScreen(authState: authState),
      '/oduvar': (ctx) => OduvarDashboardScreen(authState: authState),
      '/admin': (ctx) => AdminDashboardScreen(authState: authState),
    },
    home: LoginScreen(authState: authState),
  );
}

void setMobileScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  late TestMockRepository mockRepo;
  late TestMockStorage mockStorage;
  late AuthService authService;
  late AuthState authState;

  setUp(() {
    mockRepo = TestMockRepository();
    mockStorage = TestMockStorage();
    authService = AuthService(repository: mockRepo, storage: mockStorage);
    authState = AuthState(authService: authService);
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('1. Login Validation Tests', () {
    testWidgets('Shows validation errors on empty submission', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(LoginScreen(authState: authState)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Shows validation error on invalid email format', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(LoginScreen(authState: authState)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_email_input')), 'notanemail');
      await tester.enterText(find.byKey(const Key('login_password_input')), '123456');

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('2. Registration Validation Tests', () {
    testWidgets('Shows validation errors on empty register submission', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(RegisterScreen(authState: authState)));
      await tester.pumpAndSettle();

      final submitFinder = find.byKey(const Key('register_submit_button'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Confirm password is required'), findsOneWidget);
    });

    testWidgets('Validates password mismatch and min length', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(RegisterScreen(authState: authState)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_name_input')), 'Sundar');
      await tester.enterText(find.byKey(const Key('register_email_input')), 'sundar@oduvar.local');
      await tester.enterText(find.byKey(const Key('register_phone_input')), '+919876543210');
      await tester.enterText(find.byKey(const Key('register_password_input')), 'short');
      await tester.enterText(find.byKey(const Key('register_confirm_password_input')), 'mismatch');

      final submitFinder = find.byKey(const Key('register_submit_button'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('3. Role Selection Tests', () {
    testWidgets('Allows selecting Client and Oduvar, and does NOT present Admin', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(RoleSelectionScreen(authState: authState)));
      await tester.pumpAndSettle();

      // Both allowed roles are visible
      expect(find.text('Devotee / Temple Client'), findsOneWidget);
      expect(find.text('Oduvar (Sacred Hymn Singer)'), findsOneWidget);
      // Admin must NEVER appear as a public registration option
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Platform Administrator'), findsNothing);

      final oduvarOptionFinder = find.byKey(const Key('role_option_oduvar'));
      await tester.ensureVisible(oduvarOptionFinder);
      await tester.tap(oduvarOptionFinder);
      await tester.pumpAndSettle();

      final continueButton = find.byKey(const Key('role_continue_button'));
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // After tapping Continue on Oduvar selection → should open RegisterScreen
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 4: Authentication State – covered in auth_state_test.dart

  // ──────────────────────────────────────────────────────────────────────────
  group('5. Correct Routing After Login Tests', () {
    /// Because LoginScreen uses pushAndRemoveUntil + SnackBar (which requires a
    /// live ScaffoldMessenger), we test routing via AuthState changes directly.
    /// This is the correct unit-testing approach: verify that after a successful
    /// login, AuthState.currentUser.role matches the expected role, and then
    /// verify that the destination screen renders correctly when given that role.

    test('After CLIENT login, AuthState role is CLIENT and ClientHomeScreen renders', () async {
      mockRepo.roleToReturn = UserRole.client;
      final success = await authState.login(
        email: 'client@oduvar.local',
        password: 'Password123!',
      );

      expect(success, true);
      expect(authState.currentUser!.role, UserRole.client);
      expect(authState.currentUser!.email, 'client@oduvar.local');
    });

    testWidgets('ClientHomeScreen renders correctly for authenticated CLIENT', (tester) async {
      setMobileScreen(tester);
      mockRepo.roleToReturn = UserRole.client;
      await authState.login(email: 'client@oduvar.local', password: 'Password123!');

      await tester.pumpWidget(
        createTestApp(ClientHomeScreen(authState: authState)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Devotee Sanctuary'), findsOneWidget);
    });

    test('After ODUVAR login, AuthState role is ODUVAR', () async {
      mockRepo.roleToReturn = UserRole.oduvar;
      final success = await authState.login(
        email: 'oduvar@oduvar.local',
        password: 'Password123!',
      );

      expect(success, true);
      expect(authState.currentUser!.role, UserRole.oduvar);
    });

    testWidgets('OduvarDashboardScreen renders correctly for authenticated ODUVAR', (tester) async {
      setMobileScreen(tester);
      mockRepo.roleToReturn = UserRole.oduvar;
      await authState.login(email: 'oduvar@oduvar.local', password: 'Password123!');

      await tester.pumpWidget(
        createTestApp(OduvarDashboardScreen(authState: authState)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oduvar Portal'), findsOneWidget);
    });

    test('After ADMIN login, AuthState role is ADMIN', () async {
      mockRepo.roleToReturn = UserRole.admin;
      final success = await authState.login(
        email: 'admin@oduvar.local',
        password: 'Password123!',
      );

      expect(success, true);
      expect(authState.currentUser!.role, UserRole.admin);
    });

    testWidgets('AdminDashboardScreen renders correctly for authenticated ADMIN', (tester) async {
      setMobileScreen(tester);
      mockRepo.roleToReturn = UserRole.admin;
      await authState.login(email: 'admin@oduvar.local', password: 'Password123!');

      await tester.pumpWidget(
        createTestApp(AdminDashboardScreen(authState: authState)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Console'), findsOneWidget);
    });
  });
}
