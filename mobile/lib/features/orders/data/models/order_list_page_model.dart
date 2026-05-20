import '../../../cart/data/models/order_status_model.dart';

class OrderListPageModel {
  final List<OrderStatusModel> items;
  final int page;
  final int limit;
  final bool hasMore;

  const OrderListPageModel({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  factory OrderListPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return OrderListPageModel(
      items: rawItems
          .map((e) => OrderStatusModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? rawItems.length,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  factory OrderListPageModel.fromLegacyList(List<dynamic> list) {
    return OrderListPageModel(
      items: list
          .map((e) => OrderStatusModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: 1,
      limit: list.length,
      hasMore: false,
    );
  }
}
