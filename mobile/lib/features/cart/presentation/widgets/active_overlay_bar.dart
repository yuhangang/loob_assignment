import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../vouchers/presentation/voucher_wallet_page.dart';
import '../../data/models/order_status_model.dart';
import '../bloc/cart_state.dart';

/// Glassmorphic active overlay bar rendered as a global overlay above all screens.
///
/// Handles both active uncollected/unpaid orders and active shopping cart states.
/// Automatically hides itself when the current route is in checkout or status page.
class ActiveOverlayBar extends StatelessWidget {
  final CartState cartState;
  final OrderStatusModel? activeOrder;

  const ActiveOverlayBar({super.key, required this.cartState, this.activeOrder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppRouter.isDialogOpenNotifier,
      builder: (context, isDialogOpen, _) {
        if (isDialogOpen) {
          return const IgnorePointer(ignoring: true, child: SizedBox.shrink());
        }
        return ValueListenableBuilder<String?>(
          valueListenable: AppRouter.currentRouteNotifier,
          builder: (context, currentRoute, child) {
            if (currentRoute == AppRouter.cart ||
                currentRoute == AppRouter.checkout ||
                currentRoute == AppRouter.orderStatus ||
                currentRoute == AppRouter.barcode ||
                currentRoute == AppRouter.productDetail ||
                currentRoute == AppRouter.selectOutlet) {
              return const IgnorePointer(
                ignoring: true,
                child: SizedBox.shrink(),
              );
            }

            final theme = Theme.of(context);
            final showVoucherButton = currentRoute != AppRouter.vouchers;
            final showCartBar = cartState.totalQuantity > 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (activeOrder != null) ...[
                  _buildActiveOrderBar(context, theme, activeOrder!),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (showVoucherButton && showCartBar) ...[
                  _buildVoucherButton(context, theme),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (showCartBar) _buildBar(context, theme),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVoucherButton(BuildContext context, ThemeData theme) {
    return BlocBuilder<VoucherCubit, VoucherState>(
      builder: (context, state) {
        int count = 0;
        if (state is VoucherLoaded) {
          count = state.vouchers.where((v) => v.status == 'AVAILABLE').length;
        }

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: () {
                    context.push(AppRouter.vouchers);
                  },
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surface.withValues(alpha: 0.85)
                          : AppColors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number_rounded,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'My Vouchers',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                            ),
                            child: Text(
                              '$count',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBar(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: () {
                context.push(AppRouter.cart);
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surface.withValues(alpha: 0.85)
                      : AppColors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Bag icon with quantity badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm + 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            color: theme.colorScheme.primary,
                            size: 26,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.surface
                                    : AppColors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Center(
                              child: Text(
                                '${cartState.totalQuantity}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Price info + unavailability warning
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.myCart,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          if (cartState.hasUnavailableItems)
                            Text(
                              'Some items unavailable',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            )
                          else if (cartState.hasUnavailableOptions)
                            Text(
                              context.l10n.someOptionsUnavailable,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textFulfillmentOrange,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            )
                          else
                            Text(
                              cartState.totalPrice.toDisplayPrice(
                                cartState.currency,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // "View Cart" CTA
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg + 2,
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        context.push(AppRouter.cart);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.cart,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12),
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
    );
  }

  Widget _buildActiveOrderBar(
    BuildContext context,
    ThemeData theme,
    OrderStatusModel activeOrder,
  ) {
    final isUnpaid =
        activeOrder.status.toUpperCase() == 'PENDING' ||
        activeOrder.status.toUpperCase() == 'PAYMENT_PENDING' ||
        activeOrder.paymentStatus.toUpperCase() == 'PENDING';

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: () {
                context.push(
                  AppRouter.orderStatus,
                  extra: {'trackingId': activeOrder.orderTrackingId},
                );
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surface.withValues(alpha: 0.85)
                      : AppColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Watermark background icon with low opacity
                    Positioned(
                      left: -8,
                      top: -12,
                      bottom: -12,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.07,
                          child: Icon(
                            activeOrder.status.toUpperCase() == 'READY' ||
                                    activeOrder.status.toUpperCase() ==
                                        'READY_TO_COLLECT'
                                ? Icons.check_circle_rounded
                                : isUnpaid
                                ? Icons.payment_rounded
                                : Icons.hourglass_top_rounded,
                            color: theme.colorScheme.primary,
                            size: 80,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        // Order Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isUnpaid
                                    ? context.l10n.unpaidOrder
                                    : context.l10n.uncollectedOrder,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeOrder.orderTrackingId,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeOrder.status.toUpperCase() == 'READY' ||
                                        activeOrder.status.toUpperCase() ==
                                            'READY_TO_COLLECT'
                                    ? context.l10n.readyForCollection
                                    : isUnpaid
                                    ? context.l10n.awaitingPayment
                                    : context.l10n.preparingOrder,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // CTA Button
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            context.push(
                              AppRouter.orderStatus,
                              extra: {
                                'trackingId': activeOrder.orderTrackingId,
                              },
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isUnpaid
                                    ? context.l10n.payNow
                                    : context.l10n.track,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                isUnpaid
                                    ? Icons.payment_rounded
                                    : Icons.radar_rounded,
                                size: 14,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
