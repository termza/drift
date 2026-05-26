import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_player_service.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/artwork.dart';
import '../widgets/artwork_palette.dart';
import '../widgets/bookmark_sheet.dart';
import '../widgets/chapter_sheet.dart';
import '../widgets/scrub_bar.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/speed_sheet.dart';

/// Apple-Music-style Now Playing. Big centered artwork, bold title block
/// below, slim scrubber, prominent transport row, secondary controls in a
/// row at the bottom.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);

    if (track == null) {
      return const Scaffold(
        body: Center(child: Text('Nothing playing')),
      );
    }

    final palette = ref.watch(artworkPaletteProvider(track)).maybeWhen(
          data: (p) => p,
          orElse: () => ArtworkPalette.fallback,
        );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          _Backdrop(palette: palette),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
            // Reserve space for everything below the artwork before sizing it.
            const reservedBelow = 340.0;
            final byWidth =
                (c.maxWidth - Insets.gutter * 2).clamp(180.0, 380.0);
            final byHeight = (c.maxHeight - reservedBelow)
                .clamp(180.0, 380.0);
            final artSize = byWidth < byHeight ? byWidth : byHeight;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.gutter,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  const _TopBar(),
                  const Spacer(flex: 2),
                  Hero(
                    tag: 'now-playing-art',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 60,
                            spreadRadius: -10,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Artwork(
                        track: track,
                        size: artSize,
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  _TitleBlock(title: track.title, artist: track.artist),
                  const SizedBox(height: Insets.md),
                  const _ChapterStrip(),
                  const _ScrubSection(),
                  const SizedBox(height: 12),
                  const _Transport(),
                  const Spacer(flex: 1),
                  const _Footer(),
                  const SizedBox(height: Insets.sm),
                ],
              ),
            );
          },
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.palette});
  final ArtworkPalette palette;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.top,
              palette.bottom,
            ],
            stops: const [0.0, 0.78],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final track = ref.watch(currentTrackProvider);
    return Row(
      children: [
        InkResponse(
          onTap: () => Navigator.of(context).maybePop(),
          radius: 22,
          child: const Padding(
            padding: EdgeInsets.all(Insets.xs),
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          ),
        ),
        const Spacer(),
        Text(
          'Now Playing',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _MoreMenu(trackId: track?.id),
      ],
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.trackId});
  final String? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, 36),
      position: PopupMenuPosition.under,
      icon: const Padding(
        padding: EdgeInsets.all(Insets.xs),
        child: Icon(Icons.more_horiz_rounded, size: 24),
      ),
      onSelected: (v) async {
        switch (v) {
          case 'restart':
            await ref.read(audioPlayerProvider).seek(Duration.zero);
          case 'bookmarks':
            if (trackId != null) {
              await showBookmarkSheet(context, trackId!);
            }
          case 'mark_done':
            if (trackId != null) {
              await ref.read(progressStoreProvider).markCompleted(trackId!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marked as played')),
                );
              }
            }
          case 'remove':
            if (trackId != null) {
              await ref.read(libraryServiceProvider).remove(trackId!);
              ref.invalidate(libraryProvider);
              ref.invalidate(allProgressProvider);
              ref.read(currentTrackProvider.notifier).state = null;
              await ref.read(audioPlayerProvider).pause();
              if (context.mounted) Navigator.of(context).maybePop();
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'bookmarks',
          height: 42,
          child: _MenuItem(
            icon: Icons.bookmark_outline_rounded,
            label: 'Bookmarks',
          ),
        ),
        const PopupMenuItem(
          value: 'restart',
          height: 42,
          child: _MenuItem(
            icon: Icons.restart_alt_rounded,
            label: 'Restart track',
          ),
        ),
        const PopupMenuItem(
          value: 'mark_done',
          height: 42,
          child: _MenuItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Mark as played',
          ),
        ),
        const PopupMenuDivider(height: 0.5),
        const PopupMenuItem(
          value: 'remove',
          height: 42,
          child: _MenuItem(
            icon: Icons.delete_outline_rounded,
            label: 'Remove from library',
            danger: true,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Insets.sm),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.artist});
  final String title;
  final String? artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (artist != null) ...[
            const SizedBox(height: 4),
            Text(
              artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScrubSection extends ConsumerWidget {
  const _ScrubSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snap = ref.watch(playbackSnapshotProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const PlaybackSnapshot(
            position: Duration.zero,
            duration: Duration.zero,
            playing: false,
          ),
        );

    return Column(
      children: [
        ScrubBar(
          position: snap.position,
          duration: snap.duration,
          onSeek: (d) => ref.read(audioPlayerProvider).seek(d),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xxs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(snap.position),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '-${_fmt(_remaining(snap))}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Duration _remaining(PlaybackSnapshot s) {
  final r = s.duration - s.position;
  return r.isNegative ? Duration.zero : r;
}

class _Transport extends ConsumerWidget {
  const _Transport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playbackSnapshotProvider).maybeWhen(
          data: (s) => s.playing,
          orElse: () => false,
        );

    // Subscribe to the chapter index stream so the prev/next enabled state
    // updates live as playback crosses chapter boundaries.
    final chapterIdx = ref.watch(currentChapterIndexProvider).valueOrNull;
    final player = ref.watch(audioPlayerProvider);
    final hasChapters = player.hasChapters;
    final canPrev = hasChapters;
    final canNext = hasChapters &&
        chapterIdx != null &&
        chapterIdx + 1 < player.currentChapters.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Ghost(
          icon: Icons.skip_previous_rounded,
          size: 38,
          onTap: canPrev ? () => player.prevChapter() : null,
        ),
        InkResponse(
          onTap: () => ref.read(audioPlayerProvider).togglePlay(),
          radius: 48,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              key: ValueKey(playing),
              size: 72,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _Ghost(
          icon: Icons.skip_next_rounded,
          size: 38,
          onTap: canNext ? () => player.nextChapter() : null,
        ),
      ],
    );
  }
}

/// Compact pill above the scrubber showing the current chapter. Tapping
/// opens the full chapter list. Renders nothing when the track has none.
class _ChapterStrip extends ConsumerWidget {
  const _ChapterStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the stream is what makes us rebuild on chapter change.
    ref.watch(currentChapterIndexProvider);
    final player = ref.watch(audioPlayerProvider);
    if (!player.hasChapters) return const SizedBox.shrink();

    final ch = player.currentChapter;
    final idx = player.currentChapterIndex ?? 0;
    final total = player.currentChapters.length;
    final title = (ch?.title != null && ch!.title!.isNotEmpty)
        ? ch.title!
        : 'Chapter ${idx + 1}';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () => showChapterSheet(context),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.list_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                '${idx + 1} of $total',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({
    required this.icon,
    required this.onTap,
    this.size = 32,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: enabled ? 1.0 : 0.28,
          child: Icon(icon, size: size, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Speed comes through the snapshot stream so changes rebuild the UI.
    final speed = ref.watch(playbackSnapshotProvider).maybeWhen(
          data: (s) => s.speed,
          orElse: () => 1.0,
        );
    final sleep = ref.watch(sleepTimerProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SkipBtn(
            icon: Icons.replay_10_rounded,
            label: '10',
            onTap: () => ref.read(audioPlayerProvider).skipBack(),
          ),
          _SpeedPill(speed: speed),
          _FooterIcon(
            icon: sleep.isActive
                ? Icons.bedtime_rounded
                : Icons.bedtime_outlined,
            accent: sleep.isActive,
            onTap: () => showSleepTimerSheet(context),
          ),
          _SkipBtn(
            icon: Icons.forward_30_rounded,
            label: '30',
            onTap: () => ref.read(audioPlayerProvider).skipForward(),
          ),
        ],
      ),
    );
  }
}

class _SkipBtn extends StatelessWidget {
  const _SkipBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(Insets.xs),
        child: Icon(icon, size: 28, color: AppColors.textPrimary),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.speed});
  final double speed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}×';
    return InkWell(
      onTap: () => showSpeedSheet(context),
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: AppColors.fillTertiary,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _FooterIcon extends StatelessWidget {
  const _FooterIcon({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(Insets.xs),
        child: Icon(
          icon,
          size: 22,
          color:
              accent ? AppColors.accent : AppColors.textPrimary,
        ),
      ),
    );
  }
}

String _fmt(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
