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
      final response = await _client.dio.get(ApiEndpoints.userProfile);
      return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<WalletHistoryModel> getWalletHistory({required String userId}) async {
    try {
      final response = await _client.dio.get(ApiEndpoints.userWalletHistory);
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
      final response = await _client.dio.get(ApiEndpoints.userLoyaltyHistory);
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
    String? registeredCountryId,
    bool? marketingOptIn,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['display_name'] = displayName;
      if (preferredLanguage != null) {
        body['preferred_language'] = preferredLanguage;
      }
      if (registeredCountryId != null) {
        body['registered_country_id'] = registeredCountryId;
      }
      if (marketingOptIn != null) body['marketing_opt_in'] = marketingOptIn;

      final response = await _client.dio.patch(
        ApiEndpoints.userProfile,
        data: body,
      );
      return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
