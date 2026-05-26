import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'glass_panel.dart';

/// Desktop left rail. Matches the mockup: "DRIFT: Your Cloud" brand on top,
/// nav items in the middle (Library, Playlists, Favorites, Offline Cache),
/// Settings near the bottom, and a CLOUD STATUS info panel at the very
/// bottom showing the connected node + sync state.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);
    final favs = ref.watch(favoritesProvider).maybeWhen(
          data: (s) => s.length,
          orElse: () => 0,
        );
    final lib = ref.watch(libraryProvider).maybeWhen(
          data: (t) => t.length,
          orElse: () => 0,
        );

    return Container(
      width: compact ? 76 : 236,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: GlassPanel(
        borderRadius: BorderRadius.zero,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 22,
                  Insets.lg,
                  Insets.md,
                  Insets.md,
                ),
                child: _Brand(compact: compact),
              ),
              const SizedBox(height: 4),
              _NavItem(
                icon: Icons.library_music_outlined,
                activeIcon: Icons.library_music_rounded,
                label: 'Library',
                count: lib,
                selected: section == AppSection.library,
                compact: compact,
                onTap: () => ref
                    .read(currentSectionProvider.notifier)
                    .state = AppSection.library,
              ),
              _NavItem(
                icon: Icons.queue_music_rounded,
                activeIcon: Icons.queue_music_rounded,
                label: 'Playlists',
                selected: section == AppSection.playlists,
                compact: compact,
                onTap: () => ref
                    .read(currentSectionProvider.notifier)
                    .state = AppSection.playlists,
              ),
              _NavItem(
                icon: Icons.favorite_outline_rounded,
                activeIcon: Icons.favorite_rounded,
                label: 'Favorites',
                count: favs,
                selected: section == AppSection.favorites,
                compact: compact,
                onTap: () => ref
                    .read(currentSectionProvider.notifier)
                    .state = AppSection.favorites,
              ),
              _NavItem(
                icon: Icons.cloud_outlined,
                activeIcon: Icons.cloud_rounded,
                label: 'Offline Cache',
                selected: section == AppSection.cloudStatus,
                compact: compact,
                onTap: () => ref
                    .read(currentSectionProvider.notifier)
                    .state = AppSection.cloudStatus,
              ),
              const Spacer(),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'System Settings',
                selected: section == AppSection.settings,
                compact: compact,
                onTap: () => ref
                    .read(currentSectionProvider.notifier)
                    .state = AppSection.settings,
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _CloudStatusPanel(),
                ),
              ] else
                const SizedBox(height: Insets.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return const BrandMark(size: 36, glow: true);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 28, glow: true),
        const SizedBox(width: 10),
        Flexible(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(
                  text: 'DRIFT',
                  style: TextStyle(color: AppColors.accent),
                ),
                const TextSpan(text: ': Your Cloud'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CloudStatusPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final connected = auth.isSignedIn;
    final host = _hostFromUrl(auth.serverUrl);
    return GlassPanel(
      borderRadius: BorderRadius.circular(Radii.sm + 2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CLOUD STATUS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
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
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connected ? 'Node: $host' : 'Offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Text(
                connected ? 'Synced' : 'Sign in to sync',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.count = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int count;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Stack(
            children: [
              // Left accent bar for the selected item — matches mockup
              if (selected && !compact)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Row(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(
                      selected ? activeIcon : icon,
                      size: 20,
                      color: selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: selected
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '$count',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
