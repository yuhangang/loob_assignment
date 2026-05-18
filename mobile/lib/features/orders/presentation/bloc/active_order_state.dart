import '../../../cart/data/models/order_status_model.dart';

class ActiveOrderState {
  final OrderStatusModel? activeOrder;
  final bool isLoading;
  final String? error;

  const ActiveOrderState({
    this.activeOrder,
    this.isLoading = false,
    this.error,
  });

  ActiveOrderState copyWith({
    OrderStatusModel? Function()? activeOrder,
    bool? isLoading,
    String? Function()? error,
  }) {
    return ActiveOrderState(
      activeOrder: activeOrder != null ? activeOrder() : this.activeOrder,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }
}
