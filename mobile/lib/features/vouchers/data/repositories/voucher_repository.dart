import '../../../../core/network/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../datasources/voucher_remote_data_source.dart';
import '../models/wallet_model.dart';
import '../models/voucher_validation_model.dart';

/// Repository for voucher wallet data.
class VoucherRepository {
  final VoucherRemoteDataSource _remote;
  final AuthService _authService;
  final AppConfig _config;

  VoucherRepository({
    required ApiClient client,
    required AuthService authService,
    required AppConfig config,
  }) : _remote = VoucherRemoteDataSource(client: client),
       _authService = authService,
       _config = config;

  Future<WalletModel> getWallet({
    String? countryCode,
    String? userId,
    int brandId = 0,
  }) => _remote.getWallet(
    countryCode: countryCode ?? _config.defaultCountryCode,
    userId: userId ?? _authService.currentUser?.uid ?? '',
    brandId: brandId,
  );

  Future<VoucherValidationModel> validateVoucher({
    String? countryCode,
    required Map<String, dynamic> body,
  }) => _remote.validateVoucher(
    countryCode: countryCode ?? _config.defaultCountryCode,
    body: body,
  );
}
