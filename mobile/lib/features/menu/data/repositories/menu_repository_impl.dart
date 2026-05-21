import '../../domain/repositories/menu_repository.dart';
import '../datasources/menu_remote_data_source.dart';
import '../models/brand_model.dart';
import '../models/catalog_model.dart';
import '../models/product_availability_model.dart';
import '../models/store_model.dart';

class MenuRepositoryImpl implements IMenuRepository {
  final MenuRemoteDataSource _remote;

  const MenuRepositoryImpl({required MenuRemoteDataSource remote})
    : _remote = remote;

  @override
  Future<CatalogModel> loadCategoryBackedCatalog({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
  }) {
    return _remote.listCategories(
      countryCode: countryCode,
      language: language,
      storeId: storeId,
      brandId: brandId,
    );
  }

  @override
  Future<ProductAvailabilityModel> getItemAvailability({
    required String countryCode,
    required int storeId,
    required int itemId,
  }) {
    return _remote.getItemAvailability(
      countryCode: countryCode,
      storeId: storeId,
      itemId: itemId,
    );
  }

  @override
  Future<List<BrandModel>> listBrands() => _remote.listBrands();

  @override
  Future<List<StoreModel>> listStores({
    required String countryId,
    int? brandId,
  }) => _remote.listStores(countryId: countryId, brandId: brandId);
}
