import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../bloc/cart_state.dart';
import '../bloc/checkout_state.dart';

class CheckoutFloatingButton extends StatelessWidget {
  final CartState cart;
  final CheckoutState state;
  final VoidCallback? onCheckoutPressed;

  const CheckoutFloatingButton({
    super.key,
    required this.cart,
    required this.state,
    required this.onCheckoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final methods = state.methods
        .where((method) => state.getSubtotal(cart) >= method.minAmount)
        .toList(growable: false);
    final estimatedDiscount = state.currentVoucherDiscount(
      state.getSubtotal(cart),
    );
    final estimatedPayable = (state.getSubtotal(cart) - estimatedDiscount)
        .clamp(0, state.getSubtotal(cart));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.totalAmount,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      estimatedPayable.toDisplayPrice(cart.currency),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      state.isCheckingOut ||
                          state.isLoadingMethods ||
                          methods.isEmpty ||
                          cart.isSelectedStoreClosed
                      ? null
                      : onCheckoutPressed,
                  icon: state.isCheckingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    state.isCheckingOut
                        ? context.l10n.placingOrder
                        : context.l10n.placeOrder,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
