import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sleep_timer.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
    final player = ref.watch(audioPlayerProvider);
    final hasChapters = player.hasChapters;

    String subtitle;
    if (!timer.isActive) {
      subtitle = 'Pause playback after…';
    } else if (timer.mode == SleepTimerMode.endOfChapter) {
      subtitle = 'Stops at end of current chapter';
    } else if (remaining != null) {
      subtitle = 'Stops in ${_fmtCompact(remaining)}';
    } else {
      subtitle = 'Active';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          Insets.sm,
          Insets.gutter,
          Insets.xl,
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Text('Sleep Timer', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Insets.lg),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: [
                for (final d in _presets)
                  _Chip(
                    label: _label(d),
                    selected: timer.isActive &&
                        timer.mode == SleepTimerMode.duration &&
                        remaining != null &&
                        _isClose(remaining, d),
                    onTap: () {
                      timer.start(d);
                      Navigator.of(context).pop();
                    },
                  ),
                if (hasChapters)
                  _Chip(
                    label: 'End of chapter',
                    selected: timer.isActive &&
                        timer.mode == SleepTimerMode.endOfChapter,
                    onTap: () {
                      final idx = player.currentChapterIndex;
                      if (idx == null) return;
                      timer.startUntilEndOfChapter(
                        idx,
                        player.chapterIndexStream,
                      );
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
            if (timer.isActive) ...[
              const SizedBox(height: Insets.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fillTertiary,
                  foregroundColor: AppColors.danger,
                ),
                onPressed: () {
                  timer.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel timer'),
              ),
            ],
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
      borderRadius: BorderRadius.circular(Radii.sm + 2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
          color: selected ? AppColors.accentSoft : AppColors.fillTertiary,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: selected ? AppColors.accent : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
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
