import 'package:flutter_test/flutter_test.dart';
import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/features/cart/data/models/checkout_response_model.dart';
import 'package:loob_app/features/cart/data/models/order_status_model.dart';
import 'package:loob_app/features/cart/data/models/payment_method_model.dart';
import 'package:loob_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:loob_app/features/orders/data/models/local_order_model.dart';
import 'package:loob_app/features/orders/data/models/order_list_page_model.dart';
import 'package:loob_app/features/orders/data/repositories/order_repository_impl.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.user});

  final AuthUser? user;

  @override
  AuthUser? get currentUser => user;

  @override
  bool get isAuthenticated => user != null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'token';

  @override
  Future<void> init() async {}

  @override
  Future<void> signInWithPhone(String phoneNumber) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> verifyOtp(String verificationId, String code) async {
    return user ?? const AuthUser(uid: 'u1');
  }
}

class FakeCartRepository implements ICartRepository {
  FakeCartRepository({this.reorderItems = const []});

  final List<LocalOrderItemModel> reorderItems;
  int? requestedLimit;
  String? requestedCountryCode;
  bool reorderRequested = false;

  @override
  Future<OrderListPageModel> listOrdersPage({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) async {
    return const OrderListPageModel(
      items: [],
      page: 1,
      limit: 20,
      hasMore: false,
    );
  }

  @override
  Future<List<OrderStatusModel>> listOrders({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) async {
    return const [];
  }

  @override
  Future<List<LocalOrderItemModel>> listReorderItems({
    required String userId,
    required String countryCode,
    int limit = 8,
  }) async {
    reorderRequested = true;
    requestedLimit = limit;
    requestedCountryCode = countryCode;
    return reorderItems.take(limit).toList();
  }

  @override
  Future<void> confirmMockPayment({
    required String transactionId,
    required String secret,
  }) async {}

  @override
  Future<CheckoutResponseModel> checkout(Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<OrderStatusModel> collectOrder(String trackingId) {
    throw UnimplementedError();
  }

  @override
  Future<OrderStatusModel> getOrderStatus(String trackingId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PaymentMethodModel>> listPaymentMethods({
    required String countryCode,
    int? brandId,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  LocalOrderItemModel item(int id) {
    return LocalOrderItemModel(
      menuItemId: id,
      skuCode: 'SKU-$id',
      name: 'Item $id',
      description: '',
      imageUrlSm: '',
      imageUrlLg: '',
      basePrice: 600,
      quantity: 2,
      isAvailable: true,
      dietaryTags: const [],
      customizationOptionIds: const [1, 2],
      customizationOptions: const [
        LocalOrderOptionModel(
          id: 1,
          code: '',
          name: 'Regular',
          priceAdjustment: 0,
          isAvailable: true,
        ),
        LocalOrderOptionModel(
          id: 2,
          code: '',
          name: 'Pearl',
          priceAdjustment: 100,
          isAvailable: true,
        ),
      ],
    );
  }

  test('loads order-again items from the dedicated backend endpoint', () async {
    final cartRepository = FakeCartRepository(
      reorderItems: [item(100), item(101), item(102)],
    );
    final repository = OrderRepositoryImpl(
      cartRepository: cartRepository,
      authService: FakeAuthService(user: const AuthUser(uid: 'u1')),
      config: AppConfig.dev(),
    );

    final items = await repository.loadOrderAgainItems(
      countryCode: 'MY',
      limit: 3,
    );

    expect(cartRepository.requestedCountryCode, 'MY');
    expect(cartRepository.requestedLimit, 3);
    expect(items.map((item) => item.menuItemId), [100, 101, 102]);
    expect(items.first.quantity, 2);
    expect(items.first.customizationOptionIds, [1, 2]);
    expect(items.first.customizationOptions.map((option) => option.id), [1, 2]);
  });

  test('does not fetch backend orders for signed-out users', () async {
    final cartRepository = FakeCartRepository();
    final repository = OrderRepositoryImpl(
      cartRepository: cartRepository,
      authService: FakeAuthService(),
      config: AppConfig.dev(),
    );

    final items = await repository.loadOrderAgainItems(countryCode: 'MY');

    expect(items, isEmpty);
    expect(cartRepository.reorderRequested, isFalse);
  });
}
