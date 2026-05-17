import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/user_profile_model.dart';

class UserProfileRemoteDataSource {
  final ApiClient _client;

  UserProfileRemoteDataSource({required ApiClient client}) : _client = client;

  Future<UserProfileModel> getProfile({required String userId}) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.userProfile,
        queryParameters: {'user_id': userId},
      );
      return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<UserProfileModel> updateProfile({
    required String userId,
    String? displayName,
    String? preferredLanguage,
    bool? marketingOptIn,
  }) async {
    try {
      final response = await _client.dio.patch(
        ApiEndpoints.userProfile,
        queryParameters: {'user_id': userId},
        data: {
          'display_name': ?displayName,
          'preferred_language': ?preferredLanguage,
          'marketing_opt_in': ?marketingOptIn,
        },
      );
      return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
