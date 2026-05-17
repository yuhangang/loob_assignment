/// Mapped from Go `checkout.CheckoutResponse`.
class CheckoutResponseModel {
  final String status;
  final String orderTrackingId;
  final String statusUrl;
  final int subtotal;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;
  final PaymentTransactionResponseModel? payment;

  const CheckoutResponseModel({
    required this.status,
    required this.orderTrackingId,
    required this.statusUrl,
    required this.subtotal,
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
      taxAmount: json['tax_amount'] as int? ?? 0,
      discountAmount: json['discount_amount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      payment: json['payment'] != null
          ? PaymentTransactionResponseModel.fromJson(
              json['payment'] as Map<String, dynamic>)
          : null,
    );
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
