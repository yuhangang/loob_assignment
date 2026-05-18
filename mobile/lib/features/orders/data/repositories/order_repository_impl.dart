import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../cart/data/models/order_status_model.dart';
import '../../../cart/domain/repositories/cart_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/local_order_model.dart';

class OrderRepositoryImpl implements IOrderRepository {
  final ICartRepository _cartRepository;
  final AuthService _authService;
  final AppConfig _config;

  const OrderRepositoryImpl({
    required ICartRepository cartRepository,
    required AuthService authService,
    required AppConfig config,
  })  : _cartRepository = cartRepository,
        _authService = authService,
        _config = config;

  @override
  Future<List<OrderStatusModel>> loadOrders({String? countryCode}) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return const [];
    return _cartRepository.listOrders(
      userId: userId,
      countryCode: countryCode ?? _config.defaultCountryCode,
    );
  }

  @override
  List<LocalOrderItemModel> loadOrderAgainItems() {
    return const [];
  }
}
