import 'package:flutter/material.dart';

/// Spacing scale (base-8 with a couple of half-steps).
///
/// Use these instead of magic numbers — a consistent rhythm is what
/// separates polished UI from generic UI.
class Insets {
  Insets._();
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
}

class Radii {
  Radii._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class Motion {
  Motion._();
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 340);

  /// Apple-ish ease — quick acceleration, gentle settle.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const standard = Curves.easeOutCubic;
}
