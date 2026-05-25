import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.dark);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    const bg = AppColors.bg;
    const surface = AppColors.surface;
    const surfaceElevated = AppColors.surfaceElevated;
    const border = AppColors.border;
    const borderSubtle = AppColors.borderSubtle;
    const textPrimary = AppColors.textPrimary;
    const textSecondary = AppColors.textSecondary;
    const textTertiary = AppColors.textTertiary;

    // Apple-Music-like type scale. SF Pro substitute: Inter, with the
    // heavier weights doing the hierarchy work. Sentence case, no all-caps.
    final base = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    final textTheme = base.copyWith(
      // Hero / page title — Apple's iOS "Large Title" feel
      displayLarge: base.displayLarge?.copyWith(
        color: textPrimary,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.1,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: AppColors.accentInk,
      secondary: AppColors.accentDeep,
      onSecondary: AppColors.accentInk,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceElevated,
      outline: border,
      outlineVariant: borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: textPrimary, size: 22),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: AppColors.fillTertiary,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          highlightColor: textPrimary.withValues(alpha: 0.03),
          hoverColor: textPrimary.withValues(alpha: 0.03),
          focusColor: textPrimary.withValues(alpha: 0.05),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fillTertiary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: 12,
        ),
        hintStyle: const TextStyle(
          color: textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
          borderSide:
              BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary.withValues(alpha: 0.92),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          textTertiary.withValues(alpha: 0.5),
        ),
        thickness: const WidgetStatePropertyAll(3),
        radius: const Radius.circular(1.5),
        crossAxisMargin: 2,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: 6,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: Color(0x66000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
        ),
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }
}
