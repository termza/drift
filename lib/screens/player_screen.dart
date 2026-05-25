import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_player_service.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/artwork.dart';
import '../widgets/scrub_bar.dart';
import '../widgets/sleep_timer_sheet.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final theme = Theme.of(context);

    if (track == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    return Scaffold(
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Column(
                children: [
                  const SizedBox(height: Insets.xs),
                  _TopBar(),
                  const Spacer(flex: 3),
                  Hero(
                    tag: 'now-playing-art',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.xxl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 80,
                            spreadRadius: -16,
                            offset: const Offset(0, 30),
                          ),
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            blurRadius: 60,
                            spreadRadius: -20,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Artwork(
                        track: track,
                        size: 300,
                        borderRadius: BorderRadius.circular(Radii.xxl),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  if (track.artist != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      track.artist!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: Insets.lg + 4),
                  const _ScrubSection(),
                  const SizedBox(height: Insets.md),
                  const _TransportControls(),
                  const Spacer(flex: 2),
                  const _BottomBar(),
                  const SizedBox(height: Insets.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.1,
            colors: [
              AppColors.accent.withValues(alpha: 0.10),
              theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _RoundIcon(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const Spacer(),
        Text(
          'NOW PLAYING',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.6,
            fontSize: 10.5,
          ),
        ),
        const Spacer(),
        _RoundIcon(
          icon: Icons.more_horiz_rounded,
          onTap: () {},
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(Insets.xs),
        child: Icon(icon, size: 24),
      ),
    );
  }
}

class _ScrubSection extends ConsumerWidget {
  const _ScrubSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapAsync = ref.watch(playbackSnapshotProvider);
    final snap = snapAsync.maybeWhen(
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
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '-${_fmt(_remaining(snap))}',
                style: theme.textTheme.labelMedium?.copyWith(
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

class _TransportControls extends ConsumerWidget {
  const _TransportControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playbackSnapshotProvider);
    final playing =
        snap.maybeWhen(data: (s) => s.playing, orElse: () => false);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _GhostButton(icon: Icons.skip_previous_rounded, size: 28, onTap: () {}),
        _GhostButton(
          icon: Icons.replay_10_rounded,
          size: 32,
          onTap: () => ref.read(audioPlayerProvider).skipBack(),
        ),
        _PlayButton(playing: playing),
        _GhostButton(
          icon: Icons.forward_30_rounded,
          size: 32,
          onTap: () => ref.read(audioPlayerProvider).skipForward(),
        ),
        _GhostButton(icon: Icons.skip_next_rounded, size: 28, onTap: () {}),
      ],
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.playing});
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => ref.read(audioPlayerProvider).togglePlay(),
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: Motion.fast,
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.30),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(playing),
            size: 38,
            color: const Color(0xFF1A0F05),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.onTap,
    this.size = 28,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Icon(
          icon,
          size: size,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(audioPlayerProvider).speed;
    final sleep = ref.watch(sleepTimerProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SpeedPill(speed: speed),
        _SleepBtn(active: sleep.isActive),
        _IconBtn(
            icon: Icons.bookmark_outline_rounded, tooltip: 'Bookmark'),
        _IconBtn(icon: Icons.queue_music_rounded, tooltip: 'Queue'),
      ],
    );
  }
}

class _SleepBtn extends StatelessWidget {
  const _SleepBtn({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showSleepTimerSheet(context),
      icon: Icon(
        active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
        size: 22,
        color: active ? AppColors.accent : null,
      ),
      tooltip: 'Sleep timer',
      splashRadius: 22,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SpeedPill extends ConsumerWidget {
  const _SpeedPill({required this.speed});
  final double speed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _cycle(ref, speed),
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Text(
          '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}×',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  void _cycle(WidgetRef ref, double current) {
    const steps = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75];
    final idx = steps.indexWhere((s) => (s - current).abs() < 0.01);
    final next = steps[(idx + 1) % steps.length];
    ref.read(audioPlayerProvider).setSpeed(next);
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, this.tooltip});
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      splashRadius: 22,
      visualDensity: VisualDensity.compact,
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
