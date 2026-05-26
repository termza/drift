import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Placeholder destination so the sidebar's "Playlists" entry has somewhere
/// to land. Real playlist support is on the roadmap (Phase 2) — for now this
/// just communicates "coming soon".
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Playlists', style: theme.textTheme.displayLarge),
              const SizedBox(height: Insets.xs),
              Text(
                'Organize tracks into custom collections',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 64,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Coming soon',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Playlists will let you queue mixed audiobook +\n'
                      'music sessions and pin "up next" lists.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
