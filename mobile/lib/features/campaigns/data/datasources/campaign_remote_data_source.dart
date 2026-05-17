import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/home_feed_model.dart';

/// Remote data source for campaign endpoints.
///
/// Uses [ApiClient] so all requests are routed through the flavor-configured
/// [baseUrl] and the auth / context interceptors.
class CampaignRemoteDataSource {
  final ApiClient _client;

  CampaignRemoteDataSource({required ApiClient client}) : _client = client;

  Future<HomeFeedModel> getHomeFeed({
    required String countryCode,
    required String language,
    int? brandId,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.campaignsHome,
        queryParameters: {
          'country_code': countryCode,
          'language': language,
          'brand_id': brandId,
        },
      );
      return HomeFeedModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
