import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../cart/data/models/order_status_model.dart';
import '../../domain/repositories/order_repository.dart';
import 'active_order_state.dart';

class ActiveOrderCubit extends Cubit<ActiveOrderState> {
  static const List<String> _activeStatuses = [
    'PAYMENT_PENDING',
    'QUEUED',
    'PROCESSING',
    'READY_TO_COLLECT',
  ];

  final IOrderRepository _orderRepository;

  ActiveOrderCubit({IOrderRepository? orderRepository})
    : _orderRepository = orderRepository ?? sl<IOrderRepository>(),
      super(const ActiveOrderState());

  Future<void> fetchActiveOrder({required String countryCode}) async {
    emit(state.copyWith(isLoading: true, error: () => null));
    try {
      final orders = await _orderRepository.loadOrders(
        countryCode: countryCode,
        limit: 1,
        statuses: _activeStatuses,
      );
      final active = orders.isNotEmpty ? orders.first : null;
      emit(state.copyWith(activeOrder: () => active, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: () => e.toString()));
    }
  }

  void reconcileOrderStatus(OrderStatusModel order) {
    final current = state.activeOrder;
    final isSameOrder = current?.orderTrackingId == order.orderTrackingId;
    final isActive = _activeStatuses.contains(order.status.toUpperCase());

    if (isActive) {
      emit(state.copyWith(activeOrder: () => order, error: () => null));
      return;
    }

    if (isSameOrder) {
      clearActiveOrder();
    }
  }

  void clearActiveOrder() {
    emit(state.copyWith(activeOrder: () => null));
  }
}
