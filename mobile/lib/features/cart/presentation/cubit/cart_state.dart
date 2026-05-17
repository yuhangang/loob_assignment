import 'package:equatable/equatable.dart';
import '../../../menu/data/models/store_model.dart';
import 'cart_item.dart';

/// Represents the current loading phase of the cart.
enum CartLoadStatus { initial, loading, loaded, error }

/// State representing the contents and metadata of the shopping cart.
class CartState extends Equatable {
  final List<CartItem> items;
  final String currency;

  /// Active store ID — used for server-side upsert calls.
  final int storeId;

  /// Selected store snapshot, including current operational status.
  final StoreModel? selectedStore;

  /// Active country code — scopes all cart operations.
  final String countryCode;

  /// Current load state from the server.
  final CartLoadStatus loadStatus;

  const CartState({
    this.items = const [],
    this.currency = 'MYR',
    this.storeId = 0,
    this.selectedStore,
    this.countryCode = 'MY',
    this.loadStatus = CartLoadStatus.initial,
  });

  /// Total count of items currently in the cart.
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  /// Total price of all items in the cart in cents (unavailable items excluded).
  int get totalPrice => items
      .where((i) => i.isAvailable)
      .fold(0, (sum, item) => sum + item.totalPrice);

  /// True if any item in the cart is flagged as unavailable.
  bool get hasUnavailableItems => items.any((i) => !i.isAvailable);

  bool get isSelectedStoreClosed => selectedStore?.acceptsOrders == false;

  String get selectedStoreClosureMessage {
    final store = selectedStore;
    if (store == null || store.acceptsOrders) return '';
    return store.statusMessage.isNotEmpty
        ? store.statusMessage
        : '${store.name} is ${store.displayStatus.toLowerCase()}.';
  }

  CartState copyWith({
    List<CartItem>? items,
    String? currency,
    int? storeId,
    StoreModel? selectedStore,
    String? countryCode,
    CartLoadStatus? loadStatus,
  }) {
    return CartState(
      items: items ?? this.items,
      currency: currency ?? this.currency,
      storeId: storeId ?? this.storeId,
      selectedStore: selectedStore ?? this.selectedStore,
      countryCode: countryCode ?? this.countryCode,
      loadStatus: loadStatus ?? this.loadStatus,
    );
  }

  @override
  List<Object?> get props => [
    items,
    currency,
    storeId,
    selectedStore,
    countryCode,
    loadStatus,
  ];
}
