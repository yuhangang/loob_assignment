import 'package:flutter_test/flutter_test.dart';
import 'package:loob_app/features/menu/data/models/brand_model.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';
import 'package:loob_app/features/menu/data/models/store_model.dart';
import 'package:loob_app/features/menu/data/repositories/menu_repository.dart';
import 'package:loob_app/features/menu/presentation/menu_bloc.dart';

class _FakeMenuRepository implements MenuRepository {
  int? requestedStoreId;

  @override
  Future<CatalogModel> loadCategoryBackedCatalog({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
  }) async {
    requestedStoreId = storeId;
    return const CatalogModel(
      catalogVersion: 'test',
      brand: 'tealive',
      countryCode: 'MY',
      currency: 'MYR',
      taxInclusive: true,
      languageResolved: 'en-US',
      categories: [],
    );
  }

  @override
  Future<List<BrandModel>> listBrands() async => [];

  @override
  Future<List<StoreModel>> listStores({
    required String countryId,
    int? brandId,
  }) async {
    return const [
      StoreModel(
        id: 1,
        brandId: 1,
        countryId: 'MY',
        zoneId: 'KL',
        storeCode: 'TLV-001',
        name: 'Tealive Pavilion',
        latitude: 3.14,
        longitude: 101.68,
        address: 'Pavilion Damansara',
        isActive: true,
      ),
      StoreModel(
        id: 2,
        brandId: 1,
        countryId: 'MY',
        zoneId: 'KL',
        storeCode: 'TLV-002',
        name: 'Tealive Bangsar',
        latitude: 3.13,
        longitude: 101.67,
        address: 'Bangsar Village',
        isActive: true,
      ),
    ];
  }
}

void main() {
  test('MenuBloc loads menu for the selected outlet', () async {
    final repository = _FakeMenuRepository();
    final bloc = MenuBloc(repository: repository);

    bloc.add(
      const LoadMenu(countryCode: 'MY', language: 'en', storeId: 2, brandId: 1),
    );

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<MenuLoading>(),
        isA<MenuLoaded>().having(
          (state) => state.selectedStore.id,
          'selected store id',
          2,
        ),
      ]),
    );

    expect(repository.requestedStoreId, 2);
    await bloc.close();
  });
}
