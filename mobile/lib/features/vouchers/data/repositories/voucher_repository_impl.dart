import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/repositories/voucher_repository.dart';
import '../datasources/voucher_remote_data_source.dart';
import '../models/wallet_model.dart';
import '../models/voucher_validation_model.dart';

class VoucherRepositoryImpl implements IVoucherRepository {
  final VoucherRemoteDataSource _remote;
  final AuthService _authService;
  final AppConfig _config;

  const VoucherRepositoryImpl({
    required VoucherRemoteDataSource remote,
    required AuthService authService,
    required AppConfig config,
  })  : _remote = remote,
        _authService = authService,
        _config = config;

  @override
  Future<WalletModel> getWallet({
    String? countryCode,
    String? userId,
    int brandId = 0,
  }) =>
      _remote.getWallet(
        countryCode: countryCode ?? _config.defaultCountryCode,
        userId: userId ?? _authService.currentUser?.uid ?? '',
        brandId: brandId,
      );

  @override
  Future<VoucherValidationModel> validateVoucher({
    String? countryCode,
    required Map<String, dynamic> body,
  }) =>
      _remote.validateVoucher(
        countryCode: countryCode ?? _config.defaultCountryCode,
        body: body,
      );
}
