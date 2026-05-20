import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/widgets/loob_skeleton.dart';

class MenuLoadingSkeleton extends StatelessWidget {
  final Color primaryColor;

  const MenuLoadingSkeleton({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Sidebar Skeletons
        Container(
          width: 72,
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              right: BorderSide(
                color: AppColors.dividerBeige,
                width: 1,
              ),
            ),
          ),
          child: ListView.builder(
            itemCount: 6,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  children: [
                    LoobSkeleton(
                      width: 44,
                      height: 44,
                      borderRadius: AppSpacing.radiusXl,
                    ),
                    const SizedBox(height: 6),
                    LoobSkeleton(
                      width: 48,
                      height: 10,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Right side content skeleton
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header mockup skeleton
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LoobSkeleton(width: 80, height: 16),
                        LoobSkeleton(width: 32, height: 32, borderRadius: AppSpacing.radiusFull),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LoobSkeleton(width: 160, height: 22),
                    const SizedBox(height: 4),
                    LoobSkeleton(width: 220, height: 14),
                    const SizedBox(height: AppSpacing.md),
                    // fulfillment toggle mock
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: LoobSkeleton(width: 60, height: 14),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: LoobSkeleton(width: 60, height: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Chips mock skeleton
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    LoobSkeleton(width: 72, height: 28, borderRadius: AppSpacing.radiusFull),
                    const SizedBox(width: 8),
                    LoobSkeleton(width: 72, height: 28, borderRadius: AppSpacing.radiusFull),
                    const SizedBox(width: 8),
                    LoobSkeleton(width: 72, height: 28, borderRadius: AppSpacing.radiusFull),
                  ],
                ),
              ),

              // Product grid mock skeleton
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(
                            color: AppColors.grey200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Center(
                                child: LoobSkeleton(
                                  width: double.infinity,
                                  height: double.infinity,
                                  borderRadius: AppSpacing.radiusMd,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            LoobSkeleton(width: 100, height: 14),
                            const SizedBox(height: 6),
                            LoobSkeleton(width: 70, height: 10),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                LoobSkeleton(width: 48, height: 16),
                                LoobSkeleton(
                                  width: 28,
                                  height: 28,
                                  borderRadius: AppSpacing.radiusFull,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
