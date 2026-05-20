import '../../data/models/order_status_model.dart';

enum OrderStatusNoticeType { collectionFailed, paymentConfirmed, paymentFailed }

class OrderStatusNotice {
  final OrderStatusNoticeType type;
  final String? detail;

  const OrderStatusNotice({required this.type, this.detail});
}

class OrderStatusState {
  final OrderStatusModel? status;
  final bool isLoading;
  final bool isCollecting;
  final bool isRetryingPayment;
  final String? error;
  final OrderStatusNotice? notice;

  const OrderStatusState({
    this.status,
    this.isLoading = false,
    this.isCollecting = false,
    this.isRetryingPayment = false,
    this.error,
    this.notice,
  });

  bool get hasStatus => status != null;

  OrderStatusState copyWith({
    OrderStatusModel? Function()? status,
    bool? isLoading,
    bool? isCollecting,
    bool? isRetryingPayment,
    String? Function()? error,
    OrderStatusNotice? Function()? notice,
  }) {
    return OrderStatusState(
      status: status != null ? status() : this.status,
      isLoading: isLoading ?? this.isLoading,
      isCollecting: isCollecting ?? this.isCollecting,
      isRetryingPayment: isRetryingPayment ?? this.isRetryingPayment,
      error: error != null ? error() : this.error,
      notice: notice != null ? notice() : this.notice,
    );
  }
}
