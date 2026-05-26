import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pill-style segmented control above the track list: All · Audiobooks ·
/// Music · Downloaded. Selected pill is filled amber with dark ink text;
/// unselected pills are subtle outlined.
class LibraryFilterChips extends ConsumerWidget {
  const LibraryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(libraryFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Row(
        children: [
          for (final f in LibraryFilter.values) ...[
            _FilterChip(
              filter: f,
              selected: f == current,
              onTap: () => ref.read(libraryFilterProvider.notifier).state = f,
            ),
            if (f != LibraryFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final LibraryFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (filter) {
      LibraryFilter.all => 'All',
      LibraryFilter.audiobooks => 'Audiobooks',
      LibraryFilter.music => 'Music',
      LibraryFilter.downloaded => 'Downloaded',
    };
    final trailing = switch (filter) {
      LibraryFilter.downloaded => Icons.cloud_done_outlined,
      LibraryFilter.music => Icons.music_note_rounded,
      LibraryFilter.audiobooks => Icons.menu_book_rounded,
      LibraryFilter.all => null,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: trailing != null ? 12 : 16,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.accentInk : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Icon(
                trailing,
                size: 14,
                color: selected
                    ? AppColors.accentInk
                    : AppColors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
