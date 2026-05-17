import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/app_config_model.dart';
import '../models/feed_response_model.dart';

/// Remote data source for home/app config endpoints.
///
/// Uses [ApiClient] so all requests are routed through the flavor-configured
/// [baseUrl] and the auth / context interceptors.
class HomeRemoteDataSource {
  final ApiClient _client;

  HomeRemoteDataSource({required ApiClient client}) : _client = client;

  Future<AppConfigModel> getAppConfig() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.appConfig);
      return AppConfigModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<FeedResponseModel> getFeed() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.appFeed);
      return FeedResponseModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

