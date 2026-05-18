import '../../data/models/wallet_model.dart';
import '../../data/models/voucher_validation_model.dart';

abstract class IVoucherRepository {
  Future<WalletModel> getWallet({
    String? countryCode,
    String? userId,
    int brandId = 0,
  });

  Future<VoucherValidationModel> validateVoucher({
    String? countryCode,
    required Map<String, dynamic> body,
  });
}
