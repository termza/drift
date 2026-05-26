import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chapter.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

Future<void> showChapterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    builder: (_) => const _ChapterSheet(),
  );
}

class _ChapterSheet extends ConsumerWidget {
  const _ChapterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Watch the index stream so the highlighted row tracks playback live.
    final currentIdx = ref.watch(currentChapterIndexProvider).valueOrNull;
    final player = ref.watch(audioPlayerProvider);
    final chapters = player.currentChapters;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.sm,
            Insets.gutter,
            Insets.md,
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
              Row(
                children: [
                  Text('Chapters', style: theme.textTheme.headlineLarge),
                  const Spacer(),
                  Text(
                    '${chapters.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Flexible(
                child: chapters.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: Insets.xl),
                        child: Text(
                          'No chapters for this track.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: chapters.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 0.5,
                          color: AppColors.borderSubtle,
                        ),
                        itemBuilder: (_, i) {
                          final ch = chapters[i];
                          return _ChapterRow(
                            chapter: ch,
                            isCurrent: i == currentIdx,
                            onTap: () async {
                              await player.seekToChapter(i);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.isCurrent,
    required this.onTap,
  });

  final Chapter chapter;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (chapter.title != null && chapter.title!.isNotEmpty)
        ? chapter.title!
        : 'Chapter ${chapter.index + 1}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: isCurrent
                  ? Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.accent,
                      size: 18,
                    )
                  : Text(
                      '${chapter.index + 1}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              _fmt(chapter.duration),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
