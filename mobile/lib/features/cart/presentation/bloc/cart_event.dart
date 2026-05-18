import 'package:equatable/equatable.dart';
import '../../../menu/data/models/catalog_model.dart';
import '../../../menu/data/models/store_model.dart';
import '../../data/models/cart_api_model.dart';
import 'cart_item.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class CartSwitchCountry extends CartEvent {
  final String countryCode;
  final String currency;

  const CartSwitchCountry({required this.countryCode, this.currency = 'MYR'});

  @override
  List<Object?> get props => [countryCode, currency];
}

class CartSetStore extends CartEvent {
  final StoreModel store;

  const CartSetStore(this.store);

  @override
  List<Object?> get props => [store];
}

class CartLoadRequested extends CartEvent {
  /// When set, availability is evaluated against this store instead of the
  /// store_id persisted on each cart row.
  final int? storeId;

  const CartLoadRequested({this.storeId});

  @override
  List<Object?> get props => [storeId];
}

/// Starts a periodic timer that re-fetches the cart to refresh availability.
class CartAvailabilityPollStarted extends CartEvent {
  const CartAvailabilityPollStarted();
}

/// Stops the periodic availability polling timer.
class CartAvailabilityPollStopped extends CartEvent {
  const CartAvailabilityPollStopped();
}

class CartItemAdded extends CartEvent {
  final ProductModel product;
  final List<CustomizationOptionModel> selectedOptions;
  final List<int>? customizationOptionIds;
  final int quantity;

  const CartItemAdded({
    required this.product,
    required this.selectedOptions,
    this.customizationOptionIds,
    required this.quantity,
  });

  @override
  List<Object?> get props => [product, selectedOptions, customizationOptionIds, quantity];
}

class CartItemRemoved extends CartEvent {
  final CartItem item;

  const CartItemRemoved(this.item);

  @override
  List<Object?> get props => [item];
}

class CartItemQuantityUpdated extends CartEvent {
  final CartItem item;
  final int quantity;

  const CartItemQuantityUpdated({required this.item, required this.quantity});

  @override
  List<Object?> get props => [item, quantity];
}

class CartItemConfigurationUpdated extends CartEvent {
  final CartItem item;
  final List<CustomizationOptionModel> selectedOptions;
  final int quantity;

  const CartItemConfigurationUpdated({
    required this.item,
    required this.selectedOptions,
    required this.quantity,
  });

  @override
  List<Object?> get props => [item, selectedOptions, quantity];
}

class CartCleared extends CartEvent {
  const CartCleared();
}

/// Internal event fired after a server upsert/remove/update call successfully
/// completes, carrying the latest [CartApiResponse] to map server item IDs safely.
class CartServerIdsApplied extends CartEvent {
  final CartApiResponse apiResponse;

  const CartServerIdsApplied(this.apiResponse);

  @override
  List<Object?> get props => [apiResponse];
}
