class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'ApiException($code): $message (status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({
    String message = 'Unable to connect to server. Please check your internet connection or backend status.',
  }) : super(code: 'NETWORK_FAILURE', message: message, statusCode: null);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({
    String message = 'Session expired or unauthorized. Please log in again.',
  }) : super(code: 'AUTH_UNAUTHORIZED', message: message, statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException({
    String message = 'You do not have permission to access this area.',
  }) : super(code: 'AUTH_FORBIDDEN', message: message, statusCode: 403);
}
