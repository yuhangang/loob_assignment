import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/cart/presentation/bloc/cart_bloc.dart';
import '../router/app_router.dart';

/// Useful Dart/Flutter extensions.

extension StringExtensions on String {
  /// Capitalize the first letter.
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension StringCurrencyExtension on String {
  /// Convert currency code to its symbol (e.g. 'MYR' -> 'RM', 'THB' -> '฿').
  String get currencySymbol {
    switch (toUpperCase()) {
      case 'MYR':
        return 'RM';
      case 'THB':
        return '฿';
      case 'VND':
        return '₫';
      default:
        return this;
    }
  }
}

extension IntCurrencyExtension on int {
  /// Format an integer amount (in smallest currency unit) to display string.
  ///
  /// Example: `1250.toDisplayPrice('MYR')` → `'RM 12.50'`
  String toDisplayPrice(String currencyCode) {
    final sign = this < 0 ? '-' : '';
    final absolute = abs();
    final major = absolute ~/ 100;
    final minor = absolute % 100;
    final symbol = currencyCode.currencySymbol;
    return '$sign$symbol $major.${minor.toString().padLeft(2, '0')}';
  }
}

extension ContextExtensions on BuildContext {
  /// Shortcut to the current theme's color scheme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Shortcut to the current text theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Show a consistent custom snackbar for simulated actions.
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Returns the dynamic bottom padding needed to clear the floating cart bar.
  /// Returns 0.0 if the cart bar is hidden on the current route or if the cart is empty.
  /// Otherwise, returns 140.0 + bottom safe area to clear the floating cart bar comfortably.
  double get cartFloatingBarPadding {
    // 1. Check if the current route is one that hides the floating cart bar.
    final currentRoute = AppRouter.currentRouteNotifier.value;
    if (currentRoute == AppRouter.cart ||
        currentRoute == AppRouter.checkout ||
        currentRoute == AppRouter.orderStatus ||
        currentRoute == AppRouter.barcode ||
        currentRoute == AppRouter.productDetail) {
      return 0.0;
    }

    // 2. Check if the cart has items. Watches the CartBloc state reactively.
    final cartState = watch<CartBloc>().state;
    if (cartState.totalQuantity == 0) {
      return 0.0;
    }

    // 3. Floating cart bar is visible.
    // Base overlap height is 140.0. Add bottom safe area (e.g. notch height)
    // to guarantee sufficient clearance on all device screen sizes.
    final bottomSafeArea = MediaQuery.of(this).padding.bottom;
    return 140.0 + bottomSafeArea;
  }
}

