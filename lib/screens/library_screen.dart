import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appearance_prefs.dart';
import '../models/track.dart';
import '../services/import_result.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/cache_size_indicator.dart';
import '../widgets/connection_bar.dart';
import '../widgets/continue_card.dart';
import '../widgets/empty_library.dart';
import '../widgets/library_filter_chips.dart';
import '../widgets/track_compact_tile.dart';
import '../widgets/track_grid_tile.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';
  bool _searchOpen = false;
  bool _pulled = false;

  @override
  void initState() {
    super.initState();
    // Pull cloud catalog once per screen mount, after first frame so we
    // don't block paint. Silent failure — library still loads from local DB.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_pulled || !mounted) return;
      _pulled = true;
      final auth = ref.read(authRepositoryProvider);
      if (!auth.isSignedIn) return;
      final sync = ref.read(trackSyncServiceProvider);
      await sync.pullCatalog();
      if (!mounted) return;
      ref.invalidate(libraryProvider);
      // Push anything still local-only — catches tracks imported before the
      // user signed in.
      unawaited(sync.syncAllLocal());
    });
  }

  Future<void> _import() async {
    final result = await ref.read(libraryServiceProvider).pickAndImport();
    if (!mounted) return;
    if (result.isEmpty) return;
    if (result.added.isNotEmpty) {
      ref.invalidate(libraryProvider);
      ref.invalidate(allProgressProvider);
    }
    final parts = <String>[];
    if (result.added.isNotEmpty) parts.add('Added ${result.added.length}');
    if (result.skipped > 0) parts.add('Skipped ${result.skipped}');
    if (result.failed.isNotEmpty) parts.add('Failed ${result.failed.length}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(' · ')),
        action: result.failed.isNotEmpty
            ? SnackBarAction(
                label: 'Details',
                onPressed: () => _showFailures(result.failed),
              )
            : null,
      ),
    );
  }

  void _showFailures(List<ImportFailure> failures) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.md,
            Insets.gutter,
            Insets.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Couldn't import",
                style: Theme.of(ctx).textTheme.headlineLarge,
              ),
              const SizedBox(height: Insets.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: failures.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 0.5,
                    color: AppColors.borderSubtle,
                  ),
                  itemBuilder: (_, i) {
                    final f = failures[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.fileName,
                            style: Theme.of(ctx).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.reason,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTrackActions(Track t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.gutter,
                Insets.md,
                Insets.gutter,
                4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(sheetCtx).textTheme.titleMedium),
                  if ((t.artist ?? '').isNotEmpty)
                    Text('by ${t.artist}',
                        style: Theme.of(sheetCtx).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (t.isLocal && t.cloudRecordId != null)
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Remove local copy',
                subtitle: 'Frees disk space; re-download from cloud later',
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _confirmAndDelete(t, RemoveScope.localOnly);
                },
              ),
            if (t.cloudRecordId != null)
              _SheetAction(
                icon: Icons.cloud_off_outlined,
                label: 'Delete from cloud',
                subtitle: t.isLocal
                    ? 'Keeps the local file on this device'
                    : 'No local copy — track will disappear from the library',
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _confirmAndDelete(t, RemoveScope.cloudOnly);
                },
              ),
            _SheetAction(
              icon: Icons.delete_forever_rounded,
              label: 'Remove everywhere',
              subtitle: 'Local copy + cloud catalog entry + bookmarks',
              danger: true,
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _confirmAndDelete(t, RemoveScope.everywhere);
              },
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(Track t, RemoveScope scope) async {
    final descriptor = switch (scope) {
      RemoveScope.localOnly => 'the local copy of',
      RemoveScope.cloudOnly => 'the cloud catalog entry for',
      RemoveScope.everywhere => 'all traces of',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove track'),
        content: Text('Remove $descriptor "${t.title}"?\nThis can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final sync = ref.read(trackSyncServiceProvider);
    try {
      switch (scope) {
        case RemoveScope.localOnly:
          await sync.deleteLocalCopy(t);
        case RemoveScope.cloudOnly:
          final ok = await sync.deleteRemote(t);
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cloud delete failed — sign in to the sync server first.',
                ),
              ),
            );
          }
        case RemoveScope.everywhere:
          await sync.deleteRemote(t);
          await sync.deleteLocalCopy(t);
          await ref.read(libraryServiceProvider).remove(t.id);
      }
    } finally {
      if (mounted) {
        ref.invalidate(libraryProvider);
        ref.invalidate(allProgressProvider);
        ref.invalidate(cacheSizeProvider);
      }
    }
  }

  Future<void> _play(Track t) async {
    // Cloud-only tracks need a download first. Show a blocking dialog so the
    // user knows what's happening — downloads can take a while for big M4Bs.
    final needsDownload = !t.isLocal;
    if (needsDownload && mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  'Downloading "${t.title}"…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
    try {
      await ref.read(audioPlayerProvider).load(t);
      ref.read(currentTrackProvider.notifier).state = t;
      if (needsDownload) ref.invalidate(libraryProvider);
    } catch (e, st) {
      debugPrint('Failed to load track ${t.id}: $e\n$st');
      if (!mounted) return;
      final detail = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Could not play "${t.title}"'),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () => _showPlayError(t, detail, st.toString()),
          ),
        ),
      );
    } finally {
      if (needsDownload && mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showPlayError(Track t, String error, String stack) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Playback failed',
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.title,
                  style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'id: ${t.id}\nstate: ${t.cloudState.name}\npath: ${t.filePath.isEmpty ? "(none)" : t.filePath}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text('Error', style: Theme.of(ctx).textTheme.labelSmall),
              const SizedBox(height: 4),
              SelectableText(
                error,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
              ),
              const SizedBox(height: 12),
              Text('Stack (first 800 chars)',
                  style: Theme.of(ctx).textTheme.labelSmall),
              const SizedBox(height: 4),
              SelectableText(
                stack.length > 800 ? '${stack.substring(0, 800)}…' : stack,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontFamily: 'monospace',
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
    final filter = ref.watch(libraryFilterProvider);
    final appearanceService = ref.watch(appearancePrefsServiceProvider);
    final viewMode = appearanceService.current.libraryViewMode;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: libraryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Failed to load library\n$e',
                textAlign: TextAlign.center),
          ),
          data: (tracks) {
            if (tracks.isEmpty) return EmptyLibrary(onImport: _import);

            final progressMap =
                progressAsync.maybeWhen(data: (m) => m, orElse: () => null);
            final filtered = _filterAndSort(tracks, sort, filter);
            final showContinue = continueAsync.maybeWhen(
              data: (v) => v != null && _query.isEmpty,
              orElse: () => false,
            );

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: ConnectionBar()),
                SliverToBoxAdapter(
                  child: _Header(
                    onImport: _import,
                    onSearchToggle: () =>
                        setState(() => _searchOpen = !_searchOpen),
                    searchOpen: _searchOpen,
                    onQuery: (v) => setState(() => _query = v),
                  ),
                ),
                if (showContinue)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.gutter,
                        Insets.md,
                        Insets.gutter,
                        0,
                      ),
                      child: _ContinueWithChapters(
                        track: continueAsync.value!.track,
                        progress: continueAsync.value!.progress,
                        onResume: () => _play(continueAsync.value!.track),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: Insets.lg),
                ),
                const SliverToBoxAdapter(child: LibraryFilterChips()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.gutter,
                      Insets.md,
                      Insets.gutter,
                      Insets.sm,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${filtered.length} ${filtered.length == 1 ? 'track' : 'tracks'}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _ViewModeToggle(
                          current: viewMode,
                          onPick: (m) =>
                              appearanceService.setLibraryViewMode(m),
                        ),
                        const SizedBox(width: 6),
                        _SortButton(
                          current: sort,
                          onSelected: (s) => ref
                              .read(librarySortProvider.notifier)
                              .state = s,
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.xl),
                      child: Center(
                        child: Text(
                          'No matches for "$_query"',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  _buildTrackSliver(
                    mode: viewMode,
                    tracks: filtered,
                    current: current,
                    snap: snap,
                    progressMap: progressMap,
                  ),
                const SliverToBoxAdapter(child: CacheSizeIndicator()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrackSliver({
    required LibraryViewMode mode,
    required List<Track> tracks,
    required Track? current,
    required dynamic snap,
    required Map<String, dynamic>? progressMap,
  }) {
    switch (mode) {
      case LibraryViewMode.list:
        return SliverList.separated(
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
            final fraction = (p == null || dur == null || dur == 0)
                ? null
                : p.position.inMilliseconds / dur;
            return TrackTile(
              track: t,
              isCurrent: isCurrent,
              isPlaying: isCurrent && (snap?.playing ?? false),
              progressFraction: fraction,
              onTap: () => _play(t),
              onLongPress: () => _showTrackActions(t),
            );
          },
        );
      case LibraryViewMode.grid:
        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.gutter - 4,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              // Aim for ~170px tiles, snapping to whole columns. Allow up to
              // 10 cols so widescreen Windows / external monitors fill nicely.
              final cols =
                  (constraints.crossAxisExtent / 175).floor().clamp(2, 10);
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  // Slightly taller than wide to fit title + artist.
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final t = tracks[i];
                    final isCurrent = current?.id == t.id;
                    return TrackGridTile(
                      track: t,
                      isCurrent: isCurrent,
                      isPlaying: isCurrent && (snap?.playing ?? false),
                      onTap: () => _play(t),
                    );
                  },
                  childCount: tracks.length,
                ),
              );
            },
          ),
        );
      case LibraryViewMode.compact:
        return SliverList.separated(
          itemCount: tracks.length,
          separatorBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(left: 30, right: Insets.gutter),
            child: Divider(
              height: 0.5,
              color: AppColors.borderSubtle,
            ),
          ),
          itemBuilder: (context, i) {
            final t = tracks[i];
            final isCurrent = current?.id == t.id;
            return TrackCompactTile(
              track: t,
              isCurrent: isCurrent,
              isPlaying: isCurrent && (snap?.playing ?? false),
              onTap: () => _play(t),
              onLongPress: () => _showTrackActions(t),
            );
          },
        );
    }
  }

  List<Track> _filterAndSort(
    List<Track> tracks,
    LibrarySort sort,
    LibraryFilter filter,
  ) {
    Iterable<Track> it = tracks;

    // Filter chip: All / Audiobooks / Music / Downloaded.
    switch (filter) {
      case LibraryFilter.all:
        break;
      case LibraryFilter.audiobooks:
        it = it.where((t) => t.isAudiobook);
      case LibraryFilter.music:
        it = it.where((t) => !t.isAudiobook);
      case LibraryFilter.downloaded:
        // "Downloaded" = has a local file. Excludes cloud-only catalog entries.
        it = it.where((t) => t.isLocal);
    }

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
}

enum RemoveScope { localOnly, cloudOnly, everywhere }

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.gutter,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Continue card wrapper that pulls chapter metadata for the resuming track
/// so the card can show "Ch. N / N". Inline helper keeps the build method
/// readable.
class _ContinueWithChapters extends ConsumerWidget {
  const _ContinueWithChapters({
    required this.track,
    required this.progress,
    required this.onResume,
  });
  final Track track;
  final dynamic progress;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersForTrackProvider(track.id));
    final chapters = chaptersAsync.maybeWhen(
      data: (c) => c,
      orElse: () => null,
    );
    int? current;
    if (chapters != null && chapters.isNotEmpty && progress != null) {
      final pos = progress.position as Duration;
      for (var i = 0; i < chapters.length; i++) {
        if (chapters[i].contains(pos)) {
          current = i + 1;
          break;
        }
      }
      current ??= chapters.length;
    }
    return ContinueCard(
      track: track,
      progress: progress,
      onResume: onResume,
      currentChapter: current,
      totalChapters: chapters?.isNotEmpty == true ? chapters!.length : null,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onImport,
    required this.onSearchToggle,
    required this.searchOpen,
    required this.onQuery,
  });

  final VoidCallback onImport;
  final VoidCallback onSearchToggle;
  final bool searchOpen;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.lg,
        Insets.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Library', style: theme.textTheme.displayLarge),
              ),
              _IconBtn(
                icon: searchOpen
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                onTap: onSearchToggle,
              ),
              _IconBtn(icon: Icons.add_rounded, onTap: onImport),
            ],
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: searchOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: Insets.md),
                    child: TextField(
                      autofocus: true,
                      onChanged: onQuery,
                      decoration: InputDecoration(
                        hintText: 'Search title, artist, album',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        isDense: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(Insets.xs),
        child: Icon(icon, size: 24, color: AppColors.accent),
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.current, required this.onPick});
  final LibraryViewMode current;
  final ValueChanged<LibraryViewMode> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.fillTertiary,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in LibraryViewMode.values)
            _ToggleSegment(
              icon: switch (m) {
                LibraryViewMode.list => Icons.view_list_rounded,
                LibraryViewMode.grid => Icons.grid_view_rounded,
                LibraryViewMode.compact => Icons.density_small_rounded,
              },
              tooltip: switch (m) {
                LibraryViewMode.list => 'List view',
                LibraryViewMode.grid => 'Grid view',
                LibraryViewMode.compact => 'Compact view',
              },
              selected: m == current,
              onTap: () => onPick(m),
            ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm - 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.sm - 2),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onSelected});
  final LibrarySort current;
  final ValueChanged<LibrarySort> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<LibrarySort>(
      tooltip: 'Sort',
      initialValue: current,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        _menuItem(LibrarySort.recentlyAdded, 'Recently added'),
        _menuItem(LibrarySort.title, 'Title'),
        _menuItem(LibrarySort.artist, 'Artist'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.fillTertiary,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(current),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _label(LibrarySort s) {
    switch (s) {
      case LibrarySort.recentlyAdded:
        return 'Recent';
      case LibrarySort.title:
        return 'Title';
      case LibrarySort.artist:
        return 'Artist';
    }
  }

  PopupMenuItem<LibrarySort> _menuItem(LibrarySort value, String label) {
    return PopupMenuItem(
      value: value,
      height: 38,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value == current)
            Icon(Icons.check_rounded,
                size: 16, color: AppColors.accent),
        ],
      ),
    );
  }
}
