import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../data/models/store_model.dart';

/// Custom top Menu Header matching screenshots exactly
class MenuHeader extends StatelessWidget {
  const MenuHeader({
    super.key,
    required this.brandName,
    required this.selectedStore,
    required this.primaryColor,
    required this.onChangeOutlet,
    this.onSearchTap,
  });

  final String brandName;
  final StoreModel selectedStore;
  final Color primaryColor;
  final VoidCallback onChangeOutlet;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Pickup status + Business hour text
          Row(
            children: [
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_rounded,
                      color: primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.pickup,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              // Business Hour Details
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.door_sliding_outlined,
                      color: primaryColor.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.businessHourHeader,
                            style: const TextStyle(
                              color: AppColors
                                  .softPink, // Soft pink-purple color matching screenshot
                              fontWeight: FontWeight.w800,
                              fontSize: 8,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '10:30AM - 09:00PM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.black87,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2: Outlet selector
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: onChangeOutlet,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selectedStore.brandId == 1
                          ? AppColors.tealivePrimary
                          : AppColors.baskbearAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      selectedStore.brandId == 1 ? 'Tealive' : 'Bask Bear',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedStore.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.location_on, color: primaryColor, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Row 3: Outlined Search Bar with Boba cup prefix
          TextField(
            readOnly: true,
            onTap: onSearchTap,
            decoration: InputDecoration(
              hintText: context.l10n.searchBobaPlaceholder,
              hintStyle: TextStyle(
                color: primaryColor.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Icon(
                  Icons.local_drink_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              suffixIcon: Icon(
                Icons.search_rounded,
                color: primaryColor,
                size: 24,
              ),
              fillColor: AppColors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
