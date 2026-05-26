import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';

/// Bottom-of-library text: "X.X GB Cached for Offline Use" — pulls from
/// [cacheSizeProvider]. Hidden when the cache is empty.
class CacheSizeIndicator extends ConsumerWidget {
  const CacheSizeIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bytes = ref.watch(cacheSizeProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 0,
        );
    if (bytes <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          '${_fmt(bytes)} Cached for Offline Use',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _fmt(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
