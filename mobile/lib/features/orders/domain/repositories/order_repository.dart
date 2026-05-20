import 'package:loob_app/features/orders/data/models/local_order_model.dart';
import 'package:loob_app/features/orders/data/models/order_list_page_model.dart';

import '../../../cart/data/models/order_status_model.dart';

abstract class IOrderRepository {
  Future<List<OrderStatusModel>> loadOrders({
    String? countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  });
  Future<OrderListPageModel> loadOrdersPage({
    String? countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  });
  List<LocalOrderItemModel> loadOrderAgainItems();
}
