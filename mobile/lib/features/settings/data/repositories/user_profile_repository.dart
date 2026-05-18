import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../datasources/user_profile_remote_data_source.dart';
import '../models/user_profile_model.dart';

class UserProfileRepository {
  final UserProfileRemoteDataSource _remote;
  final AuthService _authService;
  final AppConfig _config;

  UserProfileRepository({
    required ApiClient client,
    required AuthService authService,
    required AppConfig config,
  }) : _remote = UserProfileRemoteDataSource(client: client),
       _authService = authService,
       _config = config;

  String get currentUserId => _authService.currentUser?.uid ?? '';
  String get defaultCountryCode => _config.defaultCountryCode;

  Future<UserProfileModel> getProfile() {
    return _remote.getProfile(userId: currentUserId);
  }

  Future<WalletHistoryModel> getWalletHistory() {
    return _remote.getWalletHistory(userId: currentUserId);
  }

  Future<WalletHistoryModel> topUpWallet(int amount) {
    return _remote.topUpWallet(userId: currentUserId, amount: amount);
  }

  Future<LoyaltyHistoryModel> getLoyaltyHistory() {
    return _remote.getLoyaltyHistory(userId: currentUserId);
  }

  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? preferredLanguage,
    bool? marketingOptIn,
  }) {
    return _remote.updateProfile(
      userId: currentUserId,
      displayName: displayName,
      preferredLanguage: preferredLanguage,
      marketingOptIn: marketingOptIn,
    );
  }
}
