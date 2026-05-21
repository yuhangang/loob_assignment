import '../../data/models/brand_model.dart';
import '../../data/models/catalog_model.dart';
import '../../data/models/product_availability_model.dart';
import '../../data/models/store_model.dart';

abstract class IMenuRepository {
  Future<CatalogModel> loadCategoryBackedCatalog({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
  });

  Future<ProductAvailabilityModel> getItemAvailability({
    required String countryCode,
    required int storeId,
    required int itemId,
  });

  Future<List<BrandModel>> listBrands();

  Future<List<StoreModel>> listStores({
    required String countryId,
    int? brandId,
  });
}
