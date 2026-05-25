import 'package:flutter/material.dart';

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
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 140),
              const SizedBox(height: Insets.xl),
              Text(
                'Your library is empty',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Import your audio files to start listening. Progress syncs '
                'across devices when you sign in.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.lg),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Import audio files'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
