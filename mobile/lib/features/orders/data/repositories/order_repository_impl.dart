import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../cart/data/models/order_status_model.dart';
import '../../../cart/domain/repositories/cart_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/local_order_model.dart';
import '../models/order_list_page_model.dart';

class OrderRepositoryImpl implements IOrderRepository {
  final ICartRepository _cartRepository;
  final AuthService _authService;
  final AppConfig _config;

  const OrderRepositoryImpl({
    required ICartRepository cartRepository,
    required AuthService authService,
    required AppConfig config,
  }) : _cartRepository = cartRepository,
       _authService = authService,
       _config = config;

  @override
  Future<List<OrderStatusModel>> loadOrders({
    String? countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) async {
    final ordersPage = await loadOrdersPage(
      countryCode: countryCode,
      page: page,
      limit: limit,
      statuses: statuses,
    );
    return ordersPage.items;
  }

  @override
  Future<OrderListPageModel> loadOrdersPage({
    String? countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return OrderListPageModel(
        items: const [],
        page: page,
        limit: limit,
        hasMore: false,
      );
    }
    return _cartRepository.listOrdersPage(
      userId: userId,
      countryCode: countryCode ?? _config.defaultCountryCode,
      page: page,
      limit: limit,
      statuses: statuses,
    );
  }

  @override
  List<LocalOrderItemModel> loadOrderAgainItems() {
    return const [];
  }
}
