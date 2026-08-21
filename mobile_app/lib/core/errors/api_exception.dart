import 'package:dio/dio.dart';

/// A typed error mapped from a Dio failure. Screens should branch on
/// [code] (the backend's machine-readable error code — see backend_app's
/// src/errors.ts) rather than matching [message]'s English text.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;

  const ApiException({this.statusCode, required this.message, this.code});

  bool get isUnauthorized => statusCode == 401;

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return ApiException(
        statusCode: e.response?.statusCode,
        message: data['error'] as String,
        code: data['code'] as String?,
      );
    }

    // Deliberately an if-chain rather than a switch: DioExceptionType has
    // gained members across dio versions before, and a switch would need
    // to be exhaustive over whichever set the resolved version has. This
    // degrades gracefully (falls through to the final else) if a future
    // dio version adds a case not listed here.
    final type = e.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return const ApiException(message: 'The importer took too long to respond.');
    }
    if (type == DioExceptionType.connectionError) {
      return const ApiException(
        message: 'Could not reach the importer backend. Check the URL in Settings.',
      );
    }
    if (type == DioExceptionType.badCertificate) {
      return const ApiException(message: "The backend's certificate could not be verified.");
    }
    if (type == DioExceptionType.cancel) {
      return const ApiException(message: 'Request cancelled.');
    }
    if (type == DioExceptionType.badResponse) {
      return ApiException(
        statusCode: e.response?.statusCode,
        message: 'The backend returned an unexpected response.',
      );
    }
    return ApiException(message: e.message ?? 'Unexpected network error.');
  }

  @override
  String toString() => 'ApiException(status: $statusCode, code: $code): $message';
}
