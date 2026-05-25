import 'package:flutter/material.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';

/// Hero card at the top of the library — surfaces the most-recent in-progress
/// track with a one-tap resume.
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

    return InkWell(
      onTap: onResume,
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withValues(alpha: 0.10),
              AppColors.accent.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.25),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            Artwork(track: track, size: 64),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CONTINUE LISTENING',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.4,
                      color: AppColors.accent,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    remaining.isNegative || remaining == Duration.zero
                        ? (track.artist ?? '')
                        : '${_fmtCompact(remaining)} left'
                            '${track.artist != null ? ' · ${track.artist}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: theme.colorScheme.outlineVariant,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            _ResumeButton(onTap: onResume),
          ],
        ),
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 26,
          color: Color(0xFF1A0F05),
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
