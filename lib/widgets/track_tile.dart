import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'playing_indicator.dart';

class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.isCurrent = false,
    this.isPlaying = false,
    this.progressFraction,
  });

  final Track track;
  final VoidCallback onTap;
  final bool isCurrent;
  final bool isPlaying;
  final double? progressFraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitle =
        [track.artist, track.album].whereType<String>().join(' — ');
    final isFav = ref.watch(favoritesProvider).maybeWhen(
          data: (s) => s.contains(track.id),
          orElse: () => false,
        );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.gutter,
          vertical: 8,
        ),
        child: Row(
          children: [
            Artwork(
              track: track,
              size: 52,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            const SizedBox(width: Insets.md),
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
                                ? AppColors.accent
                                : theme.textTheme.titleSmall?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        PlayingIndicator(
                          playing: true,
                          color: AppColors.accent,
                          size: 12,
                        ),
                      ],
                      if (track.isCloudOnly || track.isDownloading) ...[
                        const SizedBox(width: 6),
                        Icon(
                          track.isDownloading
                              ? Icons.downloading_rounded
                              : Icons.cloud_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ],
                      if (track.isUploading) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
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
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            _HeartButton(trackId: track.id, isFav: isFav),
          ],
        ),
      ),
    );
  }
}

class _HeartButton extends ConsumerWidget {
  const _HeartButton({required this.trackId, required this.isFav});
  final String trackId;
  final bool isFav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkResponse(
      onTap: () async {
        await ref.read(favoritesServiceProvider).toggle(trackId);
        ref.invalidate(favoritesProvider);
        ref.invalidate(favoriteTracksProvider);
      },
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(Insets.xs),
        child: Icon(
          isFav
              ? Icons.favorite_rounded
              : Icons.favorite_outline_rounded,
          size: 20,
          color: isFav ? AppColors.accent : AppColors.textTertiary,
        ),
      ),
    );
  }
}
