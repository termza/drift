import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'playing_indicator.dart';
import 'track_sync_bar.dart';

/// Standard library row — artwork · title (with state markers) · metadata
/// line · per-item sync timeline. Designed for the high-density audiobook
/// library; not for the grid view (which uses TrackGridTile).
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
    final isFav = ref.watch(favoritesProvider).maybeWhen(
          data: (s) => s.contains(track.id),
          orElse: () => false,
        );

    // Compose the metadata line: artist · album · duration. Skip empty parts
    // so we don't get awkward "·  · 1:23" gaps.
    final metaParts = <String>[
      if ((track.artist ?? '').isNotEmpty) track.artist!,
      if ((track.album ?? '').isNotEmpty) track.album!,
      if (track.duration != null) _fmtDur(track.duration!),
    ];
    final subtitle = metaParts.join('  ·  ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.gutter,
          vertical: 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                                fontWeight: FontWeight.w600,
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
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                _HeartButton(trackId: track.id, isFav: isFav),
              ],
            ),
            // Per-item timeline track. 76px left inset matches artwork + gap
            // so the bar visually starts where the title does.
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 76, right: 44),
              child: TrackSyncBar(track: track),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDur(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
