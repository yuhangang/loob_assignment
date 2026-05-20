import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';
import 'dart:ui';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_state.dart';

/// Fullscreen premium product details and customization page inspired by HeyTea.
class ProductDetailPage extends StatefulWidget {
  final ProductModel product;
  final String currency;
  final int initialQuantity;
  final List<int> initialCustomizationOptionIds;
  final bool isEditingCartItem;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.currency = 'MYR',
    this.initialQuantity = 1,
    this.initialCustomizationOptionIds = const [],
    this.isEditingCartItem = false,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  // group.id -> selected option ids
  final Map<int, Set<int>> _selections = {};

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity < 1 ? 1 : widget.initialQuantity;
    final initialIds = widget.initialCustomizationOptionIds.toSet();

    for (final group in widget.product.customizationGroups) {
      if (initialIds.isNotEmpty) {
        final selected = group.options
            .where((option) => initialIds.contains(option.id))
            .map((option) => option.id)
            .toSet();
        if (selected.isNotEmpty) {
          _selections[group.id] = selected;
          continue;
        }
      }

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

  bool _isSingleSelect(CustomizationGroupModel group) {
    return group.type == 'SINGLE_SELECT' || group.maxSelections == 1;
  }

  bool _isSelected(CustomizationGroupModel group, int optionID) {
    return _selections[group.id]?.contains(optionID) ?? false;
  }

  bool get _hasValidSelections {
    for (final group in widget.product.customizationGroups) {
      final count = (_selections[group.id] ?? const <int>{}).length;
      if (count < group.minSelections) {
        return false;
      }
      if (_isSingleSelect(group) && count > 1) {
        return false;
      }
      if (group.maxSelections > 0 && count > group.maxSelections) {
        return false;
      }
    }
    return true;
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

  String _groupHint(CustomizationGroupModel group) {
    if (_isSingleSelect(group)) {
      return group.minSelections > 0 ? 'Choose 1' : 'Optional';
    }
    if (group.maxSelections > 0) {
      return 'Choose up to ${group.maxSelections}';
    }
    return group.required
        ? 'Choose at least ${group.minSelections}'
        : 'Optional';
  }

  Map<String, dynamic> _result(String action) {
    return {
      'action': action,
      'selections': {
        for (final entry in _selections.entries)
          entry.key: entry.value.toList(),
      },
      'quantity': action == 'buy_now' ? 1 : _quantity,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Scrollable Customization Content
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
                // 1. Premium Parallax Hero Image Area
                SliverAppBar(
                  expandedHeight: size.height * 0.38,
                  pinned: true,
                  stretch: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Stylized Premium Gradient & Vector Placeholder
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                theme.colorScheme.secondary.withValues(
                                  alpha: 0.05,
                                ),
                                theme.scaffoldBackgroundColor,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Soft elegant background concentric rings
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.03,
                                ),
                                width: 20,
                              ),
                            ),
                          ),
                        ),
                        // Cup icon/illustration with floating design
                        Center(
                          child: Hero(
                            tag: 'product_hero_${widget.product.id}',
                            child: Icon(
                              Icons.local_cafe_rounded,
                              size: 110,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                        // Glassmorphic gradient overlay at bottom of hero area
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 60,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.transparent,
                                  theme.scaffoldBackgroundColor.withValues(
                                    alpha: 0.6,
                                  ),
                                  theme.scaffoldBackgroundColor,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Product Summary Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          widget.product.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Pricing and Tags
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.product.basePrice.toDisplayPrice(
                                widget.currency,
                              ),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            if (widget.product.dietaryTags.isNotEmpty)
                              ...widget.product.dietaryTags.map(
                                (tag) => Container(
                                  margin: const EdgeInsets.only(
                                    right: AppSpacing.xs,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm,
                                    ),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Description
                        Text(
                          widget.product.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Divider(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),

                // 3. Grouped Customization Cards
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final group = widget.product.customizationGroups[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusXl,
                          ),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.02),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group header (Name & Required)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  group.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                Text(
                                  _groupHint(group),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.6),
                                  ),
                                ),
                                if (group.required)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSm,
                                      ),
                                    ),
                                    child: Text(
                                      context.l10n.requiredText,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Selection list
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: group.options.map((option) {
                                final isSelected = _isSelected(
                                  group,
                                  option.id,
                                );
                                return _buildSelectionChip(
                                  theme: theme,
                                  option: option,
                                  isSelected: isSelected,
                                  onTap: () {
                                    _toggleOption(group, option.id);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }, childCount: widget.product.customizationGroups.length),
                  ),
                ),

                // Spacing to keep content clear of the floating action panel
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // 4. Premium Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: AppSpacing.pageHorizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.white.withValues(alpha: 0.1)
                        : AppColors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.white,
                      size: 18,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),

          // Premium Floating Glassmorphic Cart Button with Badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: AppSpacing.pageHorizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: BlocBuilder<CartBloc, CartState>(
                  builder: (context, cartState) {
                    final count = cartState.totalQuantity;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? AppColors.white.withValues(alpha: 0.1)
                                : AppColors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.white,
                              size: 20,
                            ),
                            onPressed: () => context.push(AppRouter.cart),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // 5. Elegant Glassmorphic Bottom Sticky Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.scaffoldBackgroundColor.withValues(alpha: 0.82)
                        : AppColors.white.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.md,
                    AppSpacing.pageHorizontal,
                    AppSpacing.lg,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        // Top Row: Total Price and Quantity Stepper
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.l10n.totalLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _totalPrice.toDisplayPrice(widget.currency),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            QuantityStepper(
                              quantity: _quantity,
                              style: QuantityStepperStyle.standard,
                              compactButtonSize: widget.isEditingCartItem,
                              onDecrease: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              onIncrease: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Action Button
                        SizedBox(
                          height: 52,
                          child: widget.isEditingCartItem
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusXl,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: () {
                                          context.pushReplacement(
                                            AppRouter.productDetail,
                                            extra: {
                                              'product': widget.product,
                                              'currency': widget.currency,
                                            },
                                          );
                                        },
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Order other',
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          foregroundColor:
                                              theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusXl,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: _hasValidSelections
                                            ? () {
                                                Navigator.of(
                                                  context,
                                                ).pop(_result('update'));
                                              }
                                            : null,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            context.l10n.update,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusXl,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: _hasValidSelections
                                            ? () {
                                                Navigator.of(
                                                  context,
                                                ).pop(_result('buy_now'));
                                              }
                                            : null,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            context.l10n.buyNow,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          foregroundColor:
                                              theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusXl,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: _hasValidSelections
                                            ? () {
                                                Navigator.of(
                                                  context,
                                                ).pop(_result('add'));
                                              }
                                            : null,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            context.l10n.addToCart,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Large, easy to press custom selection chips with soft micro animations
  Widget _buildSelectionChip({
    required ThemeData theme,
    required CustomizationOptionModel option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: option.isAvailable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.brightness == Brightness.dark
              ? theme.colorScheme.surface.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: !option.isAvailable
                ? theme.disabledColor.withValues(alpha: 0.3)
                : isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: !option.isAvailable
                    ? theme.disabledColor
                    : isSelected
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
            if (option.priceAdjustment > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '(+${option.priceAdjustment.toDisplayPrice(widget.currency)})',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
