import '../../data/models/user_profile_model.dart';

abstract class IUserProfileRepository {
  String get currentUserId;
  String get defaultCountryCode;
  Future<UserProfileModel> getProfile();
  Future<WalletHistoryModel> getWalletHistory();
  Future<WalletHistoryModel> topUpWallet(int amount);
  Future<LoyaltyHistoryModel> getLoyaltyHistory();
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? preferredLanguage,
    String? registeredCountryId,
    bool? marketingOptIn,
  });
}
