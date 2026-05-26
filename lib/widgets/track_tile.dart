import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'playing_indicator.dart';
import 'track_sync_bar.dart';

/// Library row matching the mockup:
///   - small uppercase type label ("Audiobook" / "Music Track")
///   - bold title (with playing indicator on the current track)
///   - "by Artist" subtitle
///   - status line: "Synced · Chapter X · NN% Complete" / "Not Started" / etc.
///   - cloud icon on the right indicating sync state
///   - thin per-item sync timeline at the bottom edge
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

  /// 0.0–1.0 listen progress through the track; null when no saved
  /// position exists ("Not Started").
  final double? progressFraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typeLabel = track.isAudiobook ? 'Audiobook' : 'Music Track';
    final percent = (progressFraction ?? 0).clamp(0.0, 1.0);
    final progressOpt =
        ref.watch(allProgressProvider).maybeWhen(data: (m) => m, orElse: () => null);
    final tp = progressOpt?[track.id];
    final statusLine = _statusLine(track, tp, percent);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Artwork(
                  track: track,
                  size: 56,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        typeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            PlayingIndicator(
                              playing: isPlaying,
                              color: AppColors.accent,
                              size: 12,
                            ),
                          ],
                        ],
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
                      const SizedBox(height: 4),
                      Text(
                        statusLine,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                _SyncIcon(track: track),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 36),
              child: TrackSyncBar(track: track),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the "Synced · Chapter X · NN% Complete" line. Falls back to
  /// "Not Started" when no saved position exists.
  String _statusLine(Track track, TrackProgress? tp, double percent) {
    final parts = <String>[];

    // Sync state prefix.
    switch (track.cloudState) {
      case TrackCloudState.uploaded:
        parts.add('Synced');
      case TrackCloudState.uploading:
        parts.add('Uploading');
      case TrackCloudState.cloudOnly:
        parts.add('Cloud');
      case TrackCloudState.downloading:
        parts.add('Downloading');
      case TrackCloudState.failed:
        parts.add('Sync failed');
      case TrackCloudState.localOnly:
        parts.add('Local');
    }

    if (tp != null && tp.currentChapter != null) {
      parts.add('Chapter ${tp.currentChapter! + 1}');
    }

    if (tp == null) {
      parts.add('Not Started');
    } else if (tp.completed) {
      parts.add('Complete');
    } else {
      final pct = (percent * 100).round();
      parts.add('$pct% Complete');
    }

    return parts.join('  ·  ');
  }
}

class _SyncIcon extends StatelessWidget {
  const _SyncIcon({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (track.cloudState) {
      TrackCloudState.uploaded => (
          Icons.cloud_done_outlined,
          AppColors.accent.withValues(alpha: 0.85)
        ),
      TrackCloudState.cloudOnly => (
          Icons.cloud_download_outlined,
          AppColors.accent
        ),
      TrackCloudState.uploading => (
          Icons.cloud_upload_outlined,
          AppColors.textSecondary
        ),
      TrackCloudState.downloading => (
          Icons.downloading_rounded,
          AppColors.accent
        ),
      TrackCloudState.failed => (
          Icons.cloud_off_outlined,
          AppColors.danger.withValues(alpha: 0.7)
        ),
      TrackCloudState.localOnly => (
          Icons.cloud_outlined,
          AppColors.textTertiary
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
