import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../data/models/catalog_model.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/quantity_stepper.dart';

/// Bottom sheet for product customization (Size, Sugar, Ice, Toppings).
class CustomizationSheet extends StatefulWidget {
  final ProductModel product;
  final String currency;
  final void Function(Map<int, List<int>> selectedOptions, int quantity)?
  onAddToCart;

  const CustomizationSheet({
    super.key,
    required this.product,
    this.currency = 'MYR',
    this.onAddToCart,
  });

  @override
  State<CustomizationSheet> createState() => _CustomizationSheetState();
}

class _CustomizationSheetState extends State<CustomizationSheet> {
  int _quantity = 1;
  // group.id -> selected option ids
  final Map<int, Set<int>> _selections = {};

  @override
  void initState() {
    super.initState();
    // Pre-select defaults
    for (final group in widget.product.customizationGroups) {
      final defaults = <int>{};
      for (final option in group.options) {
        if (option.isDefault) {
          defaults.add(option.id);
          if (_isSingleSelect(group)) {
            break;
          }
        }
      }
      if (defaults.isNotEmpty) {
        _selections[group.id] = defaults;
      }
    }
  }

  int get _totalPrice {
    var price = widget.product.basePrice;
    for (final group in widget.product.customizationGroups) {
      final selectedIds = _selections[group.id] ?? const <int>{};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          price += option.priceAdjustment;
        }
      }
    }
    return price * _quantity;
  }

  bool get _hasValidSelections {
    for (final group in widget.product.customizationGroups) {
      final count = (_selections[group.id] ?? const <int>{}).length;
      if (count < group.minSelections) {
        return false;
      }
      if (group.maxSelections > 0 && count > group.maxSelections) {
        return false;
      }
      if (_isSingleSelect(group) && count > 1) {
        return false;
      }
    }
    return true;
  }

  bool _isSingleSelect(CustomizationGroupModel group) {
    return group.type == 'SINGLE_SELECT' || group.maxSelections == 1;
  }

  bool _isSelected(CustomizationGroupModel group, int optionID) {
    return _selections[group.id]?.contains(optionID) ?? false;
  }

  String _groupHint(BuildContext context, CustomizationGroupModel group) {
    if (_isSingleSelect(group)) {
      return group.minSelections > 0 ? 'Choose 1' : 'Optional';
    }
    final max = group.maxSelections;
    if (max > 0) {
      return 'Choose up to $max';
    }
    return group.required
        ? 'Choose at least ${group.minSelections}'
        : 'Optional';
  }

  void _toggleOption(CustomizationGroupModel group, int optionID) {
    final current = Set<int>.from(_selections[group.id] ?? const <int>{});

    if (_isSingleSelect(group)) {
      if (current.contains(optionID) && group.minSelections == 0) {
        current.clear();
      } else {
        current
          ..clear()
          ..add(optionID);
      }
    } else if (current.contains(optionID)) {
      if (current.length > group.minSelections) {
        current.remove(optionID);
      }
    } else {
      if (group.maxSelections <= 0 || current.length < group.maxSelections) {
        current.add(optionID);
      }
    }

    setState(() {
      if (current.isEmpty) {
        _selections.remove(group.id);
      } else {
        _selections[group.id] = current;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                  ),
                  children: [
                    // Product header
                    Text(
                      widget.product.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.product.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Customization groups
                    ...widget.product.customizationGroups.map((group) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                group.name,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                _groupHint(context, group),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                              ),
                              if (group.required)
                                Container(
                                  margin: const EdgeInsets.only(
                                    left: AppSpacing.sm,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    context.l10n.requiredText,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: group.options.map((option) {
                              final isSelected = _isSelected(group, option.id);
                              return ChoiceChip(
                                label: Text(
                                  option.priceAdjustment > 0
                                      ? '${option.name} (+${option.priceAdjustment.toDisplayPrice(widget.currency)})'
                                      : option.name,
                                ),
                                selected: isSelected,
                                onSelected: option.isAvailable
                                    ? (_) {
                                        _toggleOption(group, option.id);
                                      }
                                    : null,
                                selectedColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      );
                    }),

                    // Quantity selector
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: QuantityStepper(
                        quantity: _quantity,
                        style: QuantityStepperStyle.standard,
                        onDecrease: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        onIncrease: () => setState(() => _quantity++),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),

              // Add to cart button
              Padding(
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _hasValidSelections
                        ? () {
                            widget.onAddToCart?.call({
                              for (final entry in _selections.entries)
                                entry.key: entry.value.toList(),
                            }, _quantity);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: Text(
                      context.l10n.addToCartBtn(
                        _totalPrice.toDisplayPrice(widget.currency),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
