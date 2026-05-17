import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/router/app_router.dart';
import 'cubit/cart_cubit.dart';
import 'cubit/cart_state.dart';
import 'cubit/cart_item.dart';
import '../../../core/di/injection.dart';
import '../../menu/data/repositories/menu_repository.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/localization/language_cubit.dart';
import '../../menu/data/models/catalog_model.dart';

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
          BlocBuilder<CartCubit, CartState>(
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
      body: BlocBuilder<CartCubit, CartState>(
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
                        return _buildCartItemCard(
                          context,
                          item,
                          theme,
                          state.currency,
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
                child: _buildStickyCheckoutPanel(context, state, theme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.cartEmpty,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color?.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.cartEmptySub,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.tonal(
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
      ],
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    CartItem item,
    ThemeData theme,
    String currency,
  ) {
    final isUnavailable = !item.isAvailable;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isUnavailable
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.08),
          width: isUnavailable ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          onTap: () => _editCartItem(context, item, currency),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    child: Image.network(
                      'http://localhost:8080${item.product.media.imageUrlSm}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.local_cafe_rounded,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUnavailable
                              ? theme.colorScheme.error.withValues(alpha: 0.7)
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isUnavailable) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                          ),
                          child: Text(
                            'Unavailable — please remove',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                      if (item.selectedOptions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: 4,
                          children: item.selectedOptions.map((opt) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                              child: Text(
                                opt.priceAdjustment > 0
                                    ? '${opt.name} (+${opt.priceAdjustment.toDisplayPrice(currency)})'
                                    : opt.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.totalPrice.toDisplayPrice(currency),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.quantity > 1) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.unitPrice.toDisplayPrice(currency)} each',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.5),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _QuantityStepper(
                            quantity: item.quantity,
                            onDecrease: () {
                              context.read<CartCubit>().updateQuantity(
                                item,
                                item.quantity - 1,
                              );
                            },
                            onIncrease: () {
                              context.read<CartCubit>().updateQuantity(
                                item,
                                item.quantity + 1,
                              );
                            },
                          ),
                        ],
                      ),
                      if (item.product.customizationGroups.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () =>
                              _editCartItem(context, item, currency),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Adjust choices'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editCartItem(
    BuildContext context,
    CartItem item,
    String currency,
  ) async {
    final cartState = context.read<CartCubit>().state;
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
      final catalog = await sl<MenuRepository>().loadCategoryBackedCatalog(
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
    final result = await Navigator.pushNamed(
      context,
      AppRouter.productDetail,
      arguments: {
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

    if (action == 'add') {
      context.read<CartCubit>().addToCart(
        product: enrichedProduct,
        selectedOptions: selectedOptions,
        customizationOptionIds: selectedIds,
        quantity: quantity,
      );
    } else {
      context.read<CartCubit>().updateItemConfiguration(
        item: item,
        selectedOptions: selectedOptions,
        quantity: quantity,
      );
    }
  }

  Widget _buildStickyCheckoutPanel(
    BuildContext context,
    CartState state,
    ThemeData theme,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.scaffoldBackgroundColor.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
            AppSpacing.pageHorizontal,
            AppSpacing.xl,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.textTheme.titleMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      state.totalPrice.toDisplayPrice(state.currency),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          state.hasUnavailableItems ||
                              state.isSelectedStoreClosed
                          ? theme.colorScheme.error.withValues(alpha: 0.3)
                          : theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXl,
                        ),
                      ),
                      elevation: 0,
                    ),
                    onPressed:
                        state.hasUnavailableItems || state.isSelectedStoreClosed
                        ? null
                        : () {
                            Navigator.pushNamed(context, AppRouter.checkout);
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.hasUnavailableItems
                              ? 'Remove unavailable items first'
                              : state.isSelectedStoreClosed
                              ? 'Selected outlet is closed'
                              : 'Proceed to Checkout',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (!state.hasUnavailableItems &&
                            !state.isSelectedStoreClosed) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClearCart(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              context.read<CartCubit>().clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.dividerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            onPressed: onDecrease,
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}
