import 'package:flutter/material.dart';

/// Color palette for the app. Dark-first; light is a refined inversion.
///
/// The accent is a warm copper that reads as premium/audio-equipment-y without
/// being trendy. It pairs against near-black surfaces with subtle cool tints.
class AppColors {
  AppColors._();

  // Dark palette
  static const darkBg = Color(0xFF0A0A0C);
  static const darkSurface = Color(0xFF131318);
  static const darkSurfaceElevated = Color(0xFF1C1C23);
  static const darkSurfaceHigh = Color(0xFF26262F);
  static const darkBorder = Color(0xFF2A2A33);
  static const darkBorderSubtle = Color(0xFF1F1F27);

  static const darkTextPrimary = Color(0xFFF6F6F8);
  static const darkTextSecondary = Color(0xFF9A9AA3);
  static const darkTextTertiary = Color(0xFF5C5C66);

  // Light palette
  static const lightBg = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFF4F4F6);
  static const lightSurfaceHigh = Color(0xFFEDEDEF);
  static const lightBorder = Color(0xFFE4E4E8);
  static const lightBorderSubtle = Color(0xFFEEEEF1);

  static const lightTextPrimary = Color(0xFF111114);
  static const lightTextSecondary = Color(0xFF5B5B63);
  static const lightTextTertiary = Color(0xFF8E8E96);

  // Accent (shared)
  static const accent = Color(0xFFE5A06B);
  static const accentHover = Color(0xFFEEB281);
  static const accentMuted = Color(0xFF3A2C20);

  // Semantic
  static const danger = Color(0xFFE05D5D);
  static const success = Color(0xFF6FCF8E);
}
