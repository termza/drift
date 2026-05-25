import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/settings_screen.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';

/// Left-rail navigation in the Spotify style. Brand + primary destinations.
/// Compact (icon-only) variant available for narrow desktop widths.
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
      width: compact ? 76 : 232,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
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
                Insets.lg,
              ),
              child: _Brand(compact: compact),
            ),
            const SizedBox(height: Insets.xs),
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
            const Spacer(),
            _SettingsItem(compact: compact),
            const SizedBox(height: Insets.sm),
          ],
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
      children: [
        const BrandMark(size: 32, glow: true),
        const SizedBox(width: Insets.sm),
        Text(
          'Drift',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: 2,
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : Insets.sm,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              const Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.textSecondary,
              ),
              if (!compact) ...[
                const SizedBox(width: Insets.sm),
                Text(
                  'Settings',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.count,
    required this.selected,
    required this.compact,
    required this.onTap,
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
        horizontal: Insets.sm,
        vertical: 2,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : Insets.sm,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.fillTertiary
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
                size: 22,
                color: selected
                    ? AppColors.accent
                    : AppColors.textPrimary,
              ),
              if (!compact) ...[
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
