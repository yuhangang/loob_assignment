import 'package:equatable/equatable.dart';

/// Mirrors the Go backend's `CartResponse` JSON structure.
class CartApiResponse extends Equatable {
  final String userId;
  final String countryId;
  final List<CartApiItem> items;

  const CartApiResponse({
    required this.userId,
    required this.countryId,
    required this.items,
  });

  factory CartApiResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return CartApiResponse(
      userId: json['user_id'] as String? ?? '',
      countryId: json['country_id'] as String? ?? '',
      items: rawItems
          .map((e) => CartApiItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [userId, countryId, items];
}

/// A single line-item from the server-side cart, enriched with a product
/// snapshot (name, image, price, availability) so no extra catalog call is needed.
class CartApiItem extends Equatable {
  /// Server-generated row ID — used for DELETE /cart/items/:id.
  final int id;
  final int menuItemId;
  final int storeId;
  final int quantity;
  final List<int> customizationOptionIds;

  // Product snapshot (hydrated on the server by joining menu_items).
  final String name;
  final String imageUrlSm;
  final int basePrice;
  final bool isAvailable;
  final List<CartApiOption> customizationOptions;

  const CartApiItem({
    required this.id,
    required this.menuItemId,
    required this.storeId,
    required this.quantity,
    required this.customizationOptionIds,
    required this.name,
    required this.imageUrlSm,
    required this.basePrice,
    required this.isAvailable,
    this.customizationOptions = const [],
  });

  factory CartApiItem.fromJson(Map<String, dynamic> json) {
    final rawIds = json['customization_option_ids'] as List<dynamic>? ?? [];
    final rawOptions = json['customization_options'] as List<dynamic>? ?? [];
    return CartApiItem(
      id: json['id'] as int? ?? 0,
      menuItemId: json['menu_item_id'] as int? ?? 0,
      storeId: json['store_id'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      customizationOptionIds: rawIds.map((e) => e as int).toList(),
      name: json['name'] as String? ?? '',
      imageUrlSm: json['image_url_sm'] as String? ?? '',
      basePrice: json['base_price'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      customizationOptions: rawOptions
          .map((e) => CartApiOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    menuItemId,
    storeId,
    quantity,
    customizationOptionIds,
    name,
    imageUrlSm,
    basePrice,
    isAvailable,
    customizationOptions,
  ];
}

class CartApiOption extends Equatable {
  final int id;
  final int groupId;
  final String code;
  final String name;
  final int priceAdjustment;
  final bool isAvailable;

  const CartApiOption({
    required this.id,
    required this.groupId,
    required this.code,
    required this.name,
    required this.priceAdjustment,
    required this.isAvailable,
  });

  factory CartApiOption.fromJson(Map<String, dynamic> json) {
    return CartApiOption(
      id: json['id'] as int? ?? 0,
      groupId: json['group_id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceAdjustment: json['price_adjustment'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    groupId,
    code,
    name,
    priceAdjustment,
    isAvailable,
  ];
}
