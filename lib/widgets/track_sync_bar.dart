import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';

/// Slim 2px timeline that lives beneath each track tile and renders the
/// track's current cloud-sync state. Listens to [TrackSyncService] so it
/// updates live during uploads / downloads.
///
/// Visual language:
/// - localOnly  : nothing (no sync activity to communicate)
/// - uploading  : indeterminate kinetic-amber sweep
/// - uploaded   : thin full-width amber line
/// - cloudOnly  : thin dashed amber outline
/// - downloading: indeterminate amber sweep
/// - failed     : thin red line
class TrackSyncBar extends ConsumerWidget {
  const TrackSyncBar({super.key, required this.track, this.height = 2});
  final Track track;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the sync service so state changes (upload start/complete) rebuild
    // this widget without needing a libraryProvider invalidation.
    final sync = ref.watch(trackSyncServiceProvider);
    final state = track.cloudState;

    if (state == TrackCloudState.localOnly) {
      return SizedBox(height: height);
    }

    Widget bar;
    switch (state) {
      case TrackCloudState.localOnly:
        bar = const SizedBox.shrink();
      case TrackCloudState.uploaded:
        bar = _SolidBar(height: height, color: AppColors.accent);
      case TrackCloudState.cloudOnly:
        bar = _DashedBar(
          height: height,
          color: AppColors.accent.withValues(alpha: 0.55),
        );
      case TrackCloudState.uploading:
      case TrackCloudState.downloading:
        final p = sync.progressFor(track.id);
        bar = p == null
            ? _IndeterminateBar(height: height, color: AppColors.accent)
            : _DeterminateBar(
                height: height,
                color: AppColors.accent,
                fraction: p,
              );
      case TrackCloudState.failed:
        bar = _SolidBar(height: height, color: AppColors.danger);
    }
    return bar;
  }
}

class _SolidBar extends StatelessWidget {
  const _SolidBar({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _DeterminateBar extends StatelessWidget {
  const _DeterminateBar({
    required this.height,
    required this.color,
    required this.fraction,
  });
  final double height;
  final Color color;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(
            height: height,
            color: color.withValues(alpha: 0.18),
          ),
          FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height / 2),
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            return CustomPaint(
              painter: _IndeterminatePainter(
                t: _c.value,
                color: widget.color,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IndeterminatePainter extends CustomPainter {
  _IndeterminatePainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = color.withValues(alpha: 0.15);
    canvas.drawRect(Offset.zero & size, bg);

    // A 35%-wide sweep that ping-pongs across the bar.
    const sweep = 0.35;
    final progress = (-sweep) + (1 + sweep) * t;
    final left = progress * size.width;
    final right = (progress + sweep) * size.width;

    final fg = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTRB(left, 0, right, size.height));
    canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), fg);
  }

  @override
  bool shouldRepaint(covariant _IndeterminatePainter old) =>
      old.t != t || old.color != color;
}

class _DashedBar extends StatelessWidget {
  const _DashedBar({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedPainter(color: color, height: height),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({required this.color, required this.height});
  final Color color;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = height
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color || old.height != height;
}
