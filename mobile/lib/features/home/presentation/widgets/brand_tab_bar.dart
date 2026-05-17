import 'package:flutter/material.dart';
import '../../../../core/theme/brand.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';

/// Animated brand tab bar: [ Discover | Tealive | Baskbear ]
class BrandTabBar extends StatelessWidget {
  final LoobBrand activeBrand;
  final ValueChanged<LoobBrand> onBrandSelected;

  const BrandTabBar({
    super.key,
    required this.activeBrand,
    required this.onBrandSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: LoobBrand.values.map((brand) {
          final isActive = brand == activeBrand;
          return Expanded(
            child: GestureDetector(
              onTap: () => onBrandSelected(brand),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isActive
                      ? _activeColor(brand)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  brand.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? _activeTextColor(brand)
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _activeColor(LoobBrand brand) {
    switch (brand) {
      case LoobBrand.discover:
        return AppColors.neutralPrimary;
      case LoobBrand.tealive:
        return AppColors.tealivePrimary;
      case LoobBrand.baskbear:
        return AppColors.baskbearAccent;
    }
  }

  Color _activeTextColor(LoobBrand brand) {
    return Colors.white;
  }
}
