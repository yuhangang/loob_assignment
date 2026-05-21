import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/widgets/status_message.dart';
import '../../menu/data/models/catalog_model.dart';
import '../../menu/domain/repositories/menu_repository.dart';
import 'bloc/cart_bloc.dart';
import 'bloc/cart_event.dart';
import 'bloc/cart_item.dart';
import 'bloc/cart_state.dart';
import 'widgets/cart_item_card.dart';
import 'widgets/sticky_checkout_panel.dart';

/// Cart page showing items dynamically with full control over quantities and options.
class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.myCart,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              if (state.items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  Icons.delete_sweep_rounded,
                  color: theme.colorScheme.error,
                ),
                tooltip: 'Clear Cart',
                onPressed: () => _confirmClearCart(context),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return _buildEmptyState(context, theme);
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.lg,
                      AppSpacing.pageHorizontal,
                      130.0, // Space so content isn't covered by bottom sticky bar
                    ),
                    sliver: SliverList.separated(
                      itemCount: state.items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return CartItemCard(
                          item: item,
                          currency: state.currency,
                          onTap: () =>
                              _editCartItem(context, item, state.currency),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Sticky Checkout Summary Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: StickyCheckoutPanel(state: state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return StatusMessage(
      icon: Icons.shopping_cart_outlined,
      title: context.l10n.cartEmpty,
      subtitle: context.l10n.cartEmptySub,
      iconColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      iconSize: 80.0,
      action: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        ),
        onPressed: () {
          // Navigate back to Menu
          Navigator.of(context).pop();
        },
        child: Text(
          context.l10n.browseMenu,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _editCartItem(
    BuildContext context,
    CartItem item,
    String currency,
  ) async {
    final cartState = context.read<CartBloc>().state;
    final storeId = cartState.storeId;
    final countryCode = cartState.countryCode;
    final brand = context.read<ThemeCubit>().state;
    final brandId = brand.brandId ?? 1;
    final lang = context.read<LanguageCubit>().state.languageCode;

    // Show a beautiful modern loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    ProductModel enrichedProduct = item.product;
    try {
      final catalog = await sl<IMenuRepository>().loadCategoryBackedCatalog(
        countryCode: countryCode,
        language: lang,
        storeId: storeId,
        brandId: brandId,
      );
      enrichedProduct = catalog.categories
          .expand((c) => c.products)
          .firstWhere(
            (p) => p.id == item.product.id,
            orElse: () => item.product,
          );
    } catch (e) {
      // Fallback to current item's product snapshot
    } finally {
      if (context.mounted) {
        Navigator.pop(context); // Pop the loading indicator
      }
    }

    if (!context.mounted) return;
    final result = await context.push(
      AppRouter.productDetail,
      extra: {
        'product': enrichedProduct,
        'currency': currency,
        'cartItem': item,
      },
    );
    if (!context.mounted || result is! Map<String, dynamic>) return;

    final quantity = result['quantity'] as int? ?? item.quantity;
    final action = result['action'] as String? ?? 'update';
    final selectionsMap = result['selections'] as Map<dynamic, dynamic>? ?? {};
    final selectedIds = <int>[];
    for (final ids in selectionsMap.values) {
      if (ids is List) {
        selectedIds.addAll(ids.whereType<int>());
      }
    }
    final selectedOptions = enrichedProduct.customizationGroups
        .expand((group) => group.options)
        .where((option) => selectedIds.contains(option.id))
        .toList();

    if (action == 'buy_now') {
      final buyNowItem = CartItem(
        product: enrichedProduct,
        selectedOptions: selectedOptions,
        customizationOptionIds: selectedIds,
        quantity: quantity,
      );
      context.push(AppRouter.checkout, extra: {'buyNowItem': buyNowItem});
      return;
    }

    if (action == 'add') {
      context.read<CartBloc>().add(
        CartItemAdded(
          product: enrichedProduct,
          selectedOptions: selectedOptions,
          customizationOptionIds: selectedIds,
          quantity: quantity,
        ),
      );
    } else {
      context.read<CartBloc>().add(
        CartItemConfigurationUpdated(
          item: item,
          selectedOptions: selectedOptions,
          quantity: quantity,
        ),
      );
    }
  }

  void _confirmClearCart(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.clearCartTitle),
        content: Text(context.l10n.clearCartContent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              context.read<CartBloc>().add(const CartCleared());
              Navigator.pop(context);
            },
            child: Text(context.l10n.clearAll),
          ),
        ],
      ),
    );
  }
}
