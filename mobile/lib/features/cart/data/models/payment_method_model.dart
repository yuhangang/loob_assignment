/// Mapped from Go `payments.Method`.
class PaymentMethodModel {
  final int id;
  final String code;
  final String providerCode;
  final String countryId;
  final int? brandId;
  final String displayName;
  final String description;
  final String currencyCode;
  final int minAmount;
  final int? maxAmount;
  final int displayOrder;
  final Map<String, dynamic> metadata;

  const PaymentMethodModel({
    required this.id,
    required this.code,
    required this.providerCode,
    required this.countryId,
    this.brandId,
    required this.displayName,
    required this.description,
    required this.currencyCode,
    required this.minAmount,
    this.maxAmount,
    required this.displayOrder,
    this.metadata = const {},
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      providerCode: json['provider_code'] as String? ?? '',
      countryId: json['country_id'] as String? ?? '',
      brandId: json['brand_id'] as int?,
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? '',
      minAmount: json['min_amount'] as int? ?? 0,
      maxAmount: json['max_amount'] as int?,
      displayOrder: json['display_order'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
