class ProductAvailabilityModel {
  final int itemId;
  final int storeId;
  final bool isAvailable;
  final Map<int, bool> optionAvailability;

  const ProductAvailabilityModel({
    required this.itemId,
    required this.storeId,
    required this.isAvailable,
    required this.optionAvailability,
  });

  factory ProductAvailabilityModel.fromJson(Map<String, dynamic> json) {
    final options = json['customization_options'] as List<dynamic>? ?? const [];
    return ProductAvailabilityModel(
      itemId: json['item_id'] as int? ?? 0,
      storeId: json['store_id'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? false,
      optionAvailability: {
        for (final option in options)
          if (option is Map<String, dynamic>)
            option['id'] as int? ?? 0: option['is_available'] as bool? ?? false,
      }..remove(0),
    );
  }
}
