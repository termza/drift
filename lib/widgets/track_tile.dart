import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'playing_indicator.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.isCurrent = false,
    this.isPlaying = false,
    this.progressFraction,
    this.onMore,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  /// Track is the one currently loaded in the player (regardless of play state).
  final bool isCurrent;

  /// Player is actively playing the loaded track.
  final bool isPlaying;

  final double? progressFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        [track.artist, track.album].whereType<String>().join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm + 4,
          vertical: 10,
        ),
        child: Row(
          children: [
            Artwork(track: track, size: 50),
            const SizedBox(width: Insets.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : theme.textTheme.titleSmall?.color,
                            fontWeight:
                                isCurrent ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: Insets.xs),
                        PlayingIndicator(
                          playing: isPlaying,
                          color: theme.colorScheme.primary,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (progressFraction != null && progressFraction! > 0) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: progressFraction!.clamp(0.0, 1.0),
                        minHeight: 2,
                        backgroundColor: theme.dividerTheme.color,
                        valueColor: AlwaysStoppedAnimation(
                          theme.colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.xs),
            if (track.duration != null)
              Text(
                _fmt(track.duration!),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (onMore != null)
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz, size: 20),
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
              ),
          ],
        ),
      ),
    );
  }
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
