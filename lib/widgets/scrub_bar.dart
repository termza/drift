import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Custom scrub bar — thinner track than the default Material slider, with a
/// thumb that grows on press and a subtle accent on the buffered portion.
///
/// Built on [GestureDetector] + [CustomPaint] rather than [Slider] so we have
/// full control over the visual.
class ScrubBar extends StatefulWidget {
  const ScrubBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<ScrubBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _thumb;
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    _thumb = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _thumb.dispose();
    super.dispose();
  }

  double get _fraction {
    if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
    final total = widget.duration.inMilliseconds;
    if (total == 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _onDown(DragDownDetails d, double width) {
    _thumb.forward();
    setState(() => _dragFraction = d.localPosition.dx / width);
  }

  void _onUpdate(DragUpdateDetails d, double width) {
    setState(() => _dragFraction = (d.localPosition.dx / width).clamp(0.0, 1.0));
  }

  void _onEnd() {
    if (_dragFraction != null) {
      final ms = (widget.duration.inMilliseconds * _dragFraction!).round();
      widget.onSeek(Duration(milliseconds: ms));
    }
    _thumb.reverse();
    setState(() => _dragFraction = null);
  }

  void _onTap(TapUpDetails d, double width) {
    final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
    final ms = (widget.duration.inMilliseconds * f).round();
    widget.onSeek(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, c) {
        return SizedBox(
          height: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (d) => _onDown(
              DragDownDetails(localPosition: d.localPosition),
              c.maxWidth,
            ),
            onHorizontalDragUpdate: (d) => _onUpdate(d, c.maxWidth),
            onHorizontalDragEnd: (_) => _onEnd(),
            onHorizontalDragCancel: _onEnd,
            onTapUp: (d) => _onTap(d, c.maxWidth),
            child: AnimatedBuilder(
              animation: _thumb,
              builder: (context, _) => CustomPaint(
                size: Size(c.maxWidth, 28),
                painter: _ScrubPainter(
                  fraction: _fraction,
                  trackColor: track,
                  activeColor: AppColors.accent,
                  thumbScale: 1 + _thumb.value * 0.6,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScrubPainter extends CustomPainter {
  _ScrubPainter({
    required this.fraction,
    required this.trackColor,
    required this.activeColor,
    required this.thumbScale,
  });

  final double fraction;
  final Color trackColor;
  final Color activeColor;
  final double thumbScale;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final left = const Offset(0, 0);
    final right = Offset(size.width, 0);
    final trackY = y;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(left.dx, trackY),
      Offset(right.dx, trackY),
      trackPaint,
    );

    final activeEnd = size.width * fraction;
    if (activeEnd > 0) {
      canvas.drawLine(
        Offset(0, trackY),
        Offset(activeEnd, trackY),
        activePaint,
      );
    }

    // Thumb
    final thumbPaint = Paint()..color = activeColor;
    final r = 5.0 * thumbScale;
    canvas.drawCircle(Offset(activeEnd, trackY), r, thumbPaint);
  }

  @override
  bool shouldRepaint(_ScrubPainter old) =>
      old.fraction != fraction ||
      old.thumbScale != thumbScale ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor;
}
