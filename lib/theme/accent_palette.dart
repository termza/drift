import 'package:flutter/material.dart';

/// A complete accent palette derived from a single base color. The full set
/// of surface tints is computed via HSL math so a user-picked accent always
/// renders coherently (deep variant for secondary, soft variant for selected
/// chip backgrounds, ink variant for text-on-accent).
class AccentPalette {
  final Color accent;
  final Color deep;
  final Color soft;
  final Color ink;

  const AccentPalette({
    required this.accent,
    required this.deep,
    required this.soft,
    required this.ink,
  });

  /// Build a brightness-aware palette from a single base color.
  /// `soft` flips lightness with the theme so it reads as a tinted background
  /// in both light and dark modes.
  factory AccentPalette.from(Color base, Brightness brightness) {
    final hsl = HSLColor.fromColor(base);
    final isDark = brightness == Brightness.dark;
    return AccentPalette(
      accent: base,
      deep: hsl
          .withLightness(
            (hsl.lightness * (isDark ? 0.55 : 0.7)).clamp(0.05, 1.0),
          )
          .toColor(),
      soft: HSLColor.fromAHSL(
        1.0,
        hsl.hue,
        (hsl.saturation * 0.65).clamp(0.0, 1.0),
        isDark ? 0.13 : 0.93,
      ).toColor(),
      ink: HSLColor.fromAHSL(
        1.0,
        hsl.hue,
        (hsl.saturation * 0.85).clamp(0.0, 1.0),
        isDark ? 0.07 : 0.15,
      ).toColor(),
    );
  }
}

/// A named preset shown in the accent picker.
class AccentPreset {
  final String key;
  final String name;
  final Color color;
  const AccentPreset({
    required this.key,
    required this.name,
    required this.color,
  });
}

const kAccentPresets = <AccentPreset>[
  AccentPreset(key: 'copper', name: 'Copper', color: Color(0xFFE5A06B)),
  AccentPreset(key: 'amber', name: 'Amber', color: Color(0xFFFFB454)),
  AccentPreset(key: 'coral', name: 'Coral', color: Color(0xFFFF7D61)),
  AccentPreset(key: 'rose', name: 'Rose', color: Color(0xFFE68CA8)),
  AccentPreset(key: 'violet', name: 'Violet', color: Color(0xFF9D7CD8)),
  AccentPreset(key: 'indigo', name: 'Indigo', color: Color(0xFF7E92FF)),
  AccentPreset(key: 'teal', name: 'Teal', color: Color(0xFF5EBFC9)),
  AccentPreset(key: 'mint', name: 'Mint', color: Color(0xFF74D6B0)),
  AccentPreset(key: 'lime', name: 'Lime', color: Color(0xFFA8D670)),
  AccentPreset(key: 'slate', name: 'Slate', color: Color(0xFF8FA0B5)),
];

AccentPreset accentPresetByKey(String key) {
  for (final p in kAccentPresets) {
    if (p.key == key) return p;
  }
  return kAccentPresets.first;
}
