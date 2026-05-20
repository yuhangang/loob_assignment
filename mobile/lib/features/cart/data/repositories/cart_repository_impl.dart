import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_remote_data_source.dart';
import '../models/checkout_response_model.dart';
import '../models/order_status_model.dart';
import '../models/payment_method_model.dart';
import '../../../orders/data/models/order_list_page_model.dart';

class CartRepositoryImpl implements ICartRepository {
  final CartRemoteDataSource _remote;

  const CartRepositoryImpl({required CartRemoteDataSource remote})
    : _remote = remote;

  @override
  Future<List<PaymentMethodModel>> listPaymentMethods({
    required String countryCode,
    int? brandId,
  }) => _remote.listPaymentMethods(countryCode: countryCode, brandId: brandId);

  @override
  Future<CheckoutResponseModel> checkout(Map<String, dynamic> body) =>
      _remote.checkout(body);

  @override
  Future<List<OrderStatusModel>> listOrders({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) => _remote
      .listOrdersPage(
        userId: userId,
        countryCode: countryCode,
        page: page,
        limit: limit,
        statuses: statuses,
      )
      .then((page) => page.items);

  @override
  Future<OrderListPageModel> listOrdersPage({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) => _remote.listOrdersPage(
    userId: userId,
    countryCode: countryCode,
    page: page,
    limit: limit,
    statuses: statuses,
  );

  @override
  Future<OrderStatusModel> getOrderStatus(String trackingId) =>
      _remote.getOrderStatus(trackingId);

  @override
  Future<OrderStatusModel> collectOrder(String trackingId) =>
      _remote.collectOrder(trackingId);

  @override
  Future<void> confirmMockPayment({
    required String transactionId,
    required String secret,
  }) =>
      _remote.confirmMockPayment(transactionId: transactionId, secret: secret);
}
