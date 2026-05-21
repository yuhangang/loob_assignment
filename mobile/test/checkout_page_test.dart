import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/auth/mock_auth_service.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/core/localization/app_localizations.dart';
import 'package:loob_app/core/network/api_client.dart';
import 'package:loob_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:loob_app/features/cart/data/models/cart_api_model.dart';
import 'package:loob_app/features/cart/data/models/checkout_response_model.dart';
import 'package:loob_app/features/cart/data/models/order_status_model.dart';
import 'package:loob_app/features/cart/data/models/payment_method_model.dart';
import 'package:loob_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_event.dart';
import 'package:loob_app/features/cart/presentation/checkout_page.dart';
import 'package:loob_app/features/menu/data/models/store_model.dart';
import 'package:loob_app/features/orders/data/models/local_order_model.dart';
import 'package:loob_app/features/orders/data/models/order_list_page_model.dart';
import 'package:loob_app/features/orders/domain/repositories/order_repository.dart';
import 'package:loob_app/features/orders/presentation/bloc/active_order_cubit.dart';
import 'package:loob_app/features/vouchers/data/models/voucher_validation_model.dart';
import 'package:loob_app/features/vouchers/data/models/wallet_model.dart';
import 'package:loob_app/features/vouchers/domain/repositories/voucher_repository.dart';

class FakeAuthService extends MockAuthService {
  @override
  AuthUser? get currentUser => const AuthUser(uid: 'u1', phoneNumber: '+6012');

  @override
  bool get isAuthenticated => true;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'mock-jwt';
}

class FakeCartRemoteDataSource extends CartRemoteDataSource {
  FakeCartRemoteDataSource(this.response)
    : super(client: ApiClient(config: AppConfig.dev()));

  final CartApiResponse response;
  int? requestedStoreId;

  @override
  Future<CartApiResponse> getCart({
    required String userId,
    required String countryCode,
    int? storeId,
  }) async {
    requestedStoreId = storeId;
    return response;
  }
}

class FakeCartRepository implements ICartRepository {
  @override
  Future<List<PaymentMethodModel>> listPaymentMethods({
    required String countryCode,
    int? brandId,
  }) async => const [];

  @override
  Future<CheckoutResponseModel> checkout(Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmMockPayment({
    required String transactionId,
    required String secret,
  }) async {}

  @override
  Future<OrderStatusModel> collectOrder(String trackingId) {
    throw UnimplementedError();
  }

  @override
  Future<OrderStatusModel> getOrderStatus(String trackingId) {
    throw UnimplementedError();
  }

  @override
  Future<List<OrderStatusModel>> listOrders({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<OrderListPageModel> listOrdersPage({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<LocalOrderItemModel>> listReorderItems({
    required String userId,
    required String countryCode,
    int limit = 8,
  }) {
    throw UnimplementedError();
  }
}

class FakeVoucherRepository implements IVoucherRepository {
  @override
  Future<WalletModel> getWallet({
    String? countryCode,
    String? userId,
    int brandId = 0,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<VoucherValidationModel> validateVoucher({
    String? countryCode,
    required Map<String, dynamic> body,
  }) {
    throw UnimplementedError();
  }
}

class FakeOrderRepository implements IOrderRepository {
  @override
  Future<List<OrderStatusModel>> loadOrders({
    String? countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) async => const [];

  @override
  Future<List<LocalOrderItemModel>> loadOrderAgainItems({
    String? countryCode,
    int limit = 8,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<OrderListPageModel> loadOrdersPage({
    String? countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) {
    throw UnimplementedError();
  }
}

void main() {
  final sl = GetIt.instance;

  setUp(() {
    if (sl.isRegistered<AuthService>()) {
      sl.unregister<AuthService>();
    }
    if (sl.isRegistered<ICartRepository>()) {
      sl.unregister<ICartRepository>();
    }
    if (sl.isRegistered<IVoucherRepository>()) {
      sl.unregister<IVoucherRepository>();
    }

    sl.registerSingleton<AuthService>(FakeAuthService());
    sl.registerSingleton<ICartRepository>(FakeCartRepository());
    sl.registerSingleton<IVoucherRepository>(FakeVoucherRepository());
  });

  testWidgets(
    'opening checkout refreshes cart availability for the selected store',
    (tester) async {
      final remote = FakeCartRemoteDataSource(
        const CartApiResponse(
          userId: 'u1',
          countryId: 'MY',
          items: [
            CartApiItem(
              id: 1,
              menuItemId: 100,
              storeId: 2,
              quantity: 1,
              customizationOptionIds: [],
              name: 'Milk Tea',
              imageUrlSm: '',
              basePrice: 600,
              isAvailable: true,
              customizationOptions: [],
            ),
          ],
        ),
      );
      final cartBloc = CartBloc(remoteDataSource: remote);

      cartBloc.add(
        const CartSetStore(
          StoreModel(
            id: 2,
            brandId: 1,
            countryId: 'MY',
            zoneId: 'KLANG',
            storeCode: 'TL-002',
            name: 'New Outlet',
            latitude: 0,
            longitude: 0,
            address: '',
            isActive: true,
          ),
        ),
      );
      await cartBloc.stream.firstWhere((state) => state.storeId == 2);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<CartBloc>.value(value: cartBloc),
            BlocProvider<ActiveOrderCubit>(
              create: (_) =>
                  ActiveOrderCubit(orderRepository: FakeOrderRepository()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ms')],
            home: CheckoutPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(remote.requestedStoreId, 2);
    },
  );
}
