import 'package:flutter/material.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';

/// Apple-Music-style "Recently Played" hero card. White card, subtle shadow.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.track,
    required this.progress,
    required this.onResume,
  });

  final Track track;
  final TrackProgress progress;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dur = track.duration?.inMilliseconds ?? 0;
    final fraction =
        dur == 0 ? 0.0 : progress.position.inMilliseconds / dur;
    final remaining = (track.duration ?? Duration.zero) - progress.position;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Artwork(
                  track: track,
                  size: 76,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue listening',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        remaining.isNegative ||
                                remaining == Duration.zero
                            ? (track.artist ?? '')
                            : '${_fmtCompact(remaining)} left'
                                '${track.artist != null ? ' — ${track.artist}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: AppColors.fillSecondary,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.md),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 26,
                    color: AppColors.accentInk,
                  ),
                ),
              ],
            ),
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
