import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Custom hairline scrub bar. A 2px track with no thumb when idle; the thumb
/// fades in only while you're dragging. Less visual chrome.
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
  double? _drag;

  @override
  void initState() {
    super.initState();
    _thumb = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _thumb.dispose();
    super.dispose();
  }

  double get _fraction {
    if (_drag != null) return _drag!.clamp(0.0, 1.0);
    final total = widget.duration.inMilliseconds;
    if (total == 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _setDrag(double dx, double width) {
    setState(() => _drag = (dx / width).clamp(0.0, 1.0));
  }

  void _commit() {
    if (_drag != null) {
      final ms = (widget.duration.inMilliseconds * _drag!).round();
      widget.onSeek(Duration(milliseconds: ms));
    }
    _thumb.reverse();
    setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        return SizedBox(
          height: 24,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (d) {
              _thumb.forward();
              _setDrag(d.localPosition.dx, c.maxWidth);
            },
            onHorizontalDragUpdate: (d) =>
                _setDrag(d.localPosition.dx, c.maxWidth),
            onHorizontalDragEnd: (_) => _commit(),
            onHorizontalDragCancel: _commit,
            onTapUp: (d) {
              final f = (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0);
              final ms = (widget.duration.inMilliseconds * f).round();
              widget.onSeek(Duration(milliseconds: ms));
            },
            child: AnimatedBuilder(
              animation: _thumb,
              builder: (context, _) => CustomPaint(
                size: Size(c.maxWidth, 24),
                painter: _Painter(
                  fraction: _fraction,
                  track: theme.colorScheme.outlineVariant,
                  active: AppColors.accent,
                  thumb: _thumb.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Painter extends CustomPainter {
  _Painter({
    required this.fraction,
    required this.track,
    required this.active,
    required this.thumb,
  });

  final double fraction;
  final Color track;
  final Color active;
  final double thumb;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = active
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), trackPaint);

    final activeEnd = size.width * fraction;
    if (activeEnd > 0) {
      canvas.drawLine(Offset(0, y), Offset(activeEnd, y), activePaint);
    }

    // Thumb only appears mid-drag — keep the resting state quiet.
    if (thumb > 0) {
      final r = 5.0 * thumb;
      final thumbPaint = Paint()..color = active;
      canvas.drawCircle(Offset(activeEnd, y), r, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(_Painter old) =>
      old.fraction != fraction ||
      old.thumb != thumb ||
      old.active != active ||
      old.track != track;
}
