import '../../../../core/network/api_client.dart';
import '../datasources/cart_remote_data_source.dart';
import '../models/checkout_response_model.dart';
import '../models/order_status_model.dart';
import '../models/payment_method_model.dart';

/// Repository for cart, checkout, and payment data.
class CartRepository {
  final CartRemoteDataSource _remote;

  CartRepository({required ApiClient client})
    : _remote = CartRemoteDataSource(client: client);

  Future<List<PaymentMethodModel>> listPaymentMethods({
    required String countryCode,
    int? brandId,
  }) => _remote.listPaymentMethods(countryCode: countryCode, brandId: brandId);

  Future<CheckoutResponseModel> checkout(Map<String, dynamic> body) =>
      _remote.checkout(body);

  Future<List<OrderStatusModel>> listOrders({
    required String userId,
    required String countryCode,
  }) => _remote.listOrders(userId: userId, countryCode: countryCode);

  Future<OrderStatusModel> getOrderStatus(String trackingId) =>
      _remote.getOrderStatus(trackingId);
}
