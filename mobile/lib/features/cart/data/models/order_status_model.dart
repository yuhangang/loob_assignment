import 'checkout_response_model.dart';

/// Mapped from Go `checkout.OrderStatus`.
class OrderStatusModel {
  final String orderTrackingId;
  final String status;
  final String paymentStatus;
  final int subtotal;
  final List<ChargeLineModel> charges;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;
  final String createdAt;
  final String updatedAt;

  const OrderStatusModel({
    required this.orderTrackingId,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    this.charges = const [],
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderStatusModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusModel(
      orderTrackingId: json['order_tracking_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      subtotal: json['subtotal'] as int? ?? 0,
      charges: (json['charges'] as List<dynamic>? ?? const [])
          .map((e) => ChargeLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxAmount: json['tax_amount'] as int? ?? 0,
      discountAmount: json['discount_amount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}
