import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../data/models/store_model.dart';

/// Compact collapsed header for sticky behavior when scrolling products
class CollapsedMenuHeader extends StatelessWidget {
  const CollapsedMenuHeader({
    super.key,
    required this.selectedStore,
    required this.primaryColor,
    required this.onChangeOutlet,
  });

  final StoreModel selectedStore;
  final Color primaryColor;
  final VoidCallback onChangeOutlet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_rounded, color: primaryColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: onChangeOutlet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
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
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, color: primaryColor, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Action for search if needed
            },
            icon: Icon(Icons.search_rounded, color: primaryColor, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
