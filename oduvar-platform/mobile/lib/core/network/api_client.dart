import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'api_exceptions.dart';

class ApiClient {
  final http.Client _httpClient;
  final String _baseUrl;

  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    Duration timeout = ApiConstants.connectTimeout,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(
        message: 'Cannot reach backend server. Please verify the backend is running.',
      );
    } on TimeoutException {
      throw NetworkException(
        message: 'Request timed out. Please check your network connection.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Connection error: ${e.toString()}');
    }
  }

  Future<dynamic> get(
    String endpoint, {
    String? token,
    Duration timeout = ApiConstants.receiveTimeout,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(
        message: 'Cannot reach backend server. Please verify the backend is running.',
      );
    } on TimeoutException {
      throw NetworkException(
        message: 'Request timed out. Please check your network connection.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Connection error: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        code: 'PARSE_ERROR',
        message: 'Failed to parse server response',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return decoded['data'];
      }
      return decoded;
    }

    if (decoded is Map<String, dynamic> && decoded['error'] != null) {
      final err = decoded['error'];
      final code = err['code']?.toString() ?? 'SERVER_ERROR';
      final message = err['message']?.toString() ?? 'An error occurred';
      final details = err['details'];

      if (response.statusCode == 401) {
        throw UnauthorizedException(message: message);
      }
      if (response.statusCode == 403) {
        throw ForbiddenException(message: message);
      }

      throw ApiException(
        code: code,
        message: message,
        statusCode: response.statusCode,
        details: details,
      );
    }

    throw ApiException(
      code: 'HTTP_${response.statusCode}',
      message: 'Server returned HTTP status ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
}
