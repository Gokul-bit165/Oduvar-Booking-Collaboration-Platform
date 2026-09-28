import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class AuthRepository {
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  });

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<Map<String, String>> refreshToken({
    required String refreshToken,
  });

  Future<void> logout({
    required String accessToken,
  });

  Future<UserModel> getMe({
    required String accessToken,
  });
}

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;

  AuthRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'role': role.toServerString(),
      },
    );

    return AuthResponseModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    return AuthResponseModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Map<String, String>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.refresh,
      body: {'refreshToken': refreshToken},
    );

    return {
      'accessToken': response['accessToken'] as String,
      'refreshToken': response['refreshToken'] as String,
    };
  }

  @override
  Future<void> logout({
    required String accessToken,
  }) async {
    await _apiClient.post(
      ApiConstants.logout,
      token: accessToken,
    );
  }

  @override
  Future<UserModel> getMe({
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.me,
      token: accessToken,
    );

    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }
}
