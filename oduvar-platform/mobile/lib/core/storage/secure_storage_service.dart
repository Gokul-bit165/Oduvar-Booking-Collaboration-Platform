import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const String keyAccessToken = 'oduvar_access_token';
  static const String keyRefreshToken = 'oduvar_refresh_token';
  static const String keyUserJson = 'oduvar_cached_user';

  final FlutterSecureStorage _secureStorage;

  SecureStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _secureStorage.write(key: keyAccessToken, value: accessToken);
      await _secureStorage.write(key: keyRefreshToken, value: refreshToken);
    } catch (_) {
      // Fallback for environments where native secure storage is unavailable
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAccessToken, accessToken);
      await prefs.setString(keyRefreshToken, refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: keyAccessToken);
      if (token != null) return token;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: keyRefreshToken);
      if (token != null) return token;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRefreshToken);
  }

  Future<void> saveUserJson(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUserJson, jsonString);
  }

  Future<String?> getUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserJson);
  }

  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: keyAccessToken);
      await _secureStorage.delete(key: keyRefreshToken);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyRefreshToken);
    await prefs.remove(keyUserJson);
  }
}
