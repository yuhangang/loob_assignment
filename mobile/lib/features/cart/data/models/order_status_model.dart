import 'checkout_response_model.dart';

class OrderStatusItemOptionModel {
  final int id;
  final int groupId;
  final String name;
  final int priceAdjustment;

  const OrderStatusItemOptionModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.priceAdjustment,
  });

  factory OrderStatusItemOptionModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusItemOptionModel(
      id: json['id'] as int? ?? 0,
      groupId: json['group_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      priceAdjustment: json['price_adjustment'] as int? ?? 0,
    );
  }
}

class OrderStatusItemModel {
  final int menuItemId;
  final String name;
  final int quantity;
  final int basePrice;
  final List<OrderStatusItemOptionModel> customizationOptions;

  const OrderStatusItemModel({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.basePrice,
    this.customizationOptions = const [],
  });

  factory OrderStatusItemModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusItemModel(
      menuItemId: json['menu_item_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      basePrice: json['base_price'] as int? ?? 0,
      customizationOptions: (json['customization_options'] as List<dynamic>? ?? const [])
          .map((e) => OrderStatusItemOptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  int get unitPrice =>
      basePrice +
      customizationOptions.fold<int>(0, (sum, opt) => sum + opt.priceAdjustment);

  int get totalPrice => unitPrice * quantity;
}

/// Mapped from Go `checkout.OrderStatus`.
class OrderStatusModel {
  final String orderTrackingId;
  final String status;
  final String paymentStatus;
  final String paymentTransactionId;
  final int subtotal;
  final List<ChargeLineModel> charges;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;
  final String createdAt;
  final String updatedAt;
  final List<OrderStatusItemModel> items;

  const OrderStatusModel({
    required this.orderTrackingId,
    required this.status,
    required this.paymentStatus,
    this.paymentTransactionId = '',
    required this.subtotal,
    this.charges = const [],
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory OrderStatusModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusModel(
      orderTrackingId: json['order_tracking_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      paymentTransactionId: json['payment_transaction_id'] as String? ?? '',
      subtotal: json['subtotal'] as int? ?? 0,
      charges: (json['charges'] as List<dynamic>? ?? const [])
          .map((e) => ChargeLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxAmount: json['tax_amount'] as int? ?? 0,
      discountAmount: json['discount_amount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => OrderStatusItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
