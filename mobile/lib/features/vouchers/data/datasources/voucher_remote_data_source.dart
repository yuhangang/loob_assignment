import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/wallet_model.dart';

/// Remote data source for voucher endpoints.
///
/// Uses [ApiClient] so all requests are routed through the flavor-configured
/// [baseUrl] and the auth / context interceptors.
class VoucherRemoteDataSource {
  final ApiClient _client;

  VoucherRemoteDataSource({required ApiClient client}) : _client = client;

  Future<WalletModel> getWallet({
    required String countryCode,
    required String userId,
    required int brandId,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.vouchersWallet,
        queryParameters: {
          'country_code': countryCode,
          'user_id': userId,
          'brand_id': brandId,
        },
      );
      return WalletModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
