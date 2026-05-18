import 'package:loob_app/features/orders/data/models/local_order_model.dart';

import '../../../cart/data/models/order_status_model.dart';

abstract class IOrderRepository {
  Future<List<OrderStatusModel>> loadOrders({String? countryCode});
  List<LocalOrderItemModel> loadOrderAgainItems();
}
