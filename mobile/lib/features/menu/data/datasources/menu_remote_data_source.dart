import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/brand_model.dart';
import '../models/catalog_model.dart';
import '../models/store_model.dart';

/// Remote data source for catalog endpoints.
///
/// Uses [ApiClient] so all requests are routed through the flavor-configured
/// [baseUrl] and the auth / context interceptors.
class MenuRemoteDataSource {
  final ApiClient _client;

  MenuRemoteDataSource({required ApiClient client}) : _client = client;

  Future<CatalogModel> listCategories({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.catalogCategories,
        queryParameters: {'store_id': storeId, 'brand_id': brandId},
      );
      return CatalogModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CategoryItemsModel> listCategoryItems({
    required String countryCode,
    required String language,
    required int storeId,
    required int brandId,
    required int categoryId,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.catalogCategoryItems(categoryId),
        queryParameters: {'store_id': storeId, 'brand_id': brandId},
      );
      return CategoryItemsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<BrandModel>> listBrands() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.catalogBrands);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => BrandModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<StoreModel>> listStores({
    required String countryId,
    int? brandId,
  }) async {
    try {
      const pageLimit = 100;
      var page = 1;
      var hasMore = true;
      final stores = <StoreModel>[];

      while (hasMore) {
        final queryParameters = <String, dynamic>{
          'country_id': countryId,
          'page': page,
          'limit': pageLimit,
        };
        if (brandId != null) {
          queryParameters['brand_id'] = brandId;
        }
        final response = await _client.dio.get(
          ApiEndpoints.catalogStores,
          queryParameters: queryParameters,
        );
        final data = response.data;
        if (data is List<dynamic>) {
          stores.addAll(
            data.map((e) => StoreModel.fromJson(e as Map<String, dynamic>)),
          );
          break;
        }

        final payload = data as Map<String, dynamic>;
        final items = payload['items'] as List<dynamic>? ?? const [];
        stores.addAll(
          items.map((e) => StoreModel.fromJson(e as Map<String, dynamic>)),
        );
        hasMore = payload['has_more'] as bool? ?? false;
        if (items.isEmpty) {
          break;
        }
        page++;
      }

      return stores;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
