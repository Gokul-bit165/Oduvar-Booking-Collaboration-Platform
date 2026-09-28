import 'package:flutter/foundation.dart';

class ApiConstants {
  // Configurable base URL:
  // - Web / Windows Desktop: http://localhost:5000/api
  // - Android Emulator: http://10.0.2.2:5000/api
  // - Physical Device: LAN IP (e.g. http://192.168.1.x:5000/api)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:5000/api';
    }
  }

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Protected role verification endpoints (Phase 1)
  static const String protectedClient = '/auth/protected/client';
  static const String protectedOduvar = '/auth/protected/oduvar';
  static const String protectedAdmin = '/auth/protected/admin';

  // Request timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
