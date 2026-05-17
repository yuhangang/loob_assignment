import 'package:flutter/material.dart';

/// Curated color palettes for each brand and the neutral "Discover" mode.
class AppColors {
  AppColors._();

  // ── Yam Colors (Curated for Premium Aesthetic) ──────────────────────────────
  static const Color yamLightBackground = Color(0xFFF5ECF7); // Premium soft light yam
  static const Color yamDarkBackground = Color(0xFF130F17);  // Premium deep dark yam

  // ── Neutral / Discover ──────────────────────────────────────────────────────
  static const Color neutralPrimary = Color(0xFF111827); // Refined Off-Black
  static const Color neutralSecondary = Color(0xFF6B7280);
  static const Color neutralSurface = Color(0xFFF9FAFB); // Softer Off-White
  static const Color neutralBackground = yamLightBackground;
  static const Color neutralCard = Color(0xFFFFFFFF);
  static const Color neutralDivider = Color(0xFFF3F4F6); // Lighter Divider
  static const Color neutralAccent = Color(0xFF3B82F6); // Vibrant Blue

  // ── Tealive ─────────────────────────────────────────────────────────────────
  static const Color tealivePrimary = Color(0xFF4C1D40); // Deep Rich Purple
  static const Color tealiveSecondary = Color(0xFF7A3369);
  static const Color tealiveSurface = Color(0xFFFDF8FB);
  static const Color tealiveBackground = yamLightBackground;
  static const Color tealiveCard = Color(0xFFFFFFFF);
  static const Color tealiveAccent = Color(0xFFFFC107); // Vibrant Gold/Yellow
  static const Color tealiveOnPrimary = Color(0xFFFFFFFF);

  // ── Baskbear ────────────────────────────────────────────────────────────────
  static const Color baskbearPrimary = Color(0xFF0A0A0A); // True Deep Black
  static const Color baskbearSecondary = Color(0xFF262626);
  static const Color baskbearSurface = Color(0xFF171717); // Sleeker Surface
  static const Color baskbearBackground = yamDarkBackground;
  static const Color baskbearCard = Color(0xFF171717); // Smooth Dark Card
  static const Color baskbearAccent = Color(0xFFFF5A00); // High-Pop Orange
  static const Color baskbearOnPrimary = Color(0xFFFFFFFF);

  // ── Shared ──────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}
