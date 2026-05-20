import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/auth/mock_auth_service.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/core/network/api_client.dart';
import 'package:loob_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:loob_app/features/cart/data/models/cart_api_model.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_event.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_item.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';
import 'package:loob_app/features/menu/data/models/store_model.dart';

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

class FakeAuthService extends MockAuthService {
  @override
  AuthUser? get currentUser => const AuthUser(uid: 'u1', phoneNumber: '+60123456789');
  @override
  bool get isAuthenticated => true;
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'mock-jwt';
}

void main() {
  setUp(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<AuthService>()) {
      sl.registerSingleton<AuthService>(FakeAuthService());
    }
  });

  ProductModel product() {
    const regular = CustomizationOptionModel(
      code: 'REG',
      id: 10,
      name: 'Regular',
      priceAdjustment: 0,
      isDefault: true,
      isAvailable: true,
    );
    const large = CustomizationOptionModel(
      code: 'LRG',
      id: 11,
      name: 'Large',
      priceAdjustment: 150,
      isDefault: false,
      isAvailable: true,
    );

    return const ProductModel(
      id: 100,
      skuCode: 'TL-MILK-TEA',
      isAvailable: true,
      name: 'Milk Tea',
      description: '',
      media: MediaModel(imageUrlSm: '', imageUrlLg: ''),
      basePrice: 600,
      dietaryTags: [],
      customizationGroups: [
        CustomizationGroupModel(
          code: 'SIZE',
          id: 1,
          type: 'SINGLE_SELECT',
          required: true,
          minSelections: 1,
          maxSelections: 1,
          name: 'Size',
          options: [regular, large],
        ),
      ],
    );
  }

  group('CartBloc Tests', () {
    blocTest<CartBloc, CartState>(
      'same product with different choices stays as separate cart lines',
      build: () => CartBloc(),
      act: (bloc) {
        final item = product();
        bloc.add(
          CartItemAdded(
            product: item,
            selectedOptions: [item.customizationGroups.first.options[0]],
            customizationOptionIds: const [10],
            quantity: 1,
          ),
        );
        bloc.add(
          CartItemAdded(
            product: item,
            selectedOptions: [item.customizationGroups.first.options[1]],
            customizationOptionIds: const [11],
            quantity: 1,
          ),
        );
      },
      verify: (bloc) {
        expect(bloc.state.items, hasLength(2));
        expect(bloc.state.items[0].selectedCustomizationIds, [10]);
        expect(bloc.state.items[1].selectedCustomizationIds, [11]);
      },
    );

    blocTest<CartBloc, CartState>(
      'same product with same raw choice merges quantity',
      build: () => CartBloc(),
      act: (bloc) {
        final item = product();
        bloc.add(
          CartItemAdded(
            product: item,
            selectedOptions: const [],
            customizationOptionIds: const [11],
            quantity: 1,
          ),
        );
        bloc.add(
          CartItemAdded(
            product: item,
            selectedOptions: const [],
            customizationOptionIds: const [11],
            quantity: 2,
          ),
        );
      },
      verify: (bloc) {
        expect(bloc.state.items, hasLength(1));
        expect(bloc.state.items.single.quantity, 3);
        expect(bloc.state.items.single.selectedCustomizationIds, [11]);
      },
    );

    blocTest<CartBloc, CartState>(
      'store refresh keeps newly selected store when cart rows still carry old store id',
      build: () => CartBloc(
        remoteDataSource: FakeCartRemoteDataSource(
          const CartApiResponse(
            userId: 'u1',
            countryId: 'MY',
            items: [
              CartApiItem(
                id: 99,
                menuItemId: 100,
                storeId: 1,
                quantity: 1,
                customizationOptionIds: [10],
                name: 'Milk Tea',
                imageUrlSm: '',
                basePrice: 600,
                isAvailable: false,
                customizationOptions: [
                  CartApiOption(
                    id: 10,
                    groupId: 1,
                    code: 'REG',
                    name: 'Regular',
                    priceAdjustment: 0,
                    isAvailable: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      seed: () => CartState(
        storeId: 1,
        items: [
          CartItem(
            product: product(),
            selectedOptions: const [],
            customizationOptionIds: const [10],
            quantity: 1,
          ),
        ],
      ),
      act: (bloc) {
        bloc.add(
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
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        final fake = bloc.remoteDataSource! as FakeCartRemoteDataSource;
        expect(fake.requestedStoreId, 2);
        expect(bloc.state.storeId, 2);
        expect(bloc.state.items.single.serverId, 99);
        expect(bloc.state.items.single.isAvailable, isFalse);
        expect(bloc.state.items.single.hasUnavailableOptions, isTrue);
      },
    );
  });
}
