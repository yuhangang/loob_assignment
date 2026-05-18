import 'package:flutter/material.dart';

/// Curated color palettes for each brand and the neutral "Discover" mode.
class AppColors {
  AppColors._();

  // ── Basic Colors ───────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);
  static const Color white30 = Color(0x4DFFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color white60 = Color(0x99FFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // ── Gray Shades ────────────────────────────────────────────────────────────
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // ── Black Opacity Equivalents ──────────────────────────────────────────────
  static const Color black12 = Color(0x1F000000);
  static const Color black26 = Color(0x42000000);
  static const Color black38 = Color(0x61000000);
  static const Color black45 = Color(0x73000000);
  static const Color black54 = Color(0x8A000000);
  static const Color black87 = Color(0xDD000000);

  // ── Yam Colors (Curated for Premium Aesthetic) ──────────────────────────────
  static const Color yamLightBackground = Color(
    0xFFF5ECF7,
  ); // Premium soft light yam
  static const Color yamDarkBackground = Color(
    0xFF130F17,
  ); // Premium deep dark yam

  // ── Neutral / Discover ──────────────────────────────────────────────────────
  static const Color neutralPrimary = Color(0xFF111827); // Refined Off-Black
  static const Color neutralSecondary = Color(0xFF6B7280);
  static const Color neutralSurface = Color(0xFFF9FAFB); // Softer Off-White
  static const Color neutralBackground = yamLightBackground;
  static const Color neutralCard = Color(0xFFFFFFFF);
  static const Color neutralDivider = Color(0xFFF3F4F6); // Lighter Divider
  static const Color neutralAccent = Color(0xFF3B82F6); // Vibrant Blue

  // ── Discover Mode Brand Theme Specifics ────────────────────────────────────
  static const Color discoverPrimary = Color(0xFFB2C9AB);
  static const Color discoverOnPrimary = Color(0xFF1E331A);
  static const Color discoverPrimaryContainer = Color(0xFFD3E2CC);
  static const Color discoverOnPrimaryContainer = Color(0xFF0F1E0C);
  static const Color discoverSecondary = Color(0xFFD4C1EC);
  static const Color discoverOnSecondary = Color(0xFF2C194D);
  static const Color discoverSecondaryContainer = Color(0xFFEDE6F8);
  static const Color discoverOnSecondaryContainer = Color(0xFF160633);
  static const Color discoverTertiary = Color(0xFFF7E1AD);
  static const Color discoverOnTertiary = Color(0xFF4C3806);
  static const Color discoverTertiaryContainer = Color(0xFFFBF1D6);
  static const Color discoverOnTertiaryContainer = Color(0xFF261900);
  static const Color discoverSurface = Color(0xFFF9FBF7);
  static const Color discoverOnSurface = Color(0xFF1E211C);
  static const Color discoverDivider = Color(0xFFE1E4DC);
  static const Color discoverSelectedNav = Color(0xFF5E7957);
  static const Color discoverUnselectedNav = Color(0xFF8C9388);

  static const Color discoverGreen = Color(0xFF2E4A1F);

  // ── Tealive ─────────────────────────────────────────────────────────────────
  static const Color tealivePrimary = Color(0xFF4C1D40); // Deep Rich Purple
  static const Color tealiveSecondary = Color(0xFF7A3369);
  static const Color tealiveSurface = Color(0xFFFDF8FB);
  static const Color tealiveBackground = yamLightBackground;
  static const Color tealiveCard = Color(0xFFFFFFFF);
  static const Color tealiveAccent = Color(0xFFFFC107); // Vibrant Gold/Yellow
  static const Color tealiveOnPrimary = Color(0xFFFFFFFF);
  static const Color tealiveWarmCream = Color(0xFFFEF7EE);

  // ── Baskbear ────────────────────────────────────────────────────────────────
  static const Color baskbearPrimary = Color(0xFF0A0A0A); // True Deep Black
  static const Color baskbearSecondary = Color(0xFF262626);
  static const Color baskbearSurface = Color(0xFF171717); // Sleeker Surface
  static const Color baskbearBackground = yamDarkBackground;
  static const Color baskbearCard = Color(0xFF171717); // Smooth Dark Card
  static const Color baskbearAccent = Color(0xFFFF5A00); // High-Pop Orange
  static const Color baskbearOnPrimary = Color(0xFFFFFFFF);
  static const Color baskbearWarmCream = Color(0xFFFAF2E8);

  // ── Shared ──────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Shared UI Specifics (Extracted) ──────────────────────────────────────────
  static const Color lightLavender = Color(0xFFF1EEF5);
  static const Color darkSlate = Color(0xFF1A1A2E);
  static const Color dividerBeige = Color(0xFFF3E7DC);
  static const Color softWhiteBg = Color(0xFFFAF9F6);
  static const Color softPink = Color(0xFFE28BB9);

  // ── Maps / Custom Painting (Outlet Page) ────────────────────────────────────
  static const Color waterBlue = Color(0xFFE5F1F6);
  static const Color warmCream = Color(0xFFF2F4F3);
  static const Color parkGreen = Color(0xFFD5ECD4);
  static const Color roadGrey = Color(0xFFD4DAD9);
  static const Color signalBlue = Color(0xFF2E86DE);
  static const Color coffeeBrown = Color(0xFF8B4513);

  // ── Fulfillment Cards & Dashboard Badges ────────────────────────────────────
  static const Color warmFulfillmentGreenBg = Color(0xFFE2F0D9);
  static const Color lightFulfillmentGreenBg = Color(0xFFF2F9EE);
  static const Color borderFulfillmentGreen = Color(0xFFC5E0B4);
  static const Color textFulfillmentGreen = Color(0xFF385723);
  static const Color warmFulfillmentOrangeBg = Color(0xFFFFF2CC);
  static const Color lightFulfillmentOrangeBg = Color(0xFFFFF9E6);
  static const Color borderFulfillmentOrange = Color(0xFFF8CBAD);
  static const Color textFulfillmentOrange = Color(0xFFC65911);
}
