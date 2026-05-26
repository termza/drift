/// Persisted playback position for a track. Synced across devices.
///
/// [currentChapter] and [lastPausedAt] are local-only (not yet round-tripped
/// through PocketBase) — they support chapter resume and auto-rewind UX.
class TrackProgress {
  final String trackId;
  final Duration position;
  final DateTime updatedAt;
  final bool completed;
  final int? currentChapter;
  final DateTime? lastPausedAt;

  const TrackProgress({
    required this.trackId,
    required this.position,
    required this.updatedAt,
    this.completed = false,
    this.currentChapter,
    this.lastPausedAt,
  });

  TrackProgress copyWith({
    Duration? position,
    DateTime? updatedAt,
    bool? completed,
    int? currentChapter,
    DateTime? lastPausedAt,
  }) =>
      TrackProgress(
        trackId: trackId,
        position: position ?? this.position,
        updatedAt: updatedAt ?? this.updatedAt,
        completed: completed ?? this.completed,
        currentChapter: currentChapter ?? this.currentChapter,
        lastPausedAt: lastPausedAt ?? this.lastPausedAt,
      );

  Map<String, Object?> toRow() => {
        'track_id': trackId,
        'position_ms': position.inMilliseconds,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'completed': completed ? 1 : 0,
        'current_chapter': currentChapter,
        'last_paused_at': lastPausedAt?.millisecondsSinceEpoch,
      };

  factory TrackProgress.fromRow(Map<String, Object?> row) => TrackProgress(
        trackId: row['track_id'] as String,
        position: Duration(milliseconds: row['position_ms'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        completed: (row['completed'] as int? ?? 0) == 1,
        currentChapter: row['current_chapter'] as int?,
        lastPausedAt: row['last_paused_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['last_paused_at'] as int),
      );
}
