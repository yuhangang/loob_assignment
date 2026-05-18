import 'dart:convert';

import '../../../cart/data/models/checkout_response_model.dart';
import '../../../cart/data/models/order_status_model.dart';
import '../../../menu/data/models/catalog_model.dart';

class LocalOrderModel {
  final String orderTrackingId;
  final String countryCode;
  final String status;
  final String paymentStatus;
  final int subtotal;
  final List<ChargeLineModel> charges;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;
  final String createdAt;
  final String updatedAt;
  final List<LocalOrderItemModel> items;

  const LocalOrderModel({
    required this.orderTrackingId,
    required this.countryCode,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    this.charges = const [],
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory LocalOrderModel.fromCheckout({
    required CheckoutResponseModel checkout,
    required String countryCode,
    List<LocalOrderItemModel> items = const [],
  }) {
    final now = DateTime.now().toIso8601String();
    return LocalOrderModel(
      orderTrackingId: checkout.orderTrackingId,
      countryCode: countryCode,
      status: checkout.status,
      paymentStatus: checkout.payment?.status ?? '',
      subtotal: checkout.subtotal,
      charges: checkout.charges,
      taxAmount: checkout.taxAmount,
      discountAmount: checkout.discountAmount,
      totalAmount: checkout.totalAmount,
      createdAt: now,
      updatedAt: now,
      items: items,
    );
  }

  factory LocalOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return LocalOrderModel(
      orderTrackingId: json['order_tracking_id'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? 'MY',
      status: json['status'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      subtotal: json['subtotal'] as int? ?? 0,
      charges: (json['charges'] as List<dynamic>? ?? const [])
          .map((e) => ChargeLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxAmount: json['tax_amount'] as int? ?? 0,
      discountAmount: json['discount_amount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      items: rawItems
          .map(
            (item) =>
                LocalOrderItemModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  factory LocalOrderModel.fromEncoded(String value) {
    return LocalOrderModel.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() {
    return {
      'order_tracking_id': orderTrackingId,
      'country_code': countryCode,
      'status': status,
      'payment_status': paymentStatus,
      'subtotal': subtotal,
      'charges': charges.map((charge) => charge.toJson()).toList(),
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  String encode() => jsonEncode(toJson());

  OrderStatusModel toStatusFallback() {
    return OrderStatusModel(
      orderTrackingId: orderTrackingId,
      status: status,
      paymentStatus: paymentStatus,
      subtotal: subtotal,
      charges: charges,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class LocalOrderItemModel {
  final int menuItemId;
  final String skuCode;
  final String name;
  final String description;
  final String imageUrlSm;
  final String imageUrlLg;
  final int basePrice;
  final int quantity;
  final bool isAvailable;
  final List<String> dietaryTags;
  final List<int> customizationOptionIds;
  final List<LocalOrderOptionModel> customizationOptions;

  const LocalOrderItemModel({
    required this.menuItemId,
    required this.skuCode,
    required this.name,
    required this.description,
    required this.imageUrlSm,
    required this.imageUrlLg,
    required this.basePrice,
    required this.quantity,
    required this.isAvailable,
    required this.dietaryTags,
    required this.customizationOptionIds,
    required this.customizationOptions,
  });

  factory LocalOrderItemModel.fromJson(Map<String, dynamic> json) {
    final tags = json['dietary_tags'] as List<dynamic>? ?? const [];
    final ids = json['customization_option_ids'] as List<dynamic>? ?? const [];
    final options = json['customization_options'] as List<dynamic>? ?? const [];
    return LocalOrderItemModel(
      menuItemId: json['menu_item_id'] as int? ?? 0,
      skuCode: json['sku_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrlSm: json['image_url_sm'] as String? ?? '',
      imageUrlLg: json['image_url_lg'] as String? ?? '',
      basePrice: json['base_price'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      isAvailable: json['is_available'] as bool? ?? true,
      dietaryTags: tags.whereType<String>().toList(),
      customizationOptionIds: ids.whereType<int>().toList()..sort(),
      customizationOptions: options
          .map(
            (option) =>
                LocalOrderOptionModel.fromJson(option as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  factory LocalOrderItemModel.fromProduct({
    required ProductModel product,
    required int quantity,
    required List<int> customizationOptionIds,
    required List<CustomizationOptionModel> customizationOptions,
  }) {
    return LocalOrderItemModel(
      menuItemId: product.id,
      skuCode: product.skuCode,
      name: product.name,
      description: product.description,
      imageUrlSm: product.media.imageUrlSm,
      imageUrlLg: product.media.imageUrlLg,
      basePrice: product.basePrice,
      quantity: quantity,
      isAvailable: product.isAvailable,
      dietaryTags: product.dietaryTags,
      customizationOptionIds: List<int>.from(customizationOptionIds)..sort(),
      customizationOptions: customizationOptions
          .map(LocalOrderOptionModel.fromCustomizationOption)
          .toList(),
    );
  }

  ProductModel toProduct() {
    return ProductModel(
      id: menuItemId,
      skuCode: skuCode,
      isAvailable: isAvailable,
      name: name,
      description: description,
      media: MediaModel(imageUrlSm: imageUrlSm, imageUrlLg: imageUrlLg),
      basePrice: basePrice,
      dietaryTags: dietaryTags,
      customizationGroups: const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_item_id': menuItemId,
      'sku_code': skuCode,
      'name': name,
      'description': description,
      'image_url_sm': imageUrlSm,
      'image_url_lg': imageUrlLg,
      'base_price': basePrice,
      'quantity': quantity,
      'is_available': isAvailable,
      'dietary_tags': dietaryTags,
      'customization_option_ids': customizationOptionIds,
      'customization_options': customizationOptions
          .map((option) => option.toJson())
          .toList(),
    };
  }
}

class LocalOrderOptionModel {
  final int id;
  final String code;
  final String name;
  final int priceAdjustment;
  final bool isAvailable;

  const LocalOrderOptionModel({
    required this.id,
    required this.code,
    required this.name,
    required this.priceAdjustment,
    required this.isAvailable,
  });

  factory LocalOrderOptionModel.fromJson(Map<String, dynamic> json) {
    return LocalOrderOptionModel(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceAdjustment: json['price_adjustment'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  factory LocalOrderOptionModel.fromCustomizationOption(
    CustomizationOptionModel option,
  ) {
    return LocalOrderOptionModel(
      id: option.id,
      code: option.code,
      name: option.name,
      priceAdjustment: option.priceAdjustment,
      isAvailable: option.isAvailable,
    );
  }

  CustomizationOptionModel toCustomizationOption() {
    return CustomizationOptionModel(
      code: code,
      id: id,
      name: name,
      priceAdjustment: priceAdjustment,
      isDefault: false,
      isAvailable: isAvailable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'price_adjustment': priceAdjustment,
      'is_available': isAvailable,
    };
  }
}
