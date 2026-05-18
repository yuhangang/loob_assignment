import '../../data/models/brand_model.dart';
import '../../data/models/catalog_model.dart';
import '../../data/models/store_model.dart';

abstract class IMenuRepository {
  Future<CatalogModel> loadCategoryBackedCatalog({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
  });

  Future<List<BrandModel>> listBrands();

  Future<List<StoreModel>> listStores({
    required String countryId,
    int? brandId,
  });
}
