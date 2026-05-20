import '../../data/models/user_profile_model.dart';
import '../../data/models/wallet_topup_response_model.dart';

abstract class IUserProfileRepository {
  String get currentUserId;
  String get defaultCountryCode;
  Future<UserProfileModel> getProfile();
  Future<WalletHistoryModel> getWalletHistory();
  Future<WalletTopUpResponseModel> topUpWallet(int amount, String paymentMethod);
  Future<void> confirmMockPayment(String transactionId);
  Future<LoyaltyHistoryModel> getLoyaltyHistory();
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? preferredLanguage,
    String? registeredCountryId,
    bool? marketingOptIn,
  });
}
