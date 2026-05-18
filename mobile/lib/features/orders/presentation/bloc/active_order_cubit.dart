import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../cart/data/models/order_status_model.dart';
import '../../domain/repositories/order_repository.dart';
import 'active_order_state.dart';

class ActiveOrderCubit extends Cubit<ActiveOrderState> {
  final IOrderRepository _orderRepository;

  ActiveOrderCubit({IOrderRepository? orderRepository})
      : _orderRepository = orderRepository ?? sl<IOrderRepository>(),
        super(const ActiveOrderState());

  Future<void> fetchActiveOrder({required String countryCode}) async {
    emit(state.copyWith(isLoading: true, error: () => null));
    try {
      final orders = await _orderRepository.loadOrders(countryCode: countryCode);
      OrderStatusModel? active;
      for (final order in orders) {
        final status = order.status.toUpperCase();
        if (status != 'COMPLETED' &&
            status != 'FAILED' &&
            status != 'CANCELLED' &&
            status != 'PAYMENT_FAILED') {
          active = order;
          break;
        }
      }
      emit(state.copyWith(activeOrder: () => active, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      ));
    }
  }

  void clearActiveOrder() {
    emit(state.copyWith(activeOrder: () => null));
  }
}
