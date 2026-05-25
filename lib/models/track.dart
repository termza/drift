import 'dart:io';

/// A single audio item in the user's library.
///
/// [id] is a stable content hash (filename + size) so the same file imported
/// on iOS and Windows resolves to the same record for cloud sync.
class Track {
  final String id;
  final String filePath;
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final String? artworkPath;
  final DateTime addedAt;

  const Track({
    required this.id,
    required this.filePath,
    required this.title,
    required this.addedAt,
    this.artist,
    this.album,
    this.duration,
    this.artworkPath,
  });

  bool get fileExists => File(filePath).existsSync();

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? artworkPath,
  }) {
    return Track(
      id: id,
      filePath: filePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artworkPath: artworkPath ?? this.artworkPath,
      addedAt: addedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'file_path': filePath,
        'title': title,
        'artist': artist,
        'album': album,
        'duration_ms': duration?.inMilliseconds,
        'artwork_path': artworkPath,
        'added_at': addedAt.millisecondsSinceEpoch,
      };

  factory Track.fromRow(Map<String, Object?> row) {
    final ms = row['duration_ms'] as int?;
    return Track(
      id: row['id'] as String,
      filePath: row['file_path'] as String,
      title: row['title'] as String,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      duration: ms == null ? null : Duration(milliseconds: ms),
      artworkPath: row['artwork_path'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int),
    );
  }
}
