import 'package:flutter/material.dart';

/// Spacing — base-8 with one half-step (xxs=4). Use these religiously.
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

  /// Outer page gutter — wider than Material default. Room to breathe.
  static const gutter = 28.0;
}

/// Two radii. Anything else is undisciplined.
class Radii {
  Radii._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
}

/// Three durations + one curve. Anything else is excess.
class Motion {
  Motion._();
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 380);

  /// Decisive acceleration, soft settle. The only curve this app uses.
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const exit = Curves.easeInCubic;
}
