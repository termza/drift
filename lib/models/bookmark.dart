/// A user-saved position within a track, optionally annotated.
class Bookmark {
  final String id;
  final String trackId;
  final Duration position;
  final String? note;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.trackId,
    required this.position,
    required this.createdAt,
    this.note,
  });

  Bookmark copyWith({String? note}) => Bookmark(
        id: id,
        trackId: trackId,
        position: position,
        createdAt: createdAt,
        note: note ?? this.note,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'track_id': trackId,
        'position_ms': position.inMilliseconds,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Bookmark.fromRow(Map<String, Object?> row) => Bookmark(
        id: row['id'] as String,
        trackId: row['track_id'] as String,
        position: Duration(milliseconds: row['position_ms'] as int),
        note: row['note'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );
}
