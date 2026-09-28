import 'package:flutter_test/flutter_test.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/auth/data/auth_service.dart';
import 'package:oduvar_mobile/features/auth/data/auth_repository.dart';
import 'package:oduvar_mobile/features/auth/models/auth_response_model.dart';
import 'package:oduvar_mobile/features/auth/models/user_model.dart';
import 'package:oduvar_mobile/core/storage/secure_storage_service.dart';

class MockAuthRepository implements AuthRepository {
  UserModel? mockUser;
  bool shouldFail = false;

  @override
  Future<AuthResponseModel> login({required String email, required String password}) async {
    if (shouldFail) throw Exception('Invalid credentials');
    final user = UserModel(
      id: 'mock-uuid-1',
      name: 'Test Devotee',
      email: email,
      phone: '+919876543210',
      role: UserRole.client,
      createdAt: DateTime.now(),
    );
    return AuthResponseModel(
      user: user,
      accessToken: 'mock_access_token',
      refreshToken: 'mock_refresh_token',
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
    if (shouldFail) throw Exception('Registration failed');
    final user = UserModel(
      id: 'mock-uuid-2',
      name: name,
      email: email,
      phone: phone,
      role: role,
      createdAt: DateTime.now(),
    );
    return AuthResponseModel(
      user: user,
      accessToken: 'mock_access_token',
      refreshToken: 'mock_refresh_token',
    );
  }

  @override
  Future<UserModel> getMe({required String accessToken}) async {
    return mockUser ??
        UserModel(
          id: 'mock-uuid-1',
          name: 'Restored User',
          email: 'restored@oduvar.local',
          phone: '+919876543210',
          role: UserRole.client,
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<Map<String, String>> refreshToken({required String refreshToken}) async {
    return {
      'accessToken': 'new_mock_access_token',
      'refreshToken': 'new_mock_refresh_token',
    };
  }

  @override
  Future<void> logout({required String accessToken}) async {}
}

class FakeSecureStorageService extends SecureStorageService {
  String? accessToken;
  String? refreshToken;
  String? userJson;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveUserJson(String jsonString) async {
    userJson = jsonString;
  }

  @override
  Future<String?> getUserJson() async => userJson;

  @override
  Future<void> clearAll() async {
    accessToken = null;
    refreshToken = null;
    userJson = null;
  }
}

void main() {
  group('4. Authentication State Tests', () {
    late MockAuthRepository mockRepo;
    late FakeSecureStorageService fakeStorage;
    late AuthService authService;
    late AuthState authState;

    setUp(() {
      mockRepo = MockAuthRepository();
      fakeStorage = FakeSecureStorageService();
      authService = AuthService(repository: mockRepo, storage: fakeStorage);
      authState = AuthState(authService: authService);
    });

    test('Initial status should be AuthStatus.initial and user should be null', () {
      expect(authState.status, AuthStatus.initial);
      expect(authState.currentUser, isNull);
      expect(authState.isAuthenticated, false);
    });

    test('Successful login updates state to authenticated and stores user', () async {
      final success = await authState.login(
        email: 'client@oduvar.local',
        password: 'Password123!',
      );

      expect(success, true);
      expect(authState.status, AuthStatus.authenticated);
      expect(authState.currentUser, isNotNull);
      expect(authState.currentUser!.email, 'client@oduvar.local');
      expect(authState.currentUser!.role, UserRole.client);
      expect(authState.isAuthenticated, true);
      expect(fakeStorage.accessToken, 'mock_access_token');
    });

    test('Failed login updates state to error and sets error message', () async {
      mockRepo.shouldFail = true;

      final success = await authState.login(
        email: 'client@oduvar.local',
        password: 'WrongPassword!',
      );

      expect(success, false);
      expect(authState.status, AuthStatus.error);
      expect(authState.currentUser, isNull);
      expect(authState.errorMessage, isNotNull);
      expect(authState.isAuthenticated, false);
    });

    test('Successful registration updates state to authenticated', () async {
      final success = await authState.register(
        name: 'Oduvar Kumar',
        email: 'oduvar@oduvar.local',
        phone: '+919876543211',
        password: 'Password123!',
        role: UserRole.oduvar,
      );

      expect(success, true);
      expect(authState.status, AuthStatus.authenticated);
      expect(authState.currentUser!.role, UserRole.oduvar);
      expect(authState.currentUser!.name, 'Oduvar Kumar');
    });

    test('Logout clears user, tokens, and sets state to unauthenticated', () async {
      await authState.login(
        email: 'client@oduvar.local',
        password: 'Password123!',
      );
      expect(authState.isAuthenticated, true);

      await authState.logout();

      expect(authState.status, AuthStatus.unauthenticated);
      expect(authState.currentUser, isNull);
      expect(authState.isAuthenticated, false);
      expect(fakeStorage.accessToken, isNull);
    });
  });
}
