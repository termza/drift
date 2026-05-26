import 'package:flutter/material.dart';

import 'accent_palette.dart';

/// Global color palette. Mutable so the active theme (dark/light + accent) can
/// be applied app-wide without threading a Theme.of(context) lookup through
/// every widget.
///
/// Values are swapped by [apply] at theme-build time. Widgets that reference
/// these as plain field reads (e.g. `Container(color: AppColors.bg)`) pick up
/// the current values on each build. **Do not use these inside `const`
/// constructors** — the compiler will reject it. If you need a const color,
/// pull from the palette presets in `accent_palette.dart` or hard-code.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Active values — mutated by [apply].
  // ---------------------------------------------------------------------------

  static Color bg = _darkBg;
  static Color surface = _darkSurface;
  static Color surfaceElevated = _darkSurfaceElevated;
  static Color surfaceMuted = _darkSurfaceMuted;
  static Color surfaceTint = _darkSurfaceTint;

  static Color border = _darkBorder;
  static Color borderSubtle = _darkBorderSubtle;

  static Color textPrimary = _darkTextPrimary;
  static Color textSecondary = _darkTextSecondary;
  static Color textTertiary = _darkTextTertiary;

  static Color fillTertiary = _darkFillTertiary;
  static Color fillSecondary = _darkFillSecondary;

  static Color accent = const Color(0xFFE5A06B);
  static Color accentDeep = const Color(0xFFB6693A);
  static Color accentSoft = const Color(0xFF332217);
  static Color accentInk = const Color(0xFF1A0F05);

  /// Brightness of the currently-applied palette. Lets widgets cheaply branch
  /// for light/dark without doing a full Theme.of() lookup.
  static Brightness brightness = Brightness.dark;

  // Semantic — never themed.
  static const danger = Color(0xFFFF453A);

  // ---------------------------------------------------------------------------
  // Dark palette (iOS-style scale on pure-black bg).
  // ---------------------------------------------------------------------------

  static const _darkBg = Color(0xFF000000);
  static const _darkSurface = Color(0xFF1C1C1E);
  static const _darkSurfaceElevated = Color(0xFF2C2C2E);
  static const _darkSurfaceMuted = Color(0xFF1C1C1E);
  static const _darkSurfaceTint = Color(0xFF1A1A1A);
  static const _darkBorder = Color(0xFF38383A);
  static const _darkBorderSubtle = Color(0xFF2C2C2E);
  static const _darkTextPrimary = Color(0xFFFFFFFF);
  static const _darkTextSecondary = Color(0xFF98989F);
  static const _darkTextTertiary = Color(0xFF636366);
  static const _darkFillTertiary = Color(0xFF2C2C2E);
  static const _darkFillSecondary = Color(0xFF38383A);

  // ---------------------------------------------------------------------------
  // Light palette (Apple iOS grouped light).
  // ---------------------------------------------------------------------------

  static const _lightBg = Color(0xFFF2F2F7);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceElevated = Color(0xFFFFFFFF);
  static const _lightSurfaceMuted = Color(0xFFF2F2F7);
  static const _lightSurfaceTint = Color(0xFFFAFAFA);
  static const _lightBorder = Color(0xFFC6C6C8);
  static const _lightBorderSubtle = Color(0xFFE5E5EA);
  static const _lightTextPrimary = Color(0xFF000000);
  static const _lightTextSecondary = Color(0xFF6E6E73);
  static const _lightTextTertiary = Color(0xFFAEAEB2);
  static const _lightFillTertiary = Color(0xFFE5E5EA);
  static const _lightFillSecondary = Color(0xFFD1D1D6);

  // Light theme stub aliases kept for any external references that
  // hard-coded the old "lightBg" names.
  static const lightBg = _lightBg;
  static const lightSurface = _lightSurface;
  static const lightSurfaceElevated = _lightSurfaceElevated;
  static const lightBorder = _lightBorder;
  static const lightBorderSubtle = _lightBorderSubtle;
  static const lightTextPrimary = _lightTextPrimary;
  static const lightTextSecondary = _lightTextSecondary;
  static const lightTextTertiary = _lightTextTertiary;

  // ---------------------------------------------------------------------------
  // Apply
  // ---------------------------------------------------------------------------

  /// Swap the active palette. Called by `AppTheme.build` whenever the
  /// effective brightness or accent changes, so the next frame paints with
  /// the user's selection.
  static void apply({
    required Brightness brightness,
    required AccentPalette palette,
  }) {
    AppColors.brightness = brightness;
    if (brightness == Brightness.dark) {
      bg = _darkBg;
      surface = _darkSurface;
      surfaceElevated = _darkSurfaceElevated;
      surfaceMuted = _darkSurfaceMuted;
      surfaceTint = _darkSurfaceTint;
      border = _darkBorder;
      borderSubtle = _darkBorderSubtle;
      textPrimary = _darkTextPrimary;
      textSecondary = _darkTextSecondary;
      textTertiary = _darkTextTertiary;
      fillTertiary = _darkFillTertiary;
      fillSecondary = _darkFillSecondary;
    } else {
      bg = _lightBg;
      surface = _lightSurface;
      surfaceElevated = _lightSurfaceElevated;
      surfaceMuted = _lightSurfaceMuted;
      surfaceTint = _lightSurfaceTint;
      border = _lightBorder;
      borderSubtle = _lightBorderSubtle;
      textPrimary = _lightTextPrimary;
      textSecondary = _lightTextSecondary;
      textTertiary = _lightTextTertiary;
      fillTertiary = _lightFillTertiary;
      fillSecondary = _lightFillSecondary;
    }
    accent = palette.accent;
    accentDeep = palette.deep;
    accentSoft = palette.soft;
    accentInk = palette.ink;
  }
}
