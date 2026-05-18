import 'dart:async' show Timer, unawaited;
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../menu/data/models/catalog_model.dart';
import '../../data/datasources/cart_remote_data_source.dart';
import '../../data/models/cart_api_model.dart';
import 'cart_event.dart';
import 'cart_item.dart';
import 'cart_state.dart';

/// Bloc managing all cart interactions and local state transitions.
///
/// When [remoteDataSource] is provided, all mutations sync with the backend
/// via the consolidated `POST /cart/update` endpoint and [CartLoadRequested]
/// hydrates state from the server on startup or when the active store changes.
///
/// The UI always updates **optimistically** — local state changes instantly
/// and the API call happens in the background.
class CartBloc extends Bloc<CartEvent, CartState> {
  final CartRemoteDataSource? remoteDataSource;

  /// The authenticated user ID — set this once the user logs in.
  final String userId;

  /// Periodic availability refresh timer.
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 60);

  CartBloc({
    this.remoteDataSource,
    this.userId = 'mock_user_001',
    String countryCode = 'MY',
  }) : super(CartState(countryCode: countryCode)) {
    on<CartSwitchCountry>(_onSwitchCountry);
    on<CartSetStore>(_onSetStore);
    on<CartLoadRequested>(_onLoadRequested);
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartItemQuantityUpdated>(_onItemQuantityUpdated);
    on<CartItemConfigurationUpdated>(_onItemConfigurationUpdated);
    on<CartCleared>(_onCleared);
    on<CartServerIdsApplied>(_onServerIdsApplied);
    on<CartAvailabilityPollStarted>(_onPollStarted);
    on<CartAvailabilityPollStopped>(_onPollStopped);
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  // ── Country management ─────────────────────────────────────────────────────

  /// Switches the active country and reloads the cart for that country.
  /// Clears local state immediately so the UI doesn't show stale items.
  void _onSwitchCountry(CartSwitchCountry event, Emitter<CartState> emit) {
    emit(
      CartState(
        countryCode: event.countryCode,
        currency: event.currency,
        storeId: state.storeId,
        selectedStore: state.selectedStore,
        loadStatus: CartLoadStatus.loading,
      ),
    );
    add(const CartLoadRequested());
  }

  /// Sets the active store — needed for backend upsert calls.
  /// When the store changes, triggers a cart reload to revalidate availability.
  void _onSetStore(CartSetStore event, Emitter<CartState> emit) {
    final storeChanged = state.storeId != event.store.id;
    if (storeChanged || state.selectedStore != event.store) {
      emit(state.copyWith(storeId: event.store.id, selectedStore: event.store));
    }
    // Reload cart with new store so is_available flags are re-evaluated.
    if (storeChanged && state.items.isNotEmpty) {
      add(CartLoadRequested(storeId: event.store.id));
    }
  }

  // ── Server hydration ───────────────────────────────────────────────────────

  /// Fetches the current cart from the server and rebuilds local state.
  ///
  /// Items are rebuilt as [CartItem] objects using the product snapshot
  /// returned by the backend (no separate catalog call needed).
  /// Unavailable items are preserved in the list but flagged via [CartItem.isAvailable].
  Future<void> _onLoadRequested(
    CartLoadRequested event,
    Emitter<CartState> emit,
  ) async {
    final ds = remoteDataSource;
    if (ds == null || userId.isEmpty) return;

    emit(state.copyWith(loadStatus: CartLoadStatus.loading));

    try {
      final resp = await ds.getCart(
        userId: userId,
        countryCode: state.countryCode,
        storeId: event.storeId ?? state.storeId,
      );
      final items = resp.items.map(_apiItemToCartItem).toList();
      final resolvedStoreId = event.storeId ?? state.storeId;
      emit(
        state.copyWith(
          items: items,
          storeId: resolvedStoreId > 0
              ? resolvedStoreId
              : (items.isNotEmpty ? resp.items.first.storeId : state.storeId),
          loadStatus: CartLoadStatus.loaded,
        ),
      );
    } catch (e) {
      developer.log('CartBloc: loadCart failed: $e', name: 'cart');
      emit(state.copyWith(loadStatus: CartLoadStatus.error));
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _onPollStarted(
    CartAvailabilityPollStarted event,
    Emitter<CartState> emit,
  ) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!isClosed && state.items.isNotEmpty) {
        add(CartLoadRequested(storeId: state.storeId));
      }
    });
  }

  void _onPollStopped(
    CartAvailabilityPollStopped event,
    Emitter<CartState> emit,
  ) {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Adds an item to the cart. Merges identical items (same product + options).
  void _onItemAdded(CartItemAdded event, Emitter<CartState> emit) {
    final quantity = event.quantity;
    if (quantity <= 0) return;

    final sortedOptions = List<CustomizationOptionModel>.from(
      event.selectedOptions,
    )..sort((a, b) => a.id.compareTo(b.id));
    final sortedOptionIds = event.customizationOptionIds == null
        ? sortedOptions.map((o) => o.id).toList()
        : (List<int>.from(event.customizationOptionIds!)..sort());

    final newItem = CartItem(
      product: event.product,
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

    _syncUpdate(
      method: 'upsert',
      menuItemId: event.product.id,
      quantity: existingIndex != -1
          ? currentItems[existingIndex].quantity
          : quantity,
      customizationOptionIds: sortedOptionIds,
    );
  }

  /// Removes a specific customized item from the cart.
  void _onItemRemoved(CartItemRemoved event, Emitter<CartState> emit) {
    final serverId = event.item.serverId;
    final currentItems = List<CartItem>.from(state.items);
    currentItems.remove(event.item);
    emit(state.copyWith(items: currentItems));

    if (serverId != null) {
      _syncUpdate(method: 'remove', itemId: serverId);
    }
  }

  /// Updates the quantity of a cart item. Removes it when quantity ≤ 0.
  void _onItemQuantityUpdated(
    CartItemQuantityUpdated event,
    Emitter<CartState> emit,
  ) {
    final quantity = event.quantity;
    if (quantity <= 0) {
      add(CartItemRemoved(event.item));
      return;
    }

    final currentItems = List<CartItem>.from(state.items);
    final index = currentItems.indexOf(event.item);

    if (index != -1) {
      currentItems[index] = currentItems[index].copyWith(quantity: quantity);
      emit(state.copyWith(items: currentItems));

      _syncUpdate(
        method: 'upsert',
        menuItemId: event.item.product.id,
        quantity: quantity,
        customizationOptionIds: event.item.selectedCustomizationIds,
      );
    }
  }

  /// Replaces an existing cart line with updated quantity and customizations.
  ///
  /// If the new configuration matches another line already in the cart, the
  /// lines are merged so checkout still submits one backend line per config.
  void _onItemConfigurationUpdated(
    CartItemConfigurationUpdated event,
    Emitter<CartState> emit,
  ) {
    final quantity = event.quantity;
    if (quantity <= 0) {
      add(CartItemRemoved(event.item));
      return;
    }

    final sortedOptions = List<CustomizationOptionModel>.from(
      event.selectedOptions,
    )..sort((a, b) => a.id.compareTo(b.id));
    final customizationOptionIds = sortedOptions.isEmpty
        ? event.item.selectedCustomizationIds
        : sortedOptions.map((o) => o.id).toList();
    final updatedItem = CartItem(
      product: event.item.product,
      selectedOptions: List.unmodifiable(sortedOptions),
      customizationOptionIds: customizationOptionIds,
      quantity: quantity,
      serverId: event.item.serverId,
      isAvailable: event.item.isAvailable,
    );

    final currentItems = List<CartItem>.from(state.items);
    final originalIndex = currentItems.indexOf(event.item);
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
      event.item.selectedCustomizationIds,
      updatedItem.selectedCustomizationIds,
    );
    if (changedConfiguration && event.item.serverId != null) {
      _syncUpdate(
        method: 'update',
        itemId: event.item.serverId!,
        menuItemId: updatedItem.product.id,
        quantity: mergedQuantity,
        customizationOptionIds: updatedItem.selectedCustomizationIds,
      );
      return;
    }
    _syncUpdate(
      method: 'upsert',
      menuItemId: updatedItem.product.id,
      quantity: mergedQuantity,
      customizationOptionIds: updatedItem.selectedCustomizationIds,
    );
  }

  /// Wipes all items from the cart.
  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    emit(state.copyWith(items: const []));
    _syncUpdate(method: 'clear');
  }

  // ── Server sync helpers ────────────────────────────────────────────────────

  /// Consolidated sync — all mutations go through `POST /cart/update`.
  void _syncUpdate({
    required String method,
    int? itemId,
    int? menuItemId,
    int? quantity,
    List<int>? customizationOptionIds,
  }) {
    final ds = remoteDataSource;
    if (ds == null || userId.isEmpty) return;

    unawaited(
      ds
          .updateCart(
            method: method,
            userId: userId,
            countryCode: state.countryCode,
            storeId: state.storeId,
            itemId: itemId,
            menuItemId: menuItemId,
            quantity: quantity,
            customizationOptionIds: customizationOptionIds,
          )
          .then((resp) {
            // Refresh serverIds and availability from the latest server response.
            add(CartServerIdsApplied(resp));
          })
          .catchError((Object e) {
            developer.log('CartBloc: sync ($method) failed: $e', name: 'cart');
          }),
    );
  }

  /// After a mutation, the server responds with the full cart including
  /// server-assigned IDs and updated availability. Update local state.
  void _onServerIdsApplied(
    CartServerIdsApplied event,
    Emitter<CartState> emit,
  ) {
    final updatedItems = List<CartItem>.from(state.items);
    for (int i = 0; i < updatedItems.length; i++) {
      final local = updatedItems[i];
      final sortedIds = local.selectedCustomizationIds;
      final match = event.apiResponse.items.where((api) {
        final apiSorted = List<int>.from(api.customizationOptionIds)..sort();
        return api.menuItemId == local.product.id &&
            _listEquals(apiSorted, sortedIds);
      }).firstOrNull;
      if (match != null) {
        // Rebuild selected options with updated availability from server.
        final updatedOptions = match.customizationOptions.map((option) {
          return CustomizationOptionModel(
            code: option.code,
            id: option.id,
            name: option.name,
            priceAdjustment: option.priceAdjustment,
            isDefault: false,
            isAvailable: option.isAvailable,
          );
        }).toList();

        updatedItems[i] = local.copyWith(
          serverId: match.id,
          isAvailable: match.isAvailable,
          selectedOptions: updatedOptions.isNotEmpty ? updatedOptions : null,
        );
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
