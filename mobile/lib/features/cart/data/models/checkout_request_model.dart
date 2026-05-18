/// Mapped from Go `checkout.CheckoutRequest`.
class CheckoutRequestModel {
  final String userId;
  final int storeId;
  final String fulfillmentType;
  final String? voucherCode;
  final String paymentMethod;
  final String idempotencyKey;
  final List<CartItemModel> items;

  const CheckoutRequestModel({
    required this.userId,
    required this.storeId,
    required this.fulfillmentType,
    this.voucherCode,
    required this.paymentMethod,
    required this.idempotencyKey,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'store_id': storeId,
    'fulfillment_type': fulfillmentType,
    if (voucherCode != null) 'voucher_code': voucherCode,
    'payment_method': paymentMethod,
    'idempotency_key': idempotencyKey,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

/// Mapped from Go `checkout.CartItem`.
class CartItemModel {
  final int menuItemId;
  final int quantity;
  final List<int> customizationOptionIds;

  const CartItemModel({
    required this.menuItemId,
    required this.quantity,
    this.customizationOptionIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'menu_item_id': menuItemId,
    'quantity': quantity,
    'customization_option_ids': customizationOptionIds,
  };
}
