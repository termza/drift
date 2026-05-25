/// Persisted playback position for a track. Synced across devices.
class TrackProgress {
  final String trackId;
  final Duration position;
  final DateTime updatedAt;
  final bool completed;

  const TrackProgress({
    required this.trackId,
    required this.position,
    required this.updatedAt,
    this.completed = false,
  });

  Map<String, Object?> toRow() => {
        'track_id': trackId,
        'position_ms': position.inMilliseconds,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'completed': completed ? 1 : 0,
      };

  factory TrackProgress.fromRow(Map<String, Object?> row) => TrackProgress(
        trackId: row['track_id'] as String,
        position: Duration(milliseconds: row['position_ms'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        completed: (row['completed'] as int? ?? 0) == 1,
      );
}
