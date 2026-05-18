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

  Future<WalletHistoryModel> getWalletHistory({required String userId}) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.userWalletHistory,
        queryParameters: {'user_id': userId},
      );
      return WalletHistoryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<WalletHistoryModel> topUpWallet({
    required String userId,
    required int amount,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiEndpoints.userWalletTopups,
        queryParameters: {'user_id': userId},
        data: {'amount': amount, 'description': 'Mobile wallet top-up'},
      );
      return WalletHistoryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<LoyaltyHistoryModel> getLoyaltyHistory({
    required String userId,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.userLoyaltyHistory,
        queryParameters: {'user_id': userId},
      );
      return LoyaltyHistoryModel.fromJson(
        response.data as Map<String, dynamic>,
      );
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
