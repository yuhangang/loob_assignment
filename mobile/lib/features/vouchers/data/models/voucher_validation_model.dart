class VoucherValidationModel {
  final String code;
  final bool isValid;
  final String? reason;
  final int eligibleSubtotal;
  final int discountAmount;

  const VoucherValidationModel({
    required this.code,
    required this.isValid,
    this.reason,
    required this.eligibleSubtotal,
    required this.discountAmount,
  });

  factory VoucherValidationModel.fromJson(Map<String, dynamic> json) {
    return VoucherValidationModel(
      code: json['code'] as String? ?? '',
      isValid: json['is_valid'] as bool? ?? false,
      reason: json['reason'] as String?,
      eligibleSubtotal: json['eligible_subtotal'] as int? ?? 0,
      discountAmount: json['discount_amount'] as int? ?? 0,
    );
  }
}
