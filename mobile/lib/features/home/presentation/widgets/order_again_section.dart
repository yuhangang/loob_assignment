import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../cart/presentation/bloc/cart_event.dart';
import '../../../cart/presentation/bloc/cart_item.dart';
import '../../../menu/data/models/catalog_model.dart';
import '../../../orders/data/models/local_order_model.dart';

class OrderAgainSection extends StatelessWidget {
  final List<LocalOrderItemModel> products;
  final String currency;
  final int storeId;

  const OrderAgainSection({
    super.key,
    required this.products,
    this.currency = 'MYR',
    this.storeId = 0,
  });

  /// Fetches the full product, then fast-adds the saved configuration when possible.
  Future<void> _reorder(
    BuildContext context,
    LocalOrderItemModel orderItem,
  ) async {
    AuthGuard.run(context, () async {
      ProductModel fullProduct = orderItem.toProduct();
      try {
        final cartState = context.read<CartBloc>().state;
        final resolvedStoreId = storeId > 0 ? storeId : cartState.storeId;
        final response = await sl<ApiClient>().dio.get(
          ApiEndpoints.catalogItem(orderItem.menuItemId),
          queryParameters: resolvedStoreId > 0
              ? {'store_id': resolvedStoreId}
              : null,
        );
        fullProduct = ProductModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      } catch (_) {
        // Fall back to the local snapshot so previous-order quick add still works
        // when the catalog call is unavailable.
      }

      if (!context.mounted) return;
      final savedOptionIds = orderItem.customizationOptionIds;
      if (savedOptionIds.isNotEmpty) {
        final selectedOptions = _resolveSelectedOptions(
          fullProduct,
          orderItem,
          savedOptionIds,
        );
        context.read<CartBloc>().add(
          CartItemAdded(
            product: fullProduct,
            selectedOptions: selectedOptions,
            customizationOptionIds: savedOptionIds,
            quantity: orderItem.quantity < 1 ? 1 : orderItem.quantity,
          ),
        );
        context.showSuccessSnackBar(
          context.l10n.addedToCartReorderToast(orderItem.name),
        );
        return;
      }

      if (fullProduct.customizationGroups.isEmpty) {
        context.read<CartBloc>().add(
          CartItemAdded(
            product: fullProduct,
            selectedOptions: const [],
            customizationOptionIds: const [],
            quantity: orderItem.quantity < 1 ? 1 : orderItem.quantity,
          ),
        );
        context.showSuccessSnackBar(
          context.l10n.addedToCartReorderToast(orderItem.name),
        );
        return;
      }

      final result = await context.push(
        AppRouter.productDetail,
        extra: {'product': fullProduct, 'currency': currency},
      );
      if (result is! Map<String, dynamic>) return;
      if (!context.mounted) return;

      final quantity = result['quantity'] as int? ?? 1;
      final selectionsMap =
          result['selections'] as Map<dynamic, dynamic>? ?? {};
      final allOptionIds = <int>[];
      for (final ids in selectionsMap.values) {
        if (ids is List) allOptionIds.addAll(ids.whereType<int>());
      }
      final selectedOptions = fullProduct.customizationGroups
          .expand((g) => g.options)
          .where((o) => allOptionIds.contains(o.id))
          .toList();

      final action = result['action'] as String? ?? 'add';

      if (action == 'buy_now') {
        final buyNowItem = CartItem(
          product: fullProduct,
          selectedOptions: selectedOptions,
          customizationOptionIds: allOptionIds,
          quantity: 1,
        );
        AuthGuard.run(context, () {
          context.push(
            AppRouter.checkout,
            extra: {'buyNowItem': buyNowItem},
          );
        });
      } else {
        context.read<CartBloc>().add(
          CartItemAdded(
            product: fullProduct,
            selectedOptions: selectedOptions,
            customizationOptionIds: allOptionIds,
            quantity: quantity,
          ),
        );
        if (!context.mounted) return;
        context.showSuccessSnackBar(
          context.l10n.addedToCartReorderToast(orderItem.name),
        );
      }
    });
  }

  List<CustomizationOptionModel> _resolveSelectedOptions(
    ProductModel product,
    LocalOrderItemModel orderItem,
    List<int> optionIds,
  ) {
    final catalogOptions = product.customizationGroups
        .expand((group) => group.options)
        .where((option) => optionIds.contains(option.id))
        .toList();
    if (catalogOptions.length == optionIds.length) return catalogOptions;
    return orderItem.customizationOptions
        .where((option) => optionIds.contains(option.id))
        .map((option) => option.toCustomizationOption())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Icons.replay_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.l10n.orderAgain,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 156,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                width: 260,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? AppColors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Product Image (CDN loaded)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppSpacing.radiusLg),
                        bottomLeft: Radius.circular(AppSpacing.radiusLg),
                      ),
                      child: SizedBox(
                        width: 90,
                        height: double.infinity,
                        child: Image.network(
                          product.imageUrlSm,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.05,
                                ),
                                child: Icon(
                                  Icons.local_cafe_rounded,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    // Product details + Direct quick reorder action
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              product.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.basePrice.toDisplayPrice(currency),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            // Reorder Action button
                            Align(
                              alignment: Alignment.bottomRight,
                              child: FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.all(8),
                                  shape: CircleBorder(),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _reorder(context, product),
                                child: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
