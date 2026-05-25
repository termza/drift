import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/player_screen.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final snapAsync = ref.watch(playbackSnapshotProvider);
    final theme = Theme.of(context);

    final snap = snapAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final fraction = (snap != null && snap.duration > Duration.zero)
        ? snap.position.inMilliseconds / snap.duration.inMilliseconds
        : 0.0;

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => _openPlayer(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            Insets.sm,
            Insets.sm,
            Insets.xs,
            Insets.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'now-playing-art',
                    child: Artwork(track: track, size: 46),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (track.artist != null) ...[
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
                  IconButton(
                    onPressed: () =>
                        ref.read(audioPlayerProvider).skipBack(),
                    icon: const Icon(Icons.replay_10_rounded, size: 24),
                    splashRadius: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  _PlayPauseButton(playing: snap?.playing ?? false),
                  IconButton(
                    onPressed: () =>
                        ref.read(audioPlayerProvider).skipForward(),
                    icon: const Icon(Icons.forward_30_rounded, size: 24),
                    splashRadius: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
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
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.base,
        pageBuilder: (_, __, ___) => const PlayerScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Motion.emphasized,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({required this.playing});
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => ref.read(audioPlayerProvider).togglePlay(),
      icon: AnimatedSwitcher(
        duration: Motion.fast,
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(
          playing
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_filled_rounded,
          key: ValueKey(playing),
          size: 36,
          color: AppColors.accent,
        ),
      ),
      splashRadius: 22,
      visualDensity: VisualDensity.compact,
    );
  }
}
