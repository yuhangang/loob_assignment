import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../bloc/cart_item.dart';

class CheckoutItemTile extends StatelessWidget {
  final CartItem item;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const CheckoutItemTile({
    super.key,
    required this.item,
    required this.currency,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfigure = item.product.customizationGroups.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.selectedOptions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.selectedOptions
                            .map((option) => option.name)
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ] else if (item.customizationOptionIds.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.l10n.configuredItem,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                item.totalPrice.toDisplayPrice(currency),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                item.unitPrice.toDisplayPrice(currency),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              CheckoutQuantityPill(quantity: item.quantity),
              if (canConfigure) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(context.l10n.choicesBtn),
                ),
              ],
              IconButton(
                tooltip: context.l10n.removeTooltip,
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CheckoutQuantityPill extends StatelessWidget {
  final int quantity;

  const CheckoutQuantityPill({super.key, required this.quantity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: theme.dividerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'Qty $quantity',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.textTheme.labelLarge?.color?.withValues(
                  alpha: 0.72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
