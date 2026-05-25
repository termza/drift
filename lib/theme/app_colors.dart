import 'package:flutter/material.dart';

/// Apple-Music-inspired dark palette. Pure black background (looks great on
/// OLED, premium feel), iOS dark gray grouped surfaces, white ink, our copper
/// kept as the signature accent.
class AppColors {
  AppColors._();

  // Surfaces — Apple's iOS dark mode scale
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E);
  static const surfaceElevated = Color(0xFF2C2C2E);
  static const surfaceMuted = Color(0xFF1C1C1E);
  static const surfaceTint = Color(0xFF1A1A1A);

  // Hairlines
  static const border = Color(0xFF38383A);
  static const borderSubtle = Color(0xFF2C2C2E);

  // Ink — white scaling down
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF98989F);
  static const textTertiary = Color(0xFF636366);

  // Copper accent — original brand color pops against pure black
  static const accent = Color(0xFFE5A06B);
  static const accentDeep = Color(0xFFB6693A);
  static const accentSoft = Color(0xFF332217);
  static const accentInk = Color(0xFF1A0F05);

  // Apple's systemGray fills for chips/pills
  static const fillTertiary = Color(0xFF2C2C2E);
  static const fillSecondary = Color(0xFF38383A);

  // Light theme stub (kept for completeness — primary is dark)
  static const lightBg = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFF2F2F7);
  static const lightBorder = Color(0xFFE5E5EA);
  static const lightBorderSubtle = Color(0xFFEEEEF0);
  static const lightTextPrimary = Color(0xFF000000);
  static const lightTextSecondary = Color(0xFF6E6E73);
  static const lightTextTertiary = Color(0xFFAEAEB2);

  // Semantic
  static const danger = Color(0xFFFF453A);
}
