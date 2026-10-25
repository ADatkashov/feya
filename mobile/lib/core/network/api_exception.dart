import 'package:dio/dio.dart';

/// A failed API call, normalized from either a server error body or a transport problem.
class ApiException implements Exception {
  const ApiException({
    this.status,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
  });

  /// HTTP status, or null when the request never got a response (offline, timeout, DNS).
  final int? status;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;

  bool get isNetwork => status == null;
  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;
  bool get isConflict => status == 409;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(
        code: 'NETWORK',
        message: e.message ?? 'Network error',
      );
    }
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final fields = <String, String>{};
      final fe = data['fieldErrors'];
      if (fe is Map) {
        fe.forEach((k, v) => fields['$k'] = '$v');
      }
      return ApiException(
        status: res.statusCode,
        code: (data['code'] as String?) ?? 'HTTP_${res.statusCode}',
        message: (data['message'] as String?) ?? 'Request failed',
        fieldErrors: fields,
      );
    }
    return ApiException(
      status: res.statusCode,
      code: 'HTTP_${res.statusCode}',
      message: 'Request failed',
    );
  }

  @override
  String toString() => 'ApiException($status, $code, $message)';
}
