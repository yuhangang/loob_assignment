import 'package:flutter/material.dart';

import 'brand.dart';
import 'tokens/colors.dart';
import 'tokens/typography.dart';
import 'tokens/spacing.dart';

/// Generates the full [ThemeData] for each [LoobBrand].
class AppTheme {
  AppTheme._();

  static ThemeData fromBrand(LoobBrand brand) {
    switch (brand) {
      case LoobBrand.discover:
        return _neutralTheme();
      case LoobBrand.tealive:
        return _tealiveTheme();
      case LoobBrand.baskbear:
        return _baskbearTheme();
    }
  }

  // ── Shared Component Theme Helpers ─────────────────────────────────────────

  static FilledButtonThemeData _filledButtonTheme(ColorScheme colors) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: const StadiumBorder(),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme colors) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.outline, width: 1.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: const StadiumBorder(),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(ColorScheme colors) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: const StadiumBorder(),
      ),
    );
  }

  static DialogThemeData _dialogTheme(ColorScheme colors) {
    return DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      titleTextStyle: AppTypography.titleLarge.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: colors.onSurface.withValues(alpha: 0.85),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme colors) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(color: colors.outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(color: colors.outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: colors.onSurface.withValues(alpha: 0.6),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: colors.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  static DividerThemeData _dividerTheme(ColorScheme colors) {
    return DividerThemeData(color: colors.outline, thickness: 1, space: 1);
  }

  // ── Neutral / Discover ────────────────────────────────────────────────────

  static ThemeData _neutralTheme() {
    final colors = ColorScheme.light(
      primary: const Color(0xFFB2C9AB),
      onPrimary: const Color(0xFF1E331A),
      primaryContainer: const Color(0xFFD3E2CC),
      onPrimaryContainer: const Color(0xFF0F1E0C),
      secondary: const Color(0xFFD4C1EC),
      onSecondary: const Color(0xFF2C194D),
      secondaryContainer: const Color(0xFFEDE6F8),
      onSecondaryContainer: const Color(0xFF160633),
      tertiary: const Color(0xFFF7E1AD),
      onTertiary: const Color(0xFF4C3806),
      tertiaryContainer: const Color(0xFFFBF1D6),
      onTertiaryContainer: const Color(0xFF261900),
      surface: const Color(0xFFF9FBF7),
      onSurface: const Color(0xFF1E211C),
      error: AppColors.error,
      onError: Colors.white,
      outline: const Color(0xFFE1E4DC),
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      brightness: Brightness.light,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.yamLightBackground,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: const BorderSide(color: Color(0xFFE1E4DC), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.yamLightBackground,
        foregroundColor: const Color(0xFF1E211C),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: const Color(0xFF1E211C),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.yamLightBackground,
        selectedItemColor: Color(0xFF5E7957),
        unselectedItemColor: Color(0xFF8C9388),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      filledButtonTheme: _filledButtonTheme(colors),
      outlinedButtonTheme: _outlinedButtonTheme(colors),
      textButtonTheme: _textButtonTheme(colors),
      dialogTheme: _dialogTheme(colors),
      inputDecorationTheme: _inputDecorationTheme(colors),
      dividerTheme: _dividerTheme(colors),
      textTheme: _textTheme(const Color(0xFF1E211C)),
      dividerColor: const Color(0xFFE1E4DC),
    );
  }

  // ── Tealive ───────────────────────────────────────────────────────────────

  static ThemeData _tealiveTheme() {
    final colors = ColorScheme.light(
      primary: AppColors.tealivePrimary,
      onPrimary: AppColors.tealiveOnPrimary,
      primaryContainer: AppColors.tealiveSurface,
      onPrimaryContainer: AppColors.tealivePrimary,
      secondary: AppColors.tealiveAccent,
      onSecondary: AppColors.tealivePrimary,
      secondaryContainer: AppColors.tealiveAccent.withValues(alpha: 0.1),
      onSecondaryContainer: AppColors.tealiveSecondary,
      surface: AppColors.tealiveSurface,
      onSurface: AppColors.tealivePrimary,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.tealivePrimary.withValues(alpha: 0.08),
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      brightness: Brightness.light,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.tealiveBackground,
      cardTheme: CardThemeData(
        color: AppColors.tealiveCard,
        elevation: 4,
        shadowColor: AppColors.tealivePrimary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.tealivePrimary,
        foregroundColor: AppColors.tealiveOnPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.tealiveOnPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.tealivePrimary,
        unselectedItemColor: AppColors.neutralSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.tealiveAccent,
        foregroundColor: AppColors.tealivePrimary,
      ),
      filledButtonTheme: _filledButtonTheme(colors),
      outlinedButtonTheme: _outlinedButtonTheme(colors),
      textButtonTheme: _textButtonTheme(colors),
      dialogTheme: _dialogTheme(colors),
      inputDecorationTheme: _inputDecorationTheme(colors),
      dividerTheme: _dividerTheme(colors),
      textTheme: _textTheme(AppColors.tealivePrimary),
      dividerColor: AppColors.tealivePrimary.withValues(alpha: 0.08),
    );
  }

  // ── Baskbear ──────────────────────────────────────────────────────────────

  static ThemeData _baskbearTheme() {
    final colors = ColorScheme.dark(
      primary: AppColors.baskbearAccent,
      onPrimary: AppColors.baskbearPrimary,
      primaryContainer: AppColors.baskbearSurface,
      onPrimaryContainer: AppColors.baskbearAccent,
      secondary: AppColors.baskbearAccent,
      onSecondary: AppColors.baskbearPrimary,
      secondaryContainer: AppColors.baskbearAccent.withValues(alpha: 0.1),
      onSecondaryContainer: AppColors.baskbearAccent,
      surface: AppColors.baskbearSurface,
      onSurface: AppColors.baskbearOnPrimary,
      error: AppColors.error,
      onError: Colors.white,
      outline: Colors.white12,
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.baskbearBackground,
      cardTheme: CardThemeData(
        color: AppColors.baskbearCard,
        elevation: 6,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.baskbearPrimary,
        foregroundColor: AppColors.baskbearOnPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.baskbearOnPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.baskbearPrimary,
        selectedItemColor: AppColors.baskbearAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.baskbearAccent,
        foregroundColor: AppColors.baskbearOnPrimary,
      ),
      filledButtonTheme: _filledButtonTheme(colors),
      outlinedButtonTheme: _outlinedButtonTheme(colors),
      textButtonTheme: _textButtonTheme(colors),
      dialogTheme: _dialogTheme(colors),
      inputDecorationTheme: _inputDecorationTheme(colors),
      dividerTheme: _dividerTheme(colors),
      textTheme: _textTheme(AppColors.baskbearOnPrimary),
      dividerColor: Colors.white12,
    );
  }

  // ── Shared text theme builder ─────────────────────────────────────────────

  static TextTheme _textTheme(Color defaultColor) {
    return TextTheme(
      headlineLarge: AppTypography.headlineLarge.copyWith(color: defaultColor),
      headlineMedium: AppTypography.headlineMedium.copyWith(
        color: defaultColor,
      ),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: defaultColor),
      titleLarge: AppTypography.titleLarge.copyWith(color: defaultColor),
      titleMedium: AppTypography.titleMedium.copyWith(color: defaultColor),
      titleSmall: AppTypography.titleSmall.copyWith(color: defaultColor),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: defaultColor),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: defaultColor),
      bodySmall: AppTypography.bodySmall.copyWith(color: defaultColor),
      labelLarge: AppTypography.labelLarge.copyWith(color: defaultColor),
      labelMedium: AppTypography.labelMedium.copyWith(color: defaultColor),
      labelSmall: AppTypography.labelSmall.copyWith(color: defaultColor),
    );
  }
}
