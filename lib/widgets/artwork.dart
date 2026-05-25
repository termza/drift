import 'dart:io';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Artwork — embedded album art when available, otherwise the copper vinyl
/// brand mark with a hue-tinted backdrop derived from the track id. Keeps the
/// library visually coherent even when ID3 tags don't include images.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.track,
    this.size = 48,
    this.borderRadius,
  });

  final Track? track;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.14);
    final art = track?.artworkPath;

    Widget child;
    if (art != null && File(art).existsSync()) {
      child = Image.file(
        File(art),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _BrandFallback(track: track, size: size),
      );
    } else {
      child = _BrandFallback(track: track, size: size);
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// Fallback: copper vinyl on a subtly hue-shifted backdrop so adjacent rows
/// don't feel identical. The vinyl sits slightly oversized and offset so it
/// reads as art, not as a logo placeholder.
class _BrandFallback extends StatelessWidget {
  const _BrandFallback({required this.track, required this.size});
  final Track? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Vary the backdrop slightly per track for visual rhythm.
    final seed = (track?.id ?? '').hashCode;
    final hue = (seed.abs() % 360).toDouble();
    final tint = HSLColor.fromAHSL(0.18, hue, 0.30, 0.20).toColor();

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(tint, AppColors.darkSurfaceElevated),
                AppColors.darkSurface,
              ],
            ),
          ),
        ),
        Transform.scale(
          scale: 1.12,
          child: Transform.translate(
            offset: Offset(size * 0.04, size * 0.04),
            child: Image.asset(
              'assets/brand_vinyl.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _LetterFallback(
                track: track,
                size: size,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Used only if the brand asset can't be loaded (dev-time before the user
/// drops the file in). Keeps the app from showing a broken image.
class _LetterFallback extends StatelessWidget {
  const _LetterFallback({required this.track, required this.size});
  final Track? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = (track?.title.trim().isNotEmpty ?? false)
        ? track!.title.trim()[0].toUpperCase()
        : '·';
    return Container(
      color: AppColors.darkSurfaceElevated,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.darkTextPrimary.withValues(alpha: 0.85),
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Standalone use of the brand mark — for empty states, splash, etc.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 88, this.glow = true});
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: glow
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    blurRadius: size * 0.6,
                    spreadRadius: -size * 0.1,
                  ),
                ],
              )
            : const BoxDecoration(),
        child: Image.asset(
          'assets/brand_vinyl.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.album_rounded,
            size: size * 0.7,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
