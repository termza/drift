import 'package:flutter/material.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'glass_panel.dart';

/// Frosted-glass "Pick up where you left off" hero card. Matches the
/// phone+desktop mockup: small uppercase label, large title, "by Artist",
/// chapter / time-remaining line, slim amber progress, filled amber Resume
/// button with play icon.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.track,
    required this.progress,
    required this.onResume,
    this.currentChapter,
    this.totalChapters,
  });

  final Track track;
  final TrackProgress progress;
  final VoidCallback onResume;

  /// 1-indexed chapter number when available, for the "Ch. N / N" display.
  final int? currentChapter;
  final int? totalChapters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durMs = track.duration?.inMilliseconds ?? 0;
    final fraction =
        durMs == 0 ? 0.0 : progress.position.inMilliseconds / durMs;
    final remaining = (track.duration ?? Duration.zero) - progress.position;

    final statusLine = _statusLine(
      remaining: remaining,
      currentChapter: currentChapter,
      totalChapters: totalChapters,
    );

    return GlassPanel(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onResume,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PICK UP WHERE YOU LEFT OFF',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Artwork(
                      track: track,
                      size: 76,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          if ((track.artist ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'by ${track.artist}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            statusLine,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textTertiary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ResumeButton(onTap: onResume),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLine({
    required Duration remaining,
    int? currentChapter,
    int? totalChapters,
  }) {
    final parts = <String>[];
    if (currentChapter != null && totalChapters != null) {
      parts.add('Ch. $currentChapter / $totalChapters');
    }
    if (!remaining.isNegative && remaining != Duration.zero) {
      parts.add('${_fmtCompact(remaining)} remaining');
    }
    return parts.isEmpty ? '—' : parts.join('  |  ');
  }
}

class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: AppColors.accentInk,
              ),
              const SizedBox(width: 4),
              Text(
                'Resume',
                style: TextStyle(
                  color: AppColors.accentInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtCompact(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }
  return '${d.inMinutes}m';
}
