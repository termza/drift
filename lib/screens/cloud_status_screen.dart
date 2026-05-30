import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../services/track_sync_service.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_panel.dart';

/// Cloud Status / Offline Cache destination. Surfaces connection health,
/// sync stats, and the currently-cached files so the user can manage
/// what's taking up local space.
class CloudStatusScreen extends ConsumerWidget {
  const CloudStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final libraryAsync = ref.watch(libraryProvider);
    final cacheBytes = ref.watch(cacheSizeProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 0,
        );
    final sync = ref.watch(trackSyncServiceProvider);
    final failures = sync.recentFailures;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.md,
                  Insets.gutter,
                  Insets.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud Status', style: theme.textTheme.displayLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Your sync node + offline cache.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.md,
                  Insets.gutter,
                  0,
                ),
                child: _ConnectionCard(
                  connected: auth.isSignedIn,
                  host: _hostFromUrl(auth.serverUrl),
                  email: auth.userEmail,
                  onSync: auth.isSignedIn
                      ? () async {
                          final s = ref.read(trackSyncServiceProvider);
                          await s.pullCatalog();
                          ref.invalidate(libraryProvider);
                          ref.invalidate(cacheSizeProvider);
                          if (context.mounted) {
                            final seen = s.lastSyncSeen;
                            final added = s.lastSyncAdded;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added == 0
                                      ? 'In sync — $seen tracks on server.'
                                      : 'Found $added new track${added == 1 ? "" : "s"} (server has $seen).',
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.md,
                  Insets.gutter,
                  0,
                ),
                child: libraryAsync.maybeWhen(
                  data: (tracks) => _StatsRow(
                    tracks: tracks,
                    cacheBytes: cacheBytes,
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.xl,
                  Insets.gutter,
                  Insets.sm,
                ),
                child: Text(
                  'CACHED FOR OFFLINE USE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            libraryAsync.maybeWhen(
              data: (tracks) {
                final cached = tracks.where((t) => t.isLocal).toList();
                if (cached.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.gutter,
                        vertical: Insets.lg,
                      ),
                      child: Text(
                        'Nothing cached yet. Import or download a track to '
                        'see it here.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.gutter,
                  ),
                  sliver: SliverList.separated(
                    itemCount: cached.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CachedTile(track: cached[i]),
                  ),
                );
              },
              orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            if (failures.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    Insets.xl,
                    Insets.gutter,
                    Insets.sm,
                  ),
                  child: Text(
                    'RECENT SYNC FAILURES',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                sliver: SliverList.separated(
                  itemCount: failures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _FailureTile(failure: failures[i]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  String _hostFromUrl(String url) {
    try {
      final u = Uri.parse(url);
      final port = u.hasPort && u.port != 80 && u.port != 443 ? ':${u.port}' : '';
      final h = '${u.host}$port';
      return h.isEmpty ? url : h;
    } catch (_) {
      return url;
    }
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connected,
    required this.host,
    required this.email,
    required this.onSync,
  });

  final bool connected;
  final String host;
  final String? email;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0xFF34D399)
                    : AppColors.textTertiary,
                shape: BoxShape.circle,
                boxShadow: connected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF34D399)
                              .withValues(alpha: 0.55),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    connected ? 'Node: $host' : 'Offline',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? (email == null
                            ? 'Signed in · Synced'
                            : '$email · Synced')
                        : 'Sign in to sync across devices',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onSync != null)
              TextButton.icon(
                onPressed: onSync,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
                label: Text(
                  'Sync now',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.tracks, required this.cacheBytes});
  final List<Track> tracks;
  final int cacheBytes;

  @override
  Widget build(BuildContext context) {
    final total = tracks.length;
    final synced = tracks
        .where((t) => t.cloudState == TrackCloudState.uploaded)
        .length;
    final cloudOnly = tracks
        .where((t) => t.cloudState == TrackCloudState.cloudOnly)
        .length;
    return Row(
      children: [
        Expanded(
          child: _StatTile(label: 'TOTAL', value: '$total'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(label: 'SYNCED', value: '$synced'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(label: 'CLOUD ONLY', value: '$cloudOnly'),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _StatTile(label: 'OFFLINE CACHE', value: _fmt(cacheBytes)),
        ),
      ],
    );
  }

  String _fmt(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      borderRadius: BorderRadius.circular(Radii.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureTile extends StatelessWidget {
  const _FailureTile({required this.failure});
  final SyncFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failure.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            failure.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _CachedTile extends ConsumerWidget {
  const _CachedTile({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GlassPanel(
      borderRadius: BorderRadius.circular(Radii.sm + 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          track.isAudiobook
              ? Icons.menu_book_rounded
              : Icons.music_note_rounded,
          color: AppColors.accent,
          size: 22,
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          [
            if ((track.artist ?? '').isNotEmpty) track.artist!,
            _sizeFor(track.filePath),
          ].where((s) => s.isNotEmpty).join('  ·  '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
          tooltip: 'Remove local copy',
          onPressed: () async {
            try {
              final f = File(track.filePath);
              if (await f.exists()) await f.delete();
            } catch (_) {}
            ref.invalidate(cacheSizeProvider);
            ref.invalidate(libraryProvider);
          },
        ),
      ),
    );
  }

  String _sizeFor(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return '';
      final b = f.lengthSync();
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
      if (b < 1024 * 1024 * 1024) {
        return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (_) {
      return '';
    }
  }
}
