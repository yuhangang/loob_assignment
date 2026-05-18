import 'package:dio/dio.dart';

/// Typed wrapper around Dio errors for consistent error handling.
class ApiException implements Exception {
  final String message;
  final String? errorCode;
  final String? traceId;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.errorCode,
    this.traceId,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timed out. Please check your network.',
          errorCode: 'API_CONNECTION_TIMEOUT',
          statusCode: e.response?.statusCode,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final data = e.response?.data;
        String message = 'Something went wrong.';
        String? errorCode;
        String? traceId;
        if (data is Map<String, dynamic> && data.containsKey('error')) {
          message = data['error']?.toString() ?? message;
          errorCode =
              data['error_code']?.toString() ?? data['code']?.toString();
          traceId = data['trace_id']?.toString();
        }
        return ApiException(
          message: message,
          errorCode: errorCode,
          traceId: traceId,
          statusCode: statusCode,
          data: data,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Unable to connect. Please check your internet.',
          errorCode: 'API_CONNECTION_ERROR',
        );
      default:
        return ApiException(
          message: e.message ?? 'An unexpected error occurred.',
        );
    }
  }

  /// Alias for [fromDioException] — preferred name used by data sources.
  factory ApiException.fromDioError(DioException e) =>
      ApiException.fromDioException(e);

  @override
  String toString() {
    final code = errorCode == null ? '' : ' [$errorCode]';
    return 'ApiException($statusCode)$code: $message';
  }
}
