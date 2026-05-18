import 'package:flutter/material.dart';

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
}
