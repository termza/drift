import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three vertical bars that wiggle. Used on the currently-playing track tile.
/// Pauses (freezes the bars) when [playing] is false.
class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({
    super.key,
    required this.playing,
    this.color,
    this.size = 14,
  });

  final bool playing;
  final Color? color;
  final double size;

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(PlayingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _BarsPainter(
              t: _c.value,
              color: color,
              frozen: !widget.playing,
            ),
          );
        },
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.t, required this.color, required this.frozen});
  final double t;
  final Color color;
  final bool frozen;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    const phases = [0.0, 0.33, 0.66];
    final gap = size.width * 0.12;
    final barW = (size.width - gap * 2) / 3;

    for (var i = 0; i < 3; i++) {
      final phase = phases[i];
      final raw = math.sin((t + phase) * 2 * math.pi);
      final norm = (raw + 1) / 2;
      final h = frozen
          ? size.height * 0.45
          : size.height * (0.25 + 0.65 * norm);
      final x = i * (barW + gap) + barW / 2;
      final yBottom = size.height;
      canvas.drawLine(
        Offset(x, yBottom),
        Offset(x, yBottom - h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.t != t || old.color != color || old.frozen != frozen;
}
