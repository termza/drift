import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'playing_indicator.dart';

/// Dense single-line row — no artwork, just text + duration. For users who
/// want maximum information density in long libraries.
class TrackCompactTile extends StatelessWidget {
  const TrackCompactTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onLongPress,
    this.isCurrent = false,
    this.isPlaying = false,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isCurrent;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        [track.artist, track.album].whereType<String>().join(' — ');
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.gutter,
          vertical: 6,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: isCurrent
                  ? PlayingIndicator(
                      playing: isPlaying,
                      color: AppColors.accent,
                      size: 12,
                    )
                  : null,
            ),
            const SizedBox(width: Insets.xs),
            Expanded(
              flex: 5,
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              flex: 4,
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: Insets.md),
            SizedBox(
              width: 56,
              child: Text(
                track.duration == null ? '—' : _fmt(track.duration!),
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
