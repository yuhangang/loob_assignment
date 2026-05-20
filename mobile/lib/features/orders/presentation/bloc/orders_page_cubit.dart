import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../cart/data/models/order_status_model.dart';
import '../../domain/repositories/order_repository.dart';

class OrdersPageState {
  final List<OrderStatusModel> orders;
  final int page;
  final bool hasMore;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final String? error;

  const OrdersPageState({
    this.orders = const [],
    this.page = 1,
    this.hasMore = false,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  OrdersPageState copyWith({
    List<OrderStatusModel>? orders,
    int? page,
    bool? hasMore,
    bool? isInitialLoading,
    bool? isLoadingMore,
    String? Function()? error,
  }) {
    return OrdersPageState(
      orders: orders ?? this.orders,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error != null ? error() : this.error,
    );
  }
}

class OrdersPageCubit extends Cubit<OrdersPageState> {
  static const int pageSize = 20;

  final IOrderRepository _repository;
  int _requestToken = 0;

  OrdersPageCubit({IOrderRepository? repository})
    : _repository = repository ?? sl<IOrderRepository>(),
      super(const OrdersPageState(isInitialLoading: true));

  Future<void> loadFirstPage({required String countryCode}) async {
    final token = ++_requestToken;
    emit(
      state.copyWith(
        orders: const [],
        page: 1,
        hasMore: false,
        isInitialLoading: true,
        isLoadingMore: false,
        error: () => null,
      ),
    );
    try {
      final page = await _repository.loadOrdersPage(
        countryCode: countryCode,
        page: 1,
        limit: pageSize,
      );
      if (isClosed || token != _requestToken) return;
      emit(
        state.copyWith(
          orders: page.items,
          page: page.page,
          hasMore: page.hasMore,
          isInitialLoading: false,
        ),
      );
    } catch (e) {
      if (isClosed || token != _requestToken) return;
      emit(state.copyWith(isInitialLoading: false, error: () => e.toString()));
    }
  }

  Future<void> loadMore({required String countryCode}) async {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    final token = _requestToken;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.loadOrdersPage(
        countryCode: countryCode,
        page: state.page + 1,
        limit: pageSize,
      );
      if (isClosed || token != _requestToken) return;
      emit(
        state.copyWith(
          orders: [...state.orders, ...page.items],
          page: page.page,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      if (isClosed || token != _requestToken) return;
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
