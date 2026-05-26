import 'dart:io';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_colors.dart';

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
    final radius = borderRadius ?? BorderRadius.circular(size * 0.10);
    final art = track?.artworkPath;

    Widget child;
    if (art != null && File(art).existsSync()) {
      child = Image.file(
        File(art),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _BrandFallback(),
      );
    } else {
      child = const _BrandFallback();
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _BrandFallback extends StatelessWidget {
  const _BrandFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/brand_vinyl.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.album_outlined,
          color: AppColors.accent,
          size: 22,
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96, this.glow = false});
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
                    blurRadius: size * 0.5,
                    spreadRadius: -size * 0.06,
                  ),
                ],
              )
            : const BoxDecoration(),
        child: Image.asset(
          'assets/brand_vinyl.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.album_outlined,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
