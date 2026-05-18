import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../bloc/cart_state.dart';

/// A premium, glassmorphic checkout panel pinned to the bottom of the Cart screen.
class StickyCheckoutPanel extends StatelessWidget {
  final CartState state;

  const StickyCheckoutPanel({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.scaffoldBackgroundColor.withValues(alpha: 0.85)
                : AppColors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
            AppSpacing.pageHorizontal,
            AppSpacing.xl,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.subtotalLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.textTheme.titleMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      state.totalPrice.toDisplayPrice(state.currency),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          state.hasUnavailableItems ||
                                  state.isSelectedStoreClosed
                              ? theme.colorScheme.error.withValues(alpha: 0.3)
                              : theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXl,
                        ),
                      ),
                      elevation: 0,
                    ),
                    onPressed: state.hasUnavailableItems ||
                            state.isSelectedStoreClosed
                        ? null
                        : () {
                            context.push(AppRouter.checkout);
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.hasUnavailableItems
                              ? context.l10n.removeUnavailableItems
                              : state.isSelectedStoreClosed
                                  ? context.l10n.selectedOutletClosed
                                  : context.l10n.proceedToCheckout,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (!state.hasUnavailableItems &&
                            !state.isSelectedStoreClosed) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
