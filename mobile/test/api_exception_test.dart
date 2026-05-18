import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loob_app/core/network/api_exception.dart';

void main() {
  test('extracts API error code and trace id from backend response', () {
    final exception = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/users/profile'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/users/profile'),
          statusCode: 400,
          data: const {
            'error': 'unsupported country',
            'error_code': 'USR_UNSUPPORTED_COUNTRY',
            'trace_id': 'tr_test',
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(exception.message, 'unsupported country');
    expect(exception.errorCode, 'USR_UNSUPPORTED_COUNTRY');
    expect(exception.traceId, 'tr_test');
    expect(exception.statusCode, 400);
  });
}
