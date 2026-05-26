/// A chapter within an audiobook or long-form audio file.
///
/// [start] and [end] are positions within the parent track. [end] of
/// [Duration.zero] means "until end of track" — callers that have a known
/// duration should patch the final chapter via [copyWith] before use.
class Chapter {
  final String id;
  final String trackId;
  final int index;
  final String? title;
  final Duration start;
  final Duration end;

  const Chapter({
    required this.id,
    required this.trackId,
    required this.index,
    required this.start,
    required this.end,
    this.title,
  });

  Duration get duration => end > start ? end - start : Duration.zero;

  bool contains(Duration position) {
    if (position < start) return false;
    if (end == Duration.zero) return true;
    return position < end;
  }

  Chapter copyWith({
    String? title,
    Duration? start,
    Duration? end,
  }) =>
      Chapter(
        id: id,
        trackId: trackId,
        index: index,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'track_id': trackId,
        'idx': index,
        'title': title,
        'start_ms': start.inMilliseconds,
        'end_ms': end.inMilliseconds,
      };

  factory Chapter.fromRow(Map<String, Object?> row) => Chapter(
        id: row['id'] as String,
        trackId: row['track_id'] as String,
        index: row['idx'] as int,
        title: row['title'] as String?,
        start: Duration(milliseconds: row['start_ms'] as int),
        end: Duration(milliseconds: row['end_ms'] as int),
      );
}
