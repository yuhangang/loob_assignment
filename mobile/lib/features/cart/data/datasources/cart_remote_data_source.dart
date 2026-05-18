import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/cart_api_model.dart';
import '../models/checkout_response_model.dart';
import '../models/order_status_model.dart';
import '../models/payment_method_model.dart';

/// Remote data source for cart/checkout/payments endpoints.
///
/// Uses [ApiClient] so all requests are routed through the flavor-configured
/// [baseUrl] and the auth / context interceptors.
class CartRemoteDataSource {
  final ApiClient _client;

  CartRemoteDataSource({required ApiClient client}) : _client = client;

  // ── Cart CRUD ──────────────────────────────────────────────────────────────

  /// Fetches the current server-side cart for [userId].
  ///
  /// When [storeId] is provided, availability is evaluated against that store
  /// instead of the store_id stored in each cart row.
  Future<CartApiResponse> getCart({
    required String userId,
    required String countryCode,
    int? storeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'user_id': userId};
      if (storeId != null && storeId > 0) {
        queryParams['store_id'] = storeId;
      }
      final response = await _client.dio.get(
        ApiEndpoints.cart,
        queryParameters: queryParams,
        options: Options(headers: {'X-Country-Code': countryCode}),
      );
      return CartApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Consolidated cart mutation endpoint.
  ///
  /// [method] is one of: `upsert`, `update`, `remove`, `clear`.
  /// Returns the full refreshed cart after the operation.
  Future<CartApiResponse> updateCart({
    required String method,
    required String userId,
    required String countryCode,
    int storeId = 0,
    int? itemId,
    int? menuItemId,
    int? quantity,
    List<int>? customizationOptionIds,
  }) async {
    try {
      final body = <String, dynamic>{
        'method': method,
        'user_id': userId,
        'store_id': storeId,
      };
      if (itemId != null) body['item_id'] = itemId;
      if (menuItemId != null) body['menu_item_id'] = menuItemId;
      if (quantity != null) body['quantity'] = quantity;
      if (customizationOptionIds != null) {
        body['customization_option_ids'] = customizationOptionIds;
      }
      final response = await _client.dio.post(
        ApiEndpoints.cartUpdate,
        data: body,
        options: Options(headers: {'X-Country-Code': countryCode}),
      );
      return CartApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ── Legacy endpoints (kept for backward compatibility) ─────────────────────

  /// Adds a new item or updates the quantity of an existing matching item.
  ///
  /// Returns the full refreshed cart after the operation.
  Future<CartApiResponse> upsertCartItem({
    required String userId,
    required String countryCode,
    required int storeId,
    required int menuItemId,
    required int quantity,
    required List<int> customizationOptionIds,
  }) async {
    try {
      final response = await _client.dio.put(
        ApiEndpoints.cartItems,
        data: {
          'user_id': userId,
          'store_id': storeId,
          'menu_item_id': menuItemId,
          'quantity': quantity,
          'customization_option_ids': customizationOptionIds,
        },
        options: Options(headers: {'X-Country-Code': countryCode}),
      );
      return CartApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Replaces an existing cart line item by server-side [itemId].
  Future<CartApiResponse> updateCartItem({
    required int itemId,
    required String userId,
    required String countryCode,
    required int storeId,
    required int menuItemId,
    required int quantity,
    required List<int> customizationOptionIds,
  }) async {
    try {
      final response = await _client.dio.patch(
        ApiEndpoints.cartItem(itemId),
        data: {
          'user_id': userId,
          'store_id': storeId,
          'menu_item_id': menuItemId,
          'quantity': quantity,
          'customization_option_ids': customizationOptionIds,
        },
        options: Options(headers: {'X-Country-Code': countryCode}),
      );
      return CartApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Removes a single cart item by its server-side [itemId].
  ///
  /// Returns the full refreshed cart after the operation.
  Future<CartApiResponse> removeCartItem({
    required int itemId,
    required String userId,
    required String countryCode,
  }) async {
    try {
      final response = await _client.dio.delete(
        ApiEndpoints.cartItem(itemId),
        queryParameters: {'user_id': userId},
        options: Options(headers: {'X-Country-Code': countryCode}),
      );
      return CartApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Clears all items in the user's cart.
  Future<void> clearCart({
    required String userId,
    required String countryCode,
  }) async {
    try {
      await _client.dio.delete(
        ApiEndpoints.cart,
        queryParameters: {'user_id': userId},
        options: Options(headers: {'X-Country-Code': countryCode}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ── Payments & Checkout ────────────────────────────────────────────────────

  Future<List<PaymentMethodModel>> listPaymentMethods({
    required String countryCode,
    int? brandId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{'country_code': countryCode};
      if (brandId != null) {
        queryParameters['brand_id'] = brandId;
      }
      final response = await _client.dio.get(
        ApiEndpoints.paymentMethods,
        queryParameters: queryParameters,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => PaymentMethodModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CheckoutResponseModel> checkout(Map<String, dynamic> body) async {
    try {
      final response = await _client.dio.post(
        ApiEndpoints.ordersCheckout,
        data: body,
      );
      return CheckoutResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<OrderStatusModel>> listOrders({
    required String userId,
    required String countryCode,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.orders,
        queryParameters: {'user_id': userId},
        options: Options(headers: {'X-Country-Code': countryCode}),
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => OrderStatusModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<OrderStatusModel> getOrderStatus(String trackingId) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.orderStatus(trackingId),
      );
      return OrderStatusModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
