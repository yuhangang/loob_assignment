import 'package:loob_app/features/vouchers/data/models/voucher_model.dart';

/// Mapped from Go `vouchers.Wallet`.
class WalletModel {
  final String countryCode;
  final String languageResolved;
  final String userId;
  final String currencyCode;
  final int walletBalance;
  final int loyaltyPoints;
  final String loyaltyTier;
  final int voucherCount;
  final List<VoucherModel> vouchers;

  const WalletModel({
    required this.countryCode,
    required this.languageResolved,
    required this.userId,
    required this.currencyCode,
    required this.walletBalance,
    required this.loyaltyPoints,
    required this.loyaltyTier,
    required this.voucherCount,
    required this.vouchers,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final list = json['vouchers'] as List<dynamic>? ?? [];
    return WalletModel(
      countryCode: json['country_code'] as String? ?? '',
      languageResolved: json['language_resolved'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? '',
      walletBalance: json['wallet_balance'] as int? ?? 0,
      loyaltyPoints: json['loyalty_points'] as int? ?? 0,
      loyaltyTier: json['loyalty_tier'] as String? ?? 'MEMBER',
      voucherCount: json['voucher_count'] as int? ?? list.length,
      vouchers: list
          .map((e) => VoucherModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
