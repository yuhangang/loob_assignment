/// Spatial design tokens using an 4px base grid.
///
/// All padding, margin, and gap values should reference these constants
/// to keep the layout consistent and predictable.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  /// Default page horizontal padding.
  static const double pageHorizontal = 16.0;

  /// Default page vertical padding.
  static const double pageVertical = 24.0;

  /// Card inner padding.
  static const double cardPadding = 16.0;

  /// Standard border radius for cards and buttons.
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;
}
