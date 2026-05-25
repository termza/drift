import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/continue_card.dart';
import '../widgets/empty_library.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';

  Future<void> _import() async {
    final added =
        await ref.read(libraryServiceProvider).pickAndImport();
    if (!mounted) return;
    if (added.isNotEmpty) {
      ref.invalidate(libraryProvider);
      ref.invalidate(allProgressProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${added.length} ${added.length == 1 ? 'track' : 'tracks'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _play(Track track) async {
    await ref.read(audioPlayerProvider).load(track);
    ref.read(currentTrackProvider.notifier).state = track;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryAsync = ref.watch(libraryProvider);
    final progressAsync = ref.watch(allProgressProvider);
    final continueAsync = ref.watch(continueListeningProvider);
    final current = ref.watch(currentTrackProvider);
    final snap = ref.watch(playbackSnapshotProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );
    final sort = ref.watch(librarySortProvider);

    return Scaffold(
      body: SafeArea(
        child: libraryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Failed to load library\n$e',
              textAlign: TextAlign.center,
            ),
          ),
          data: (tracks) {
            if (tracks.isEmpty) return EmptyLibrary(onImport: _import);

            final progressMap =
                progressAsync.maybeWhen(data: (m) => m, orElse: () => null);

            final filtered = _filterAndSort(tracks, sort);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.lg,
                      Insets.lg,
                      Insets.xs,
                    ),
                    child: _Header(
                      total: tracks.length,
                      duration: _totalDuration(tracks),
                      onImport: _import,
                    ),
                  ),
                ),
                if (continueAsync.maybeWhen(
                  data: (v) => v != null,
                  orElse: () => false,
                ))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        Insets.md,
                        Insets.lg,
                        0,
                      ),
                      child: ContinueCard(
                        track: continueAsync.value!.track,
                        progress: continueAsync.value!.progress,
                        onResume: () => _play(continueAsync.value!.track),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.lg,
                      Insets.lg,
                      Insets.sm,
                    ),
                    child: _SearchAndSort(
                      query: _query,
                      sort: sort,
                      onQuery: (v) => setState(() => _query = v),
                      onSort: (s) => ref
                          .read(librarySortProvider.notifier)
                          .state = s,
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No matches for "$_query"',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xs,
                      0,
                      Insets.xs,
                      140,
                    ),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        indent: 78,
                        endIndent: Insets.md,
                        color: theme.dividerTheme.color,
                      ),
                      itemBuilder: (context, i) {
                        final t = filtered[i];
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
                          isPlaying: isCurrent && (snap?.playing ?? false),
                          progressFraction: fraction,
                          onTap: () => _play(t),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Track> _filterAndSort(List<Track> tracks, LibrarySort sort) {
    Iterable<Track> it = tracks;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      it = it.where((t) =>
          t.title.toLowerCase().contains(q) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false));
    }
    final list = it.toList();
    switch (sort) {
      case LibrarySort.recentlyAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySort.title:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case LibrarySort.artist:
        list.sort((a, b) => (a.artist ?? '')
            .toLowerCase()
            .compareTo((b.artist ?? '').toLowerCase()));
    }
    return list;
  }

  Duration _totalDuration(List<Track> tracks) {
    var total = Duration.zero;
    for (final t in tracks) {
      if (t.duration != null) total += t.duration!;
    }
    return total;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.duration,
    required this.onImport,
  });
  final int total;
  final Duration duration;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Library', style: theme.textTheme.displayMedium),
              const SizedBox(height: 4),
              Text(
                '$total ${total == 1 ? 'track' : 'tracks'} · '
                '${_fmtTotal(duration)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onImport,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 22,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchAndSort extends StatelessWidget {
  const _SearchAndSort({
    required this.query,
    required this.sort,
    required this.onQuery,
    required this.onSort,
  });

  final String query;
  final LibrarySort sort;
  final ValueChanged<String> onQuery;
  final ValueChanged<LibrarySort> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: 'Search title, artist, album',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.textTheme.bodySmall?.color,
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: Insets.xs),
        PopupMenuButton<LibrarySort>(
          tooltip: 'Sort',
          initialValue: sort,
          onSelected: onSort,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          itemBuilder: (_) => [
            _menuItem(LibrarySort.recentlyAdded, 'Recently added', sort),
            _menuItem(LibrarySort.title, 'Title', sort),
            _menuItem(LibrarySort.artist, 'Artist', sort),
          ],
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 20,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<LibrarySort> _menuItem(
    LibrarySort value,
    String label,
    LibrarySort current,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value == current)
            const Icon(Icons.check_rounded, size: 18),
        ],
      ),
    );
  }
}

String _fmtTotal(Duration d) {
  if (d == Duration.zero) return 'no duration data';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
