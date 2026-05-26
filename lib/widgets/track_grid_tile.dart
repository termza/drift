import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'playing_indicator.dart';

/// Artwork-first square tile used by the grid library view. Title +
/// artist sit below the cover; current-track state shows as a small
/// playing-indicator overlay on the artwork corner.
class TrackGridTile extends StatelessWidget {
  const TrackGridTile({
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
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.md),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 14,
                            spreadRadius: -4,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Artwork(
                        track: track,
                        size: 1000, // expands to fill via SizedBox
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    if (isCurrent)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: PlayingIndicator(
                            playing: isPlaying,
                            color: AppColors.accent,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((track.artist ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                track.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
