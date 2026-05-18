import '../../data/models/checkout_response_model.dart';
import '../../data/models/order_status_model.dart';
import '../../data/models/payment_method_model.dart';

abstract class ICartRepository {
  Future<List<PaymentMethodModel>> listPaymentMethods({
    required String countryCode,
    int? brandId,
  });

  Future<CheckoutResponseModel> checkout(Map<String, dynamic> body);

  Future<List<OrderStatusModel>> listOrders({
    required String userId,
    required String countryCode,
  });

  Future<OrderStatusModel> getOrderStatus(String trackingId);

  Future<OrderStatusModel> collectOrder(String trackingId);

  Future<void> confirmMockPayment({
    required String transactionId,
    required String secret,
  });
}
