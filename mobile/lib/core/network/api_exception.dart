import 'package:dio/dio.dart';

/// Typed wrapper around Dio errors for consistent error handling.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
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
          statusCode: e.response?.statusCode,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final data = e.response?.data;
        String message = 'Something went wrong.';
        if (data is Map<String, dynamic> && data.containsKey('error')) {
          message = data['error'] as String;
        }
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Unable to connect. Please check your internet.',
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
  String toString() => 'ApiException($statusCode): $message';
}

