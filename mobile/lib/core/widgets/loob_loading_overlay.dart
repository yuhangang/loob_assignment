import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/tokens/colors.dart';
import '../theme/tokens/spacing.dart';
import 'loob_spinner.dart';

/// A premium, full-screen glassmorphic loading overlay.
/// Prevents user interaction, blurs the background, and displays a brand loader.
class LoobLoadingOverlay extends StatelessWidget {
  final String? message;

  const LoobLoadingOverlay({super.key, this.message});

  static bool _isShowing = false;
  static Route<dynamic>? _currentRoute;

  /// Display the loading overlay. Keeps track of state to prevent multiple overlays.
  static void show(BuildContext context, {String? message}) {
    if (_isShowing) return;
    _isShowing = true;

    _currentRoute = DialogRoute(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.25),
      useSafeArea: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: LoobLoadingOverlay(message: message),
        );
      },
    );

    Navigator.of(context, rootNavigator: true).push(_currentRoute!);
  }

  /// Hide the loading overlay if it is currently displayed.
  static void hide() {
    if (!_isShowing) return;
    _isShowing = false;

    if (_currentRoute != null) {
      final route = _currentRoute!;
      _currentRoute = null;

      if (route.navigator != null) {
        try {
          if (route.isCurrent) {
            route.navigator!.pop();
          } else {
            route.navigator!.removeRoute(route);
          }
        } catch (_) {
          // Safely ignore any exceptions during removal/pop
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: AppColors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Glassmorphic background blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color: isDark
                    ? AppColors.black.withValues(alpha: 0.35)
                    : AppColors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          // Center Loader card
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl * 1.5,
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.grey900.withValues(alpha: 0.9)
                    : AppColors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: isDark
                      ? AppColors.white.withValues(alpha: 0.08)
                      : AppColors.black.withValues(alpha: 0.04),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.18),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LoobSpinner(size: 64),
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.white : AppColors.grey800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
