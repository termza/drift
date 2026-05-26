import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/artwork.dart';
import '../widgets/track_tile.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _play(BuildContext context, WidgetRef ref, Track t) async {
    try {
      await ref.read(audioPlayerProvider).load(t);
      ref.read(currentTrackProvider.notifier).state = t;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play "${t.title}": $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favTracksAsync = ref.watch(favoriteTracksProvider);
    final progressMap = ref.watch(allProgressProvider).maybeWhen(
          data: (m) => m,
          orElse: () => null,
        );
    final current = ref.watch(currentTrackProvider);
    final snap = ref.watch(playbackSnapshotProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: favTracksAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Failed to load favorites\n$e',
                style: theme.textTheme.bodyMedium),
          ),
          data: (tracks) {
            if (tracks.isEmpty) return const _EmptyFavorites();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.gutter,
                      Insets.xl,
                      Insets.gutter,
                      Insets.md,
                    ),
                    child: _Header(count: tracks.length),
                  ),
                ),
                SliverList.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(left: 84),
                    child: Divider(
                      height: 0.5,
                      color: AppColors.borderSubtle,
                    ),
                  ),
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    final isCurrent = current?.id == t.id;
                    final p = progressMap?[t.id];
                    final dur = t.duration?.inMilliseconds;
                    final fraction = (p == null ||
                            dur == null ||
                            dur == 0)
                        ? null
                        : p.position.inMilliseconds / dur;
                    return TrackTile(
                      track: t,
                      isCurrent: isCurrent,
                      isPlaying:
                          isCurrent && (snap?.playing ?? false),
                      progressFraction: fraction,
                      onTap: () => _play(context, ref, t),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent,
                AppColors.accentDeep,
              ],
            ),
            borderRadius: BorderRadius.circular(Radii.sm + 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.25),
                blurRadius: 22,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: AppColors.accentInk,
            size: 44,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Favorites',
                style: theme.textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '$count ${count == 1 ? 'track' : 'tracks'}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 120, glow: true),
              const SizedBox(height: Insets.xl),
              Text(
                'No favorites yet',
                style: theme.textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the heart on any track to add it here.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
