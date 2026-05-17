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
    final major = this ~/ 100;
    final minor = this % 100;
    final symbol = currencyCode.currencySymbol;
    return '$symbol $major.${minor.toString().padLeft(2, '0')}';
  }
}

extension ContextExtensions on BuildContext {
  /// Shortcut to the current theme's color scheme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Shortcut to the current text theme.
  TextTheme get textTheme => Theme.of(this).textTheme;
}
