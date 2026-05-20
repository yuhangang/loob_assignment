import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/cart_repository.dart';
import 'order_status_state.dart';

class OrderStatusCubit extends Cubit<OrderStatusState> {
  final ICartRepository _repository;
  final AppConfig _appConfig;
  final String trackingId;

  OrderStatusCubit({
    required this.trackingId,
    ICartRepository? repository,
    AppConfig? appConfig,
  }) : _repository = repository ?? sl<ICartRepository>(),
       _appConfig = appConfig ?? sl<AppConfig>(),
       super(const OrderStatusState(isLoading: true));

  Future<void> load() async {
    emit(
      state.copyWith(isLoading: true, error: () => null, notice: () => null),
    );
    try {
      final status = await _repository.getOrderStatus(trackingId);
      if (isClosed) return;
      emit(state.copyWith(status: () => status, isLoading: false));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: () => e.toString()));
    }
  }

  Future<void> collectOrder() async {
    if (state.isCollecting) return;
    emit(
      state.copyWith(isCollecting: true, error: () => null, notice: () => null),
    );
    try {
      final status = await _repository.collectOrder(trackingId);
      if (isClosed) return;
      emit(state.copyWith(status: () => status, isCollecting: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isCollecting: false,
          notice: () => OrderStatusNotice(
            type: OrderStatusNoticeType.collectionFailed,
            detail: e.toString(),
          ),
        ),
      );
    }
  }

  Future<void> retryPayment(String transactionId) async {
    if (state.isRetryingPayment) return;
    emit(
      state.copyWith(
        isRetryingPayment: true,
        error: () => null,
        notice: () => null,
      ),
    );
    try {
      await _repository.confirmMockPayment(
        transactionId: transactionId,
        secret: _appConfig.mockGatewaySecret,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final status = await _repository.getOrderStatus(trackingId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: () => status,
          isRetryingPayment: false,
          notice: () => const OrderStatusNotice(
            type: OrderStatusNoticeType.paymentConfirmed,
          ),
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isRetryingPayment: false,
          notice: () => OrderStatusNotice(
            type: OrderStatusNoticeType.paymentFailed,
            detail: e.toString(),
          ),
        ),
      );
    }
  }

  void clearNotice() {
    if (state.notice == null) return;
    emit(state.copyWith(notice: () => null));
  }
}
