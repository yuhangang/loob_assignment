/// Mapped from Go `checkout.CheckoutResponse`.
class CheckoutResponseModel {
  final String status;
  final String orderTrackingId;
  final String statusUrl;
  final int subtotal;
  final List<ChargeLineModel> charges;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;
  final PaymentTransactionResponseModel? payment;

  const CheckoutResponseModel({
    required this.status,
    required this.orderTrackingId,
    required this.statusUrl,
    required this.subtotal,
    this.charges = const [],
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    this.payment,
  });

  factory CheckoutResponseModel.fromJson(Map<String, dynamic> json) {
    return CheckoutResponseModel(
      status: json['status'] as String? ?? '',
      orderTrackingId: json['order_tracking_id'] as String? ?? '',
      statusUrl: json['status_url'] as String? ?? '',
      subtotal: json['subtotal'] as int? ?? 0,
      charges: (json['charges'] as List<dynamic>? ?? const [])
          .map((e) => ChargeLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxAmount: json['tax_amount'] as int? ?? 0,
      discountAmount: json['discount_amount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      payment: json['payment'] != null
          ? PaymentTransactionResponseModel.fromJson(
              json['payment'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class ChargeLineModel {
  final String code;
  final String name;
  final String scope;
  final int amount;
  final int taxableAmount;
  final int taxAmount;
  final int totalAmount;
  final bool taxable;
  final bool taxInclusive;
  final bool waived;
  final String? waiverReason;

  const ChargeLineModel({
    required this.code,
    required this.name,
    required this.scope,
    required this.amount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.taxable,
    required this.taxInclusive,
    required this.waived,
    this.waiverReason,
  });

  factory ChargeLineModel.fromJson(Map<String, dynamic> json) {
    return ChargeLineModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      taxableAmount: json['taxable_amount'] as int? ?? 0,
      taxAmount: json['tax_amount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      taxable: json['taxable'] as bool? ?? false,
      taxInclusive: json['tax_inclusive'] as bool? ?? false,
      waived: json['waived'] as bool? ?? false,
      waiverReason: json['waiver_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'scope': scope,
      'amount': amount,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'taxable': taxable,
      'tax_inclusive': taxInclusive,
      'waived': waived,
      if (waiverReason != null) 'waiver_reason': waiverReason,
    };
  }
}

/// Mapped from Go `checkout.PaymentTransactionResponse`.
class PaymentTransactionResponseModel {
  final String id;
  final String provider;
  final String methodCode;
  final String status;
  final String currencyCode;
  final int amount;
  final String mockRedirectUrl;

  const PaymentTransactionResponseModel({
    required this.id,
    required this.provider,
    required this.methodCode,
    required this.status,
    required this.currencyCode,
    required this.amount,
    required this.mockRedirectUrl,
  });

  factory PaymentTransactionResponseModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionResponseModel(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      methodCode: json['method_code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      mockRedirectUrl: json['mock_redirect_url'] as String? ?? '',
    );
  }
}
