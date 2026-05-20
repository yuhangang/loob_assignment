import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../data/models/catalog_model.dart';

/// Left Sidebar Individual Category Tab
class SidebarCategoryTab extends StatelessWidget {
  const SidebarCategoryTab({
    super.key,
    required this.category,
    required this.isSelected,
    required this.primaryColor,
    required this.favouritedCount,
    required this.onTap,
  });

  final CategoryModel category;
  final bool isSelected;
  final Color primaryColor;
  final int favouritedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Generate beautiful custom category icons
    Widget iconWidget;

    if (category.id == -99) {
      // Favourites tab
      iconWidget = Icon(
        Icons.favorite_rounded,
        color: favouritedCount > 0 ? AppColors.error : AppColors.grey400,
        size: 24,
      );
    } else {
      // Retrieve the icon URL from the backend model
      final iconUrl = category.iconUrl;

      if (iconUrl.isNotEmpty) {
        final resolvedIconUrl = iconUrl.startsWith('http')
            ? iconUrl
            : '${sl<AppConfig>().baseUrl}$iconUrl';
        iconWidget = SvgPicture.network(
          resolvedIconUrl,
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            isSelected ? primaryColor : AppColors.grey500,
            BlendMode.srcIn,
          ),
          placeholderBuilder: (BuildContext context) => const SizedBox(
            width: 24,
            height: 24,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      } else {
        iconWidget = Icon(
          Icons.local_drink_rounded,
          color: isSelected ? primaryColor : AppColors.grey500,
          size: 24,
        );
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.tealiveWarmCream
              : AppColors.transparent, // Highlight color
          border: Border(
            left: BorderSide(
              color: isSelected ? primaryColor : AppColors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            // Circular container for icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.white : AppColors.grey50,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        const BoxShadow(
                          color: AppColors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(height: 6),

            // Category Name Label
            Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? primaryColor : AppColors.grey500,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
