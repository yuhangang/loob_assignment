import 'package:flutter_test/flutter_test.dart';
import 'package:loob_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';

void main() {
  ProductModel product() {
    const regular = CustomizationOptionModel(
      code: 'REG',
      id: 10,
      name: 'Regular',
      priceAdjustment: 0,
      isDefault: true,
      isAvailable: true,
    );
    const large = CustomizationOptionModel(
      code: 'LRG',
      id: 11,
      name: 'Large',
      priceAdjustment: 150,
      isDefault: false,
      isAvailable: true,
    );

    return const ProductModel(
      id: 100,
      skuCode: 'TL-MILK-TEA',
      isAvailable: true,
      name: 'Milk Tea',
      description: '',
      media: MediaModel(imageUrlSm: '', imageUrlLg: ''),
      basePrice: 600,
      dietaryTags: [],
      customizationGroups: [
        CustomizationGroupModel(
          code: 'SIZE',
          id: 1,
          type: 'SINGLE_SELECT',
          required: true,
          minSelections: 1,
          maxSelections: 1,
          name: 'Size',
          options: [regular, large],
        ),
      ],
    );
  }

  test('same product with different choices stays as separate cart lines', () {
    final cubit = CartCubit();
    final item = product();

    cubit.addToCart(
      product: item,
      selectedOptions: [item.customizationGroups.first.options[0]],
      customizationOptionIds: const [10],
      quantity: 1,
    );
    cubit.addToCart(
      product: item,
      selectedOptions: [item.customizationGroups.first.options[1]],
      customizationOptionIds: const [11],
      quantity: 1,
    );

    expect(cubit.state.items, hasLength(2));
    expect(cubit.state.items[0].selectedCustomizationIds, [10]);
    expect(cubit.state.items[1].selectedCustomizationIds, [11]);
  });

  test('same product with same raw choice merges quantity', () {
    final cubit = CartCubit();
    final item = product();

    cubit.addToCart(
      product: item,
      selectedOptions: const [],
      customizationOptionIds: const [11],
      quantity: 1,
    );
    cubit.addToCart(
      product: item,
      selectedOptions: const [],
      customizationOptionIds: const [11],
      quantity: 2,
    );

    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.items.single.quantity, 3);
    expect(cubit.state.items.single.selectedCustomizationIds, [11]);
  });
}
