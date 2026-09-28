import 'dart:convert';
import 'auth_repository.dart';
import '../models/user_model.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/network/api_exceptions.dart';

class AuthService {
  final AuthRepository _repository;
  final SecureStorageService _storage;

  AuthService({
    AuthRepository? repository,
    SecureStorageService? storage,
  })  : _repository = repository ?? AuthRepositoryImpl(),
        _storage = storage ?? SecureStorageService();

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    final authResponse = await _repository.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
    );

    await _storage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );
    await _storage.saveUserJson(jsonEncode(authResponse.user.toJson()));

    return authResponse.user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final authResponse = await _repository.login(
      email: email,
      password: password,
    );

    await _storage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );
    await _storage.saveUserJson(jsonEncode(authResponse.user.toJson()));

    return authResponse.user;
  }

  Future<UserModel?> restoreSession() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();

    if (accessToken == null) {
      return null;
    }

    try {
      // Validate current access token with /api/auth/me
      final user = await _repository.getMe(accessToken: accessToken);
      await _storage.saveUserJson(jsonEncode(user.toJson()));
      return user;
    } on UnauthorizedException {
      // Access token expired, attempt refresh
      if (refreshToken != null) {
        try {
          final newTokens = await _repository.refreshToken(refreshToken: refreshToken);
          await _storage.saveTokens(
            accessToken: newTokens['accessToken']!,
            refreshToken: newTokens['refreshToken']!,
          );
          final user = await _repository.getMe(accessToken: newTokens['accessToken']!);
          await _storage.saveUserJson(jsonEncode(user.toJson()));
          return user;
        } catch (_) {
          // Refresh also failed, clear session
          await _storage.clearAll();
          return null;
        }
      }
      await _storage.clearAll();
      return null;
    } catch (_) {
      // Offline fallback: load cached user if available
      final cachedJson = await _storage.getUserJson();
      if (cachedJson != null) {
        try {
          return UserModel.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  Future<void> logout() async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken != null) {
      try {
        await _repository.logout(accessToken: accessToken);
      } catch (_) {
        // Continue clearing local storage even if network logout fails
      }
    }
    await _storage.clearAll();
  }

  Future<String?> getAccessToken() => _storage.getAccessToken();
}
