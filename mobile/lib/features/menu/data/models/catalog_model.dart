/// Mapped from Go `catalog.Catalog`.
class CatalogModel {
  final String catalogVersion;
  final String brand;
  final String countryCode;
  final String currency;
  final bool taxInclusive;
  final String languageResolved;
  final List<CategoryModel> categories;

  const CatalogModel({
    required this.catalogVersion,
    required this.brand,
    required this.countryCode,
    required this.currency,
    required this.taxInclusive,
    required this.languageResolved,
    required this.categories,
  });

  factory CatalogModel.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'] as List<dynamic>? ?? [];
    return CatalogModel(
      catalogVersion: json['catalog_version'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      taxInclusive: json['tax_inclusive'] as bool? ?? false,
      languageResolved: json['language_resolved'] as String? ?? '',
      categories: cats
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  CatalogModel copyWith({
    String? catalogVersion,
    String? brand,
    String? countryCode,
    String? currency,
    bool? taxInclusive,
    String? languageResolved,
    List<CategoryModel>? categories,
  }) {
    return CatalogModel(
      catalogVersion: catalogVersion ?? this.catalogVersion,
      brand: brand ?? this.brand,
      countryCode: countryCode ?? this.countryCode,
      currency: currency ?? this.currency,
      taxInclusive: taxInclusive ?? this.taxInclusive,
      languageResolved: languageResolved ?? this.languageResolved,
      categories: categories ?? this.categories,
    );
  }
}

/// Mapped from Go `catalog.Category`.
class CategoryModel {
  final int id;
  final int displayOrder;
  final String name;
  final String iconUrl;
  final List<ProductModel> products;

  const CategoryModel({
    required this.id,
    required this.displayOrder,
    required this.name,
    required this.iconUrl,
    required this.products,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final prods = json['products'] as List<dynamic>? ?? [];
    return CategoryModel(
      id: json['id'] as int? ?? 0,
      displayOrder: json['display_order'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      iconUrl: json['icon_url'] as String? ?? '',
      products: prods
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  CategoryModel copyWith({
    int? id,
    int? displayOrder,
    String? name,
    String? iconUrl,
    List<ProductModel>? products,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      displayOrder: displayOrder ?? this.displayOrder,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      products: products ?? this.products,
    );
  }
}

/// Mapped from Go `catalog.CategoryItems`.
class CategoryItemsModel {
  final int categoryId;
  final List<ProductModel> products;

  const CategoryItemsModel({required this.categoryId, required this.products});

  factory CategoryItemsModel.fromJson(Map<String, dynamic> json) {
    final prods = json['products'] as List<dynamic>? ?? [];
    return CategoryItemsModel(
      categoryId: json['category_id'] as int? ?? 0,
      products: prods
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Mapped from Go `catalog.Product`.
class ProductModel {
  final int id;
  final String skuCode;
  final bool isAvailable;
  final String name;
  final String description;
  final MediaModel media;
  final int basePrice;
  final List<String> dietaryTags;
  final List<CustomizationGroupModel> customizationGroups;
  final bool isPromo;

  const ProductModel({
    required this.id,
    required this.skuCode,
    required this.isAvailable,
    required this.name,
    required this.description,
    required this.media,
    required this.basePrice,
    required this.dietaryTags,
    required this.customizationGroups,
    this.isPromo = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final tags = json['dietary_tags'] as List<dynamic>? ?? [];
    final groups = json['customization_groups'] as List<dynamic>? ?? [];
    return ProductModel(
      id: json['id'] as int? ?? 0,
      skuCode: json['sku_code'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      media: MediaModel.fromJson(json['media'] as Map<String, dynamic>? ?? {}),
      basePrice: json['base_price'] as int? ?? 0,
      dietaryTags: tags.map((e) => e as String).toList(),
      customizationGroups: groups
          .map(
            (e) => CustomizationGroupModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      isPromo: json['is_promo'] as bool? ?? false,
    );
  }
}

/// Mapped from Go `catalog.Media`.
class MediaModel {
  final String imageUrlSm;
  final String imageUrlLg;

  const MediaModel({required this.imageUrlSm, required this.imageUrlLg});

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      imageUrlSm: json['image_url_sm'] as String? ?? '',
      imageUrlLg: json['image_url_lg'] as String? ?? '',
    );
  }
}

/// Mapped from Go `catalog.CustomizationGroup`.
class CustomizationGroupModel {
  final String code;
  final int id;
  final String type;
  final bool required;
  final int minSelections;
  final int maxSelections;
  final String name;
  final List<CustomizationOptionModel> options;

  const CustomizationGroupModel({
    required this.code,
    required this.id,
    required this.type,
    required this.required,
    required this.minSelections,
    required this.maxSelections,
    required this.name,
    required this.options,
  });

  factory CustomizationGroupModel.fromJson(Map<String, dynamic> json) {
    final opts = json['options'] as List<dynamic>? ?? [];
    return CustomizationGroupModel(
      code: json['code'] as String? ?? '',
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      minSelections: json['min_selections'] as int? ?? 0,
      maxSelections: json['max_selections'] as int? ?? 1,
      name: json['name'] as String? ?? '',
      options: opts
          .map(
            (e) => CustomizationOptionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Mapped from Go `catalog.CustomizationOption`.
class CustomizationOptionModel {
  final String code;
  final int id;
  final String name;
  final int priceAdjustment;
  final bool isDefault;
  final bool isAvailable;

  const CustomizationOptionModel({
    required this.code,
    required this.id,
    required this.name,
    required this.priceAdjustment,
    required this.isDefault,
    required this.isAvailable,
  });

  factory CustomizationOptionModel.fromJson(Map<String, dynamic> json) {
    return CustomizationOptionModel(
      code: json['code'] as String? ?? '',
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      priceAdjustment: json['price_adjustment'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}
