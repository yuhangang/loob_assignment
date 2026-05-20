import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_remote_data_source.dart';
import '../models/user_profile_model.dart';
import '../models/wallet_topup_response_model.dart';

class UserProfileRepositoryImpl implements IUserProfileRepository {
  final UserProfileRemoteDataSource _remote;
  final AuthService _authService;
  final AppConfig _config;

  const UserProfileRepositoryImpl({
    required UserProfileRemoteDataSource remote,
    required AuthService authService,
    required AppConfig config,
  })  : _remote = remote,
        _authService = authService,
        _config = config;

  @override
  String get currentUserId => _authService.currentUser?.uid ?? '';

  @override
  String get defaultCountryCode => _config.defaultCountryCode;

  @override
  Future<UserProfileModel> getProfile() {
    return _remote.getProfile(userId: currentUserId);
  }

  @override
  Future<WalletHistoryModel> getWalletHistory() {
    return _remote.getWalletHistory(userId: currentUserId);
  }

  @override
  Future<WalletTopUpResponseModel> topUpWallet(int amount, String paymentMethod) {
    return _remote.topUpWallet(
      userId: currentUserId,
      amount: amount,
      paymentMethod: paymentMethod,
    );
  }

  @override
  Future<void> confirmMockPayment(String transactionId) {
    return _remote.confirmMockPayment(
      transactionId: transactionId,
      secret: _config.mockGatewaySecret,
    );
  }

  @override
  Future<LoyaltyHistoryModel> getLoyaltyHistory() {
    return _remote.getLoyaltyHistory(userId: currentUserId);
  }

  @override
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? preferredLanguage,
    String? registeredCountryId,
    bool? marketingOptIn,
  }) {
    return _remote.updateProfile(
      userId: currentUserId,
      displayName: displayName,
      preferredLanguage: preferredLanguage,
      registeredCountryId: registeredCountryId,
      marketingOptIn: marketingOptIn,
    );
  }
}
