import '../../../../core/network/api_client.dart';
import '../datasources/menu_remote_data_source.dart';
import '../models/brand_model.dart';
import '../models/catalog_model.dart';
import '../models/store_model.dart';

/// Repository for catalog data.
class MenuRepository {
  final MenuRemoteDataSource _remote;

  MenuRepository({required ApiClient client})
    : _remote = MenuRemoteDataSource(client: client);

  Future<CatalogModel> loadCategoryBackedCatalog({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
  }) async {
    final categoryList = await _remote.listCategories(
      countryCode: countryCode,
      language: language,
      storeId: storeId,
      brandId: brandId,
    );

    final itemLists = await Future.wait(
      categoryList.categories.map(
        (category) => _remote.listCategoryItems(
          countryCode: countryCode,
          language: language,
          storeId: storeId,
          brandId: brandId,
          categoryId: category.id,
        ),
      ),
    );
    final productsByCategory = {
      for (final itemList in itemLists) itemList.categoryId: itemList.products,
    };

    return categoryList.copyWith(
      categories: categoryList.categories
          .map(
            (category) => category.copyWith(
              products: productsByCategory[category.id] ?? const [],
            ),
          )
          .where((category) => category.products.isNotEmpty)
          .toList(),
    );
  }

  Future<List<BrandModel>> listBrands() => _remote.listBrands();

  Future<List<StoreModel>> listStores({
    required String countryId,
    int? brandId,
  }) => _remote.listStores(countryId: countryId, brandId: brandId);
}
