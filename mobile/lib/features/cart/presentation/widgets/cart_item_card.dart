import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_item.dart';

/// A premium, reusable card displaying items inside the shopping cart.
///
/// Shows granular availability warnings:
/// - Product-level: "This item is currently unavailable"
/// - Option-level: individual chips turn red for unavailable variants/add-ons
class CartItemCard extends StatelessWidget {
  final CartItem item;
  final String currency;
  final VoidCallback onTap;

  const CartItemCard({
    super.key,
    required this.item,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProductUnavailable = !item.isAvailable;
    final hasOptionWarnings = item.hasUnavailableOptions;
    final hasAnyWarning = isProductUnavailable || hasOptionWarnings;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: hasAnyWarning
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.08),
          width: hasAnyWarning ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          onTap: onTap,
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
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: item.product.media.imageUrlSm,
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                          placeholder: (context, url) => Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.local_cafe_rounded,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                            size: 32,
                          ),
                        ),
                        if (isProductUnavailable)
                          Container(
                            width: 72,
                            height: 72,
                            color: AppColors.black.withValues(alpha: 0.45),
                            child: const Center(
                              child: Icon(
                                Icons.block_rounded,
                                color: AppColors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
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
                          color: isProductUnavailable
                              ? theme.colorScheme.error.withValues(alpha: 0.7)
                              : null,
                          decoration: isProductUnavailable
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // ── Product-level unavailability warning ──
                      if (isProductUnavailable) ...[
                        const SizedBox(height: 4),
                        _WarningBadge(
                          text: context.l10n.productUnavailable,
                          theme: theme,
                        ),
                      ],

                      // ── Option-level unavailability warning ──
                      if (!isProductUnavailable && hasOptionWarnings) ...[
                        const SizedBox(height: 4),
                        _WarningBadge(
                          text: context.l10n.someOptionsUnavailable,
                          theme: theme,
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.textFulfillmentOrange,
                          bgColor: AppColors.lightFulfillmentOrangeBg,
                        ),
                      ],

                      // ── Selected options chips ──
                      if (item.selectedOptions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: 4,
                          children: item.selectedOptions.map((opt) {
                            final isOptUnavailable = !opt.isAvailable;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOptUnavailable
                                    ? theme.colorScheme.error.withValues(
                                        alpha: 0.08,
                                      )
                                    : theme.colorScheme.primary.withValues(
                                        alpha: 0.06,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                border: isOptUnavailable
                                    ? Border.all(
                                        color: theme.colorScheme.error
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOptUnavailable) ...[
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 10,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Flexible(
                                    child: Text(
                                      isOptUnavailable
                                          ? context.l10n.optionUnavailableTag(
                                              opt.name,
                                            )
                                          : opt.priceAdjustment > 0
                                          ? '${opt.name} (+${opt.priceAdjustment.toDisplayPrice(currency)})'
                                          : opt.name,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: isOptUnavailable
                                                ? theme.colorScheme.error
                                                : theme.colorScheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            decoration: isOptUnavailable
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                    ),
                                  ),
                                ],
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
                                    '${item.unitPrice.toDisplayPrice(currency)} ${context.l10n.eachLabel}',
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
                          QuantityStepper(
                            quantity: item.quantity,
                            style: QuantityStepperStyle.compact,
                            onDecrease: () {
                              if (item.quantity == 1) {
                                _confirmRemoveItem(context, item);
                              } else {
                                context.read<CartBloc>().add(
                                  CartItemQuantityUpdated(
                                    item: item,
                                    quantity: item.quantity - 1,
                                  ),
                                );
                              }
                            },
                            onIncrease: () {
                              context.read<CartBloc>().add(
                                CartItemQuantityUpdated(
                                  item: item,
                                  quantity: item.quantity + 1,
                                ),
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
                          onPressed: onTap,
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: Text(context.l10n.adjustChoices),
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

  void _confirmRemoveItem(BuildContext context, CartItem item) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.removeItemTitle),
        content: Text(context.l10n.removeItemContent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              context.read<CartBloc>().add(
                CartItemQuantityUpdated(item: item, quantity: 0),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.itemUnavailableRemove),
          ),
        ],
      ),
    );
  }
}

/// Compact warning badge used for product and option unavailability messages.
class _WarningBadge extends StatelessWidget {
  const _WarningBadge({
    required this.text,
    required this.theme,
    this.icon = Icons.error_outline_rounded,
    this.color,
    this.bgColor,
  });

  final String text;
  final ThemeData theme;
  final IconData icon;
  final Color? color;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? theme.colorScheme.error;
    final effectiveBg =
        bgColor ?? theme.colorScheme.error.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effectiveColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
