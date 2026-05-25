import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';

class EmptyLibrary extends StatelessWidget {
  const EmptyLibrary({super.key, required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.gutter,
            Insets.gutter,
            Insets.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 140, glow: true),
              const SizedBox(height: Insets.xl),
              Text(
                'Your library is empty',
                style: theme.textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Import audio from your device. Progress syncs across '
                'signed-in devices.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.lg),
              FilledButton(
                onPressed: onImport,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Insets.sm),
                  child: Text('Import audio'),
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'MP3, M4A, FLAC, WAV, OGG, OPUS',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
