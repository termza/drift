import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bookmark.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

Future<void> showBookmarkSheet(BuildContext context, String trackId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    builder: (_) => _BookmarkSheet(trackId: trackId),
  );
}

class _BookmarkSheet extends ConsumerStatefulWidget {
  const _BookmarkSheet({required this.trackId});
  final String trackId;

  @override
  ConsumerState<_BookmarkSheet> createState() => _BookmarkSheetState();
}

class _BookmarkSheetState extends ConsumerState<_BookmarkSheet> {
  Future<void> _addAtCurrent() async {
    final snap = ref.read(playbackSnapshotProvider).valueOrNull;
    final position = snap?.position ?? Duration.zero;

    final note = await _promptNote();
    if (note == null) return; // user cancelled the dialog entirely

    await ref.read(bookmarkServiceProvider).add(
          trackId: widget.trackId,
          position: position,
          note: note.isEmpty ? null : note,
        );
    ref.invalidate(bookmarksForTrackProvider(widget.trackId));
  }

  Future<String?> _promptNote() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Bookmark note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            hintText: 'Optional — leave blank for time-only',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Bookmark b) async {
    await ref.read(bookmarkServiceProvider).remove(b.id);
    ref.invalidate(bookmarksForTrackProvider(widget.trackId));
  }

  Future<void> _jump(Bookmark b) async {
    await ref.read(audioPlayerProvider).seek(b.position);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarksAsync = ref.watch(bookmarksForTrackProvider(widget.trackId));

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
            Row(
              children: [
                Text('Bookmarks', style: theme.textTheme.headlineLarge),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.add_rounded,
                    color: AppColors.accent,
                  ),
                  tooltip: 'Add bookmark at current position',
                  onPressed: _addAtCurrent,
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: bookmarksAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Insets.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Text('Failed: $e', style: theme.textTheme.bodyMedium),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
                      child: Text(
                        'No bookmarks yet. Tap + to add one at the current position.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (_, i) {
                      final b = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.bookmark_rounded,
                          color: AppColors.accent,
                          size: 22,
                        ),
                        title: Text(
                          _fmt(b.position),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        subtitle: (b.note != null && b.note!.isNotEmpty)
                            ? Text(b.note!, style: theme.textTheme.bodySmall)
                            : null,
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: () => _delete(b),
                        ),
                        onTap: () => _jump(b),
                      );
                    },
                  );
                },
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
