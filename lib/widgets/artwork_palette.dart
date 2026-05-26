import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../models/track.dart';
import '../theme/app_colors.dart';

/// Two dominant tones extracted from a track's artwork, used to paint
/// gradient backdrops. Falls back to the accent + background when no usable
/// palette can be computed (e.g. brand vinyl fallback).
class ArtworkPalette {
  const ArtworkPalette({required this.top, required this.bottom});
  final Color top;
  final Color bottom;

  // Hardcoded fallback colors — this is `static const` and AppColors values
  // are now runtime-mutable, so the bottom can't reference AppColors.bg.
  static const fallback = ArtworkPalette(
    top: Color(0xFF2A1F18),
    bottom: Color(0xFF000000),
  );
}

/// Per-track palette. Cached by track id so we don't re-scan the same image.
final artworkPaletteProvider =
    FutureProviderFamily<ArtworkPalette, Track?>((ref, track) async {
  if (track == null) return ArtworkPalette.fallback;
  final art = track.artworkPath;
  if (art == null || !File(art).existsSync()) {
    return ArtworkPalette.fallback;
  }

  try {
    final palette = await PaletteGenerator.fromImageProvider(
      FileImage(File(art)),
      size: const Size(120, 120),
      maximumColorCount: 8,
    );

    final primary = palette.darkVibrantColor?.color ??
        palette.darkMutedColor?.color ??
        palette.vibrantColor?.color ??
        palette.dominantColor?.color;

    if (primary == null) return ArtworkPalette.fallback;

    // Deepen toward black at the bottom so the gradient ends in our app bg.
    final top = _saturateDarken(primary, 0.4);
    return ArtworkPalette(top: top, bottom: AppColors.bg);
    // (Above is a non-const ctor call — AppColors.bg is fine here.)
  } catch (_) {
    return ArtworkPalette.fallback;
  }
});

/// Pull a color toward dark — keeps the gradient understated. We don't want
/// every now-playing screen looking like a fluorescent club.
Color _saturateDarken(Color c, double t) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness * (1 - t)).clamp(0.1, 0.5))
      .withSaturation((hsl.saturation * 1.1).clamp(0.3, 0.85))
      .toColor();
}
