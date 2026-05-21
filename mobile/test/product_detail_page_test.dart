import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:loob_app/core/di/injection.dart';
import 'package:loob_app/core/localization/app_localizations.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_event.dart';
import 'package:loob_app/features/menu/data/models/brand_model.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';
import 'package:loob_app/features/menu/data/models/product_availability_model.dart';
import 'package:loob_app/features/menu/data/models/store_model.dart';
import 'package:loob_app/features/menu/domain/repositories/menu_repository.dart';
import 'package:loob_app/features/menu/presentation/product_detail_page.dart';

class FakeMenuRepository implements IMenuRepository {
  FakeMenuRepository({required this.availability});

  final ProductAvailabilityModel availability;

  @override
  Future<ProductAvailabilityModel> getItemAvailability({
    required String countryCode,
    required int storeId,
    required int itemId,
  }) async => availability;

  @override
  Future<CatalogModel> loadCategoryBackedCatalog({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<BrandModel>> listBrands() {
    throw UnimplementedError();
  }

  @override
  Future<List<StoreModel>> listStores({
    required String countryId,
    int? brandId,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<IMenuRepository>()) {
      getIt.unregister<IMenuRepository>();
    }
  });

  testWidgets('blocks add to cart and buy now when no outlet is selected', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(product: product()));
    await tester.pumpAndSettle();

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));

    expect(buttons.length, 2);
    for (final button in buttons) {
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('blocks add to cart and buy now when product is unavailable', (
    tester,
  ) async {
    sl.registerSingleton<IMenuRepository>(
      FakeMenuRepository(
        availability: const ProductAvailabilityModel(
          itemId: 100,
          storeId: 2,
          isAvailable: false,
          optionAvailability: {},
        ),
      ),
    );
    final cartBloc = CartBloc()
      ..add(
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

    await tester.pumpWidget(
      _buildTestApp(product: product(isAvailable: true), cartBloc: cartBloc),
    );
    await tester.pumpAndSettle();

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));

    expect(buttons.length, 2);
    for (final button in buttons) {
      expect(button.onPressed, isNull);
    }
  });
}

Widget _buildTestApp({required ProductModel product, CartBloc? cartBloc}) {
  return BlocProvider<CartBloc>.value(
    value: cartBloc ?? CartBloc(),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ms')],
      home: ProductDetailPage(product: product, currency: 'MYR'),
    ),
  );
}

ProductModel product({bool isAvailable = true}) {
  return ProductModel(
    id: 100,
    skuCode: 'TL-MILK-TEA',
    isAvailable: isAvailable,
    name: 'Milk Tea',
    description: '',
    media: const MediaModel(imageUrlSm: '', imageUrlLg: ''),
    basePrice: 600,
    dietaryTags: const [],
    customizationGroups: const [],
  );
}
