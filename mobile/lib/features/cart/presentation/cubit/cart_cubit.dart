import 'dart:async' show unawaited;
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../menu/data/models/catalog_model.dart';
import '../../../menu/data/models/store_model.dart';
import '../../data/datasources/cart_remote_data_source.dart';
import '../../data/models/cart_api_model.dart';
import 'cart_item.dart';
import 'cart_state.dart';

/// Cubit managing all cart interactions and local state transitions.
///
/// When [remoteDataSource] is provided, all mutations sync with the backend
/// and [loadCart] can be called to hydrate state from the server on startup
/// or when the active country changes.
///
/// The UI always updates **optimistically** — local state changes instantly
/// and the API call happens in the background.
class CartCubit extends Cubit<CartState> {
  final CartRemoteDataSource? remoteDataSource;

  /// The authenticated user ID — set this once the user logs in.
  final String userId;

  CartCubit({
    this.remoteDataSource,
    this.userId = 'mock_user_001',
    String countryCode = 'MY',
  }) : super(CartState(countryCode: countryCode));

  // ── Country management ─────────────────────────────────────────────────────

  /// Switches the active country and reloads the cart for that country.
  /// Clears local state immediately so the UI doesn't show stale items.
  void switchCountry(String countryCode, {String currency = 'MYR'}) {
    emit(
      CartState(
        countryCode: countryCode,
        currency: currency,
        storeId: state.storeId,
        selectedStore: state.selectedStore,
        loadStatus: CartLoadStatus.loading,
      ),
    );
    loadCart();
  }

  /// Sets the active store — needed for backend upsert calls.
  void setStore(StoreModel store) {
    if (state.storeId != store.id || state.selectedStore != store) {
      emit(state.copyWith(storeId: store.id, selectedStore: store));
    }
  }

  // ── Server hydration ───────────────────────────────────────────────────────

  /// Fetches the current cart from the server and rebuilds local state.
  ///
  /// Items are rebuilt as [CartItem] objects using the product snapshot
  /// returned by the backend (no separate catalog call needed).
  /// Unavailable items are preserved in the list but flagged via [CartItem.isAvailable].
  Future<void> loadCart() async {
    final ds = remoteDataSource;
    if (ds == null || userId.isEmpty) return;

    emit(state.copyWith(loadStatus: CartLoadStatus.loading));

    try {
      final resp = await ds.getCart(
        userId: userId,
        countryCode: state.countryCode,
      );
      final items = resp.items.map(_apiItemToCartItem).toList();
      emit(
        state.copyWith(
          items: items,
          storeId: items.isNotEmpty ? resp.items.first.storeId : state.storeId,
          loadStatus: CartLoadStatus.loaded,
        ),
      );
    } catch (e) {
      developer.log('CartCubit: loadCart failed: $e', name: 'cart');
      emit(state.copyWith(loadStatus: CartLoadStatus.error));
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Adds an item to the cart. Merges identical items (same product + options).
  void addToCart({
    required ProductModel product,
    required List<CustomizationOptionModel> selectedOptions,
    List<int>? customizationOptionIds,
    required int quantity,
  }) {
    if (quantity <= 0) return;

    final sortedOptions = List<CustomizationOptionModel>.from(selectedOptions)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedOptionIds = customizationOptionIds == null
        ? sortedOptions.map((o) => o.id).toList()
        : (List<int>.from(customizationOptionIds)..sort());

    final newItem = CartItem(
      product: product,
      selectedOptions: List.unmodifiable(sortedOptions),
      customizationOptionIds: List.unmodifiable(sortedOptionIds),
      quantity: quantity,
    );

    final currentItems = List<CartItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.hasSameConfiguration(newItem),
    );

    if (existingIndex != -1) {
      final existingItem = currentItems[existingIndex];
      currentItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
    } else {
      currentItems.add(newItem);
    }

    emit(state.copyWith(items: currentItems));

    _syncUpsert(
      menuItemId: product.id,
      quantity: existingIndex != -1
          ? currentItems[existingIndex].quantity
          : quantity,
      customizationOptionIds: sortedOptionIds,
    );
  }

  /// Removes a specific customized item from the cart.
  void removeFromCart(CartItem item) {
    final serverId = item.serverId;
    final currentItems = List<CartItem>.from(state.items);
    currentItems.remove(item);
    emit(state.copyWith(items: currentItems));

    if (serverId != null) {
      _syncRemove(serverId);
    }
  }

  /// Updates the quantity of a cart item. Removes it when quantity ≤ 0.
  void updateQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      removeFromCart(item);
      return;
    }

    final currentItems = List<CartItem>.from(state.items);
    final index = currentItems.indexOf(item);

    if (index != -1) {
      currentItems[index] = currentItems[index].copyWith(quantity: quantity);
      emit(state.copyWith(items: currentItems));

      _syncUpsert(
        menuItemId: item.product.id,
        quantity: quantity,
        customizationOptionIds: item.selectedCustomizationIds,
      );
    }
  }

  /// Replaces an existing cart line with updated quantity and customizations.
  ///
  /// If the new configuration matches another line already in the cart, the
  /// lines are merged so checkout still submits one backend line per config.
  void updateItemConfiguration({
    required CartItem item,
    required List<CustomizationOptionModel> selectedOptions,
    required int quantity,
  }) {
    if (quantity <= 0) {
      removeFromCart(item);
      return;
    }

    final sortedOptions = List<CustomizationOptionModel>.from(selectedOptions)
      ..sort((a, b) => a.id.compareTo(b.id));
    final customizationOptionIds = sortedOptions.isEmpty
        ? item.selectedCustomizationIds
        : sortedOptions.map((o) => o.id).toList();
    final updatedItem = CartItem(
      product: item.product,
      selectedOptions: List.unmodifiable(sortedOptions),
      customizationOptionIds: customizationOptionIds,
      quantity: quantity,
      serverId: item.serverId,
      isAvailable: item.isAvailable,
    );

    final currentItems = List<CartItem>.from(state.items);
    final originalIndex = currentItems.indexOf(item);
    if (originalIndex == -1) return;

    currentItems.removeAt(originalIndex);
    final mergeIndex = currentItems.indexWhere(
      (item) => item.hasSameConfiguration(updatedItem),
    );
    final mergedQuantity = mergeIndex == -1
        ? quantity
        : currentItems[mergeIndex].quantity + quantity;

    if (mergeIndex == -1) {
      currentItems.insert(originalIndex, updatedItem);
    } else {
      currentItems[mergeIndex] = currentItems[mergeIndex].copyWith(
        quantity: mergedQuantity,
      );
    }

    emit(state.copyWith(items: currentItems));

    final changedConfiguration = !_listEquals(
      item.selectedCustomizationIds,
      updatedItem.selectedCustomizationIds,
    );
    if (changedConfiguration && item.serverId != null) {
      _syncUpdateItem(
        serverId: item.serverId!,
        menuItemId: updatedItem.product.id,
        quantity: mergedQuantity,
        customizationOptionIds: updatedItem.selectedCustomizationIds,
      );
      return;
    }
    _syncUpsert(
      menuItemId: updatedItem.product.id,
      quantity: mergedQuantity,
      customizationOptionIds: updatedItem.selectedCustomizationIds,
    );
  }

  /// Wipes all items from the cart.
  void clearCart() {
    emit(state.copyWith(items: const []));
    _syncClear();
  }

  // ── Server sync helpers ────────────────────────────────────────────────────

  void _syncUpsert({
    required int menuItemId,
    required int quantity,
    required List<int> customizationOptionIds,
  }) {
    final ds = remoteDataSource;
    if (ds == null || userId.isEmpty) return;

    unawaited(
      ds
          .upsertCartItem(
            userId: userId,
            countryCode: state.countryCode,
            storeId: state.storeId,
            menuItemId: menuItemId,
            quantity: quantity,
            customizationOptionIds: customizationOptionIds,
          )
          .then((resp) {
            // Refresh serverIds from the latest server response.
            _applyServerIds(resp);
          })
          .catchError((Object e) {
            developer.log('CartCubit: upsert sync failed: $e', name: 'cart');
          }),
    );
  }

  void _syncRemove(int serverId) {
    final ds = remoteDataSource;
    if (ds == null || userId.isEmpty) return;

    unawaited(
      ds
          .removeCartItem(
            itemId: serverId,
            userId: userId,
            countryCode: state.countryCode,
          )
          .then(_applyServerIds)
          .catchError((Object e) {
            developer.log('CartCubit: remove sync failed: $e', name: 'cart');
          }),
    );
  }

  void _syncClear() {
    final ds = remoteDataSource;
    if (ds == null || userId.isEmpty) return;

    unawaited(
      ds.clearCart(userId: userId, countryCode: state.countryCode).catchError((
        Object e,
      ) {
        developer.log('CartCubit: clear sync failed: $e', name: 'cart');
      }),
    );
  }

  void _syncUpdateItem({
    required int serverId,
    required int menuItemId,
    required int quantity,
    required List<int> customizationOptionIds,
  }) {
    final ds = remoteDataSource;
    if (ds == null || userId.isEmpty) return;

    unawaited(
      ds
          .updateCartItem(
            itemId: serverId,
            userId: userId,
            countryCode: state.countryCode,
            storeId: state.storeId,
            menuItemId: menuItemId,
            quantity: quantity,
            customizationOptionIds: customizationOptionIds,
          )
          .then(_applyServerIds)
          .catchError((Object e) {
            developer.log('CartCubit: update sync failed: $e', name: 'cart');
          }),
    );
  }

  /// After an upsert, the server responds with the full cart including
  /// server-assigned IDs. Update [CartItem.serverId] so future DELETEs work.
  void _applyServerIds(CartApiResponse resp) {
    final updatedItems = List<CartItem>.from(state.items);
    for (int i = 0; i < updatedItems.length; i++) {
      final local = updatedItems[i];
      final sortedIds = local.selectedCustomizationIds;
      final match = resp.items.where((api) {
        final apiSorted = List<int>.from(api.customizationOptionIds)..sort();
        return api.menuItemId == local.product.id &&
            _listEquals(apiSorted, sortedIds);
      }).firstOrNull;
      if (match != null) {
        updatedItems[i] = local.copyWith(serverId: match.id);
      }
    }
    emit(state.copyWith(items: updatedItems));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a server-side [CartApiItem] into a local [CartItem].
  /// Uses the product snapshot embedded in the API response.
  CartItem _apiItemToCartItem(CartApiItem api) {
    final product = ProductModel(
      id: api.menuItemId,
      skuCode: '',
      isAvailable: api.isAvailable,
      name: api.name,
      description: '',
      media: MediaModel(imageUrlSm: api.imageUrlSm, imageUrlLg: api.imageUrlSm),
      basePrice: api.basePrice,
      dietaryTags: const [],
      customizationGroups: const [],
    );
    final selectedOptions = api.customizationOptions.map((option) {
      return CustomizationOptionModel(
        code: option.code,
        id: option.id,
        name: option.name,
        priceAdjustment: option.priceAdjustment,
        isDefault: false,
        isAvailable: option.isAvailable,
      );
    }).toList();
    return CartItem(
      product: product,
      selectedOptions: selectedOptions,
      customizationOptionIds: api.customizationOptionIds,
      quantity: api.quantity,
      serverId: api.id,
      isAvailable: api.isAvailable,
    );
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
