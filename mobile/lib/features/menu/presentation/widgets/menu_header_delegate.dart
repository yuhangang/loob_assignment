import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/colors.dart';
import '../../data/models/store_model.dart';
import 'menu_header.dart';
import 'collapsed_menu_header.dart';

/// Custom delegate for collapsible premium sticky Menu Header
class MenuHeaderDelegate extends SliverPersistentHeaderDelegate {
  MenuHeaderDelegate({
    required this.brandName,
    required this.isPickup,
    required this.selectedStore,
    required this.primaryColor,
    required this.onFulfillmentChanged,
    required this.onChangeOutlet,
  });

  final String brandName;
  final bool isPickup;
  final StoreModel selectedStore;
  final Color primaryColor;
  final ValueChanged<bool> onFulfillmentChanged;
  final VoidCallback onChangeOutlet;

  @override
  double get minExtent => 82.0;

  @override
  double get maxExtent => 195.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final limit = maxExtent - minExtent;
    final percent = limit > 0 ? (shrinkOffset / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: AppColors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Expanded Header Content
          Opacity(
            opacity: (1.0 - percent * 1.5).clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: MenuHeader(
                  brandName: brandName,
                  isPickup: isPickup,
                  selectedStore: selectedStore,
                  primaryColor: primaryColor,
                  onFulfillmentChanged: onFulfillmentChanged,
                  onChangeOutlet: onChangeOutlet,
                ),
              ),
            ),
          ),

          // Collapsed Sticky Header Content
          Opacity(
            opacity: (percent - 0.4).clamp(0.0, 1.0) * (1.0 / 0.6),
            child: Align(
              alignment: Alignment.center,
              child: CollapsedMenuHeader(
                selectedStore: selectedStore,
                primaryColor: primaryColor,
                onChangeOutlet: onChangeOutlet,
              ),
            ),
          ),

          // Top/Bottom border/divider
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(height: 1, color: AppColors.dividerBeige),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant MenuHeaderDelegate oldDelegate) {
    return oldDelegate.brandName != brandName ||
        oldDelegate.isPickup != isPickup ||
        oldDelegate.selectedStore != selectedStore ||
        oldDelegate.primaryColor != primaryColor;
  }
}
