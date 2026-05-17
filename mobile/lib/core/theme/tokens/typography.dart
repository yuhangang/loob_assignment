import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale matching the mobile architecture spec.
///
/// Uses premium Google Font (Outfit) for an elegant look.
class AppTypography {
  AppTypography._();

  // ── Headline ────────────────────────────────────────────────────────────────
  static final TextStyle headlineLarge = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static final TextStyle headlineMedium = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static final TextStyle headlineSmall = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // ── Title ───────────────────────────────────────────────────────────────────
  static final TextStyle titleLarge = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static final TextStyle titleMedium = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static final TextStyle titleSmall = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ── Body ────────────────────────────────────────────────────────────────────
  static final TextStyle bodyLarge = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static final TextStyle bodyMedium = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static final TextStyle bodySmall = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── Label ───────────────────────────────────────────────────────────────────
  static final TextStyle labelLarge = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static final TextStyle labelMedium = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static final TextStyle labelSmall = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.3,
  );

  // ── Price ───────────────────────────────────────────────────────────────────
  static final TextStyle priceLarge = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static final TextStyle priceMedium = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
