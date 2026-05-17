import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../cart/data/models/order_status_model.dart';
import '../../../cart/data/repositories/cart_repository.dart';
import '../models/local_order_model.dart';

class OrderRepository {
  final CartRepository _cartRepository;
  final AuthService _authService;
  final AppConfig _config;

  const OrderRepository({
    required CartRepository cartRepository,
    required AuthService authService,
    required AppConfig config,
  }) : _cartRepository = cartRepository,
       _authService = authService,
       _config = config;

  Future<List<OrderStatusModel>> loadOrders() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return const [];
    return _cartRepository.listOrders(
      userId: userId,
      countryCode: _config.defaultCountryCode,
    );
  }

  List<LocalOrderItemModel> loadOrderAgainItems() {
    return const [];
  }
}
