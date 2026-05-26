import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted-glass container — `bg-white/[0.02]` + `backdrop-blur-xl` +
/// hairline `border-white/[0.06]`, translated to Flutter.
///
/// Use this for **static** surfaces (sidebar, settings cards, the Continue
/// card). **Do not** wrap each item in a long scrolling list — every visible
/// glass panel re-runs the backdrop blur on every frame and tanks frame time.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.tintAlpha = 0.02,
    this.borderAlpha = 0.06,
    this.blurSigma = 24,
    this.borderWidth = 0.5,
    this.fallbackColor,
    this.enableBlur = true,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double tintAlpha;
  final double borderAlpha;
  final double blurSigma;
  final double borderWidth;

  /// Solid color shown when `enableBlur == false` (cheaper fallback for
  /// per-item rendering). Defaults to a low-alpha surface.
  final Color? fallbackColor;

  /// Set to false to skip the backdrop blur and render a flat tinted panel —
  /// way cheaper for many simultaneous instances.
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final isDark = AppColors.brightness == Brightness.dark;
    final tint = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: tintAlpha);
    final border = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: borderAlpha);

    final inner = Container(
      decoration: BoxDecoration(
        color: enableBlur ? tint : (fallbackColor ?? AppColors.surface),
        borderRadius: radius,
        border: Border.all(color: border, width: borderWidth),
      ),
      padding: padding,
      child: child,
    );

    if (!enableBlur) {
      return ClipRRect(
        borderRadius: radius,
        child: inner,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: inner,
      ),
    );
  }
}
