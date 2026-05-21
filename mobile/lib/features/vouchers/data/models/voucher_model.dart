/// Mapped from Go `vouchers.Voucher`.
class VoucherModel {
  final int id;
  final String code;
  final String title;
  final String description;
  final String termsAndConditionsMarkdown;
  final String termsAndConditionsHtml;
  final String voucherType;
  final String discountType; // PERCENTAGE, FIXED_AMOUNT
  final int discountValue;
  final int minSpend;
  final int? maxDiscountCap;
  final int? brandId;
  final String zoneId;
  final String status; // AVAILABLE, REDEEMED, EXPIRED
  final String startsAt;
  final String expiresAt;

  const VoucherModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    this.termsAndConditionsMarkdown = '',
    this.termsAndConditionsHtml = '',
    required this.voucherType,
    required this.discountType,
    required this.discountValue,
    required this.minSpend,
    this.maxDiscountCap,
    this.brandId,
    this.zoneId = '',
    required this.status,
    required this.startsAt,
    required this.expiresAt,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      termsAndConditionsMarkdown:
          json['terms_and_conditions_markdown'] as String? ?? '',
      termsAndConditionsHtml:
          json['terms_and_conditions_html'] as String? ?? '',
      voucherType: json['voucher_type'] as String? ?? '',
      discountType: json['discount_type'] as String? ?? '',
      discountValue: json['discount_value'] as int? ?? 0,
      minSpend: json['min_spend'] as int? ?? 0,
      maxDiscountCap: json['max_discount_cap'] as int?,
      brandId: json['brand_id'] as int?,
      zoneId: json['zone_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startsAt: json['starts_at'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
    );
  }

  String get termsAndConditionsText {
    final raw = termsAndConditionsMarkdown.trim().isNotEmpty
        ? termsAndConditionsMarkdown
        : termsAndConditionsHtml;
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAllMapped(
          RegExp(r'(^|\n)\s*[-*]\s*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'[*_`#>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
