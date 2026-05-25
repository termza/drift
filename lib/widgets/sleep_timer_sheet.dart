import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bottom sheet for picking a sleep-timer duration. Tapping a chip starts the
/// timer and closes the sheet; the active duration is highlighted.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: (_) => const _SleepTimerSheet(),
  );
}

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  static const _presets = <Duration>[
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timer = ref.watch(sleepTimerProvider);
    final remaining = timer.remaining;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.md,
          Insets.lg,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Text('Sleep Timer', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              timer.isActive && remaining != null
                  ? 'Stops in ${_fmtCompact(remaining)}'
                  : 'Pause playback after…',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.lg),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: [
                for (final d in _presets)
                  _Chip(
                    label: _label(d),
                    selected: timer.isActive &&
                        remaining != null &&
                        _isClose(remaining, d),
                    onTap: () {
                      timer.start(d);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            if (timer.isActive)
              OutlinedButton.icon(
                onPressed: () {
                  timer.cancel();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel timer'),
              ),
          ],
        ),
      ),
    );
  }

  bool _isClose(Duration a, Duration b) =>
      (a.inSeconds - b.inSeconds).abs() < 3;

  String _label(Duration d) {
    if (d.inHours >= 1) {
      return d.inHours == 1 ? '1 hour' : '${d.inHours} hours';
    }
    return '${d.inMinutes} min';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.55)
                : theme.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: selected ? AppColors.accent : null,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

String _fmtCompact(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
  if (d.inMinutes >= 1) {
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }
  return '${d.inSeconds}s';
}
