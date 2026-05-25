import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/player_screen.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';

/// Apple-Music-style bottom player. White card floating just above the bottom
/// edge, soft shadow underneath, rounded corners. Play and skip-forward
/// buttons exposed; the rest is one tap away.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final snap = ref.watch(playbackSnapshotProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );
    final playing = snap?.playing ?? false;

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.sm,
        0,
        Insets.sm,
        Insets.sm,
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        borderRadius: BorderRadius.circular(Radii.md),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                spreadRadius: -8,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _openPlayer(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  Hero(
                    tag: 'now-playing-art',
                    child: Artwork(
                      track: track,
                      size: 44,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (track.artist != null) ...[
                          const SizedBox(height: 1),
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
                  _IconBtn(
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 28,
                    onTap: () =>
                        ref.read(audioPlayerProvider).togglePlay(),
                  ),
                  const SizedBox(width: 2),
                  _IconBtn(
                    icon: Icons.forward_30_rounded,
                    size: 26,
                    onTap: () =>
                        ref.read(audioPlayerProvider).skipForward(),
                  ),
                ],
              ),
            ),
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
            curve: Motion.standard,
            reverseCurve: Motion.exit,
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

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.size = 26,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: AppColors.textPrimary),
      ),
    );
  }
}
