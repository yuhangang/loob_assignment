import '../../../menu/data/models/catalog_model.dart';

/// Represents a customized product in the user's shopping cart.
class CartItem {
  final ProductModel product;
  final List<CustomizationOptionModel> selectedOptions;

  /// Raw option IDs retained when the cart is hydrated from the API.
  ///
  /// The backend cart response stores IDs, while local menu selections carry
  /// full option models. Checkout and quantity updates must preserve either
  /// source so customized items remain valid after app restart.
  final List<int> customizationOptionIds;
  final int quantity;

  /// Server-assigned cart_items.id — null until confirmed by the API.
  final int? serverId;

  /// Whether this item is currently available at the selected store.
  /// Set to true by default; updated when the cart is loaded from the server.
  final bool isAvailable;

  const CartItem({
    required this.product,
    required this.selectedOptions,
    this.customizationOptionIds = const [],
    required this.quantity,
    this.serverId,
    this.isAvailable = true,
  });

  List<int> get selectedCustomizationIds {
    if (selectedOptions.isNotEmpty) {
      return selectedOptions.map((option) => option.id).toList()..sort();
    }
    return List<int>.from(customizationOptionIds)..sort();
  }

  /// Calculates the price of a single item including all customization adjustments.
  int get unitPrice {
    var price = product.basePrice;
    for (final option in selectedOptions) {
      price += option.priceAdjustment;
    }
    return price;
  }

  /// Calculates the total price for the given quantity.
  int get totalPrice => unitPrice * quantity;

  bool hasSameConfiguration(CartItem other) {
    return other.product.id == product.id &&
        _listEquals(other.selectedCustomizationIds, selectedCustomizationIds);
  }

  CartItem copyWith({
    ProductModel? product,
    List<CustomizationOptionModel>? selectedOptions,
    List<int>? customizationOptionIds,
    int? quantity,
    int? serverId,
    bool? isAvailable,
  }) {
    return CartItem(
      product: product ?? this.product,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      customizationOptionIds:
          customizationOptionIds ?? this.customizationOptionIds,
      quantity: quantity ?? this.quantity,
      serverId: serverId ?? this.serverId,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.product.id == product.id &&
        _listEquals(other.selectedCustomizationIds, selectedCustomizationIds) &&
        other.quantity == quantity &&
        other.serverId == serverId &&
        other.isAvailable == isAvailable;
  }

  @override
  int get hashCode => Object.hash(
    product.id,
    Object.hashAll(selectedCustomizationIds),
    quantity,
    serverId,
    isAvailable,
  );

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
