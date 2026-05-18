import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/models/catalog_model.dart';

/// Highly stylized circular product card matching the brand guidelines.
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final String currency;
  final bool isFavourited;
  final VoidCallback? onFavouriteToggled;
  final VoidCallback? onTap;
  final VoidCallback? onCartPressed;

  const ProductCard({
    super.key,
    required this.product,
    this.currency = 'MYR',
    this.isFavourited = false,
    this.onFavouriteToggled,
    this.onTap,
    this.onCartPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTealive = theme.colorScheme.primary == AppColors.tealivePrimary;
    final isDiscover = theme.colorScheme.primary == AppColors.discoverPrimary;

    // Core brand purple color
    final brandPurple = isTealive
        ? AppColors.tealivePrimary
        : (isDiscover ? AppColors.discoverGreen : theme.colorScheme.primary);

    // Calculate dynamic original price for mockup fidelity (e.g. +8% + RM1.00 / ฿1.00)
    final int currentPriceVal = product.basePrice;
    final int originalPriceVal = (currentPriceVal * 1.08 + 100).round();

    final currentPriceText = currentPriceVal.toDisplayPrice(currency);
    final originalPriceText = originalPriceVal.toDisplayPrice(currency);

    return GestureDetector(
      onTap: product.isAvailable ? onTap : null,
      child: Container(
        color: AppColors.transparent, // Keeps card touch-responsive
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular cup container with heart and NEW badges
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Circular Image Container
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          brandPurple.withValues(alpha: 0.05),
                          brandPurple.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ClipOval(
                        child: _BobaArtWidget(brandColor: brandPurple),
                      ),
                    ),
                  ),
                ),

                // NEW Badge (Top-Right Inner)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        context.l10n.newBadge,
                        style: const TextStyle(
                          color: AppColors.grey400,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),

                // Interactive Heart Icon (Top-Right Outer border of circle)
                Positioned(
                  top: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: onFavouriteToggled,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavourited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavourited ? AppColors.error : AppColors.grey400,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: product.isAvailable ? onCartPressed : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: product.isAvailable
                            ? brandPurple
                            : AppColors.grey300,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        product.customizationGroups.isEmpty
                            ? Icons.add_shopping_cart_rounded
                            : Icons.tune_rounded,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                // Unavailable Overlay
                if (!product.isAvailable)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          context.l10n.unavailableText,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Product Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                product.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: brandPurple,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Price display (original price with strikethrough + current price)
            Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  originalPriceText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey400,
                    decoration: TextDecoration.lineThrough,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  currentPriceText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: brandPurple,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A highly polished, beautiful custom vector-like widget that draws a detailed boba tea cup.
class _BobaArtWidget extends StatelessWidget {
  const _BobaArtWidget({required this.brandColor});

  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Background leaf details (Organic feeling)
            Positioned(
              bottom: h * 0.1,
              left: w * 0.15,
              child: Transform.rotate(
                angle: -0.4,
                child: Icon(
                  Icons.spa_rounded,
                  color: AppColors.parkGreen.withValues(alpha: 0.5),
                  size: w * 0.35,
                ),
              ),
            ),
            Positioned(
              bottom: h * 0.15,
              right: w * 0.1,
              child: Transform.rotate(
                angle: 0.5,
                child: Icon(
                  Icons.spa_rounded,
                  color: AppColors.parkGreen,
                  size: w * 0.25,
                ),
              ),
            ),

            // Boba Tea Cup Body
            Container(
              width: w * 0.5,
              height: h * 0.72,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                gradient: LinearGradient(
                  colors: [
                    AppColors.warmFulfillmentOrangeBg,
                    AppColors.coffeeBrown.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Milk Foam Layer on Top
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: h * 0.14,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  // Brand Logo 't' inside cup
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: h * 0.1),
                      child: Text(
                        't',
                        style: TextStyle(
                          color: brandColor.withValues(alpha: 0.5),
                          fontFamily: 'serif',
                          fontSize: w * 0.24,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                  // Boba Pearls at the Bottom
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(8, (index) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Boba Dome Lid
            Positioned(
              top: h * 0.1,
              child: Container(
                width: w * 0.52,
                height: h * 0.1,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // Diagonal Straw
            Positioned(
              top: h * 0.02,
              right: w * 0.32,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: w * 0.08,
                  height: h * 0.72,
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.3), width: 1),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
