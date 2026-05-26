import 'dart:io';

/// Where a track lives relative to the local device + the cloud.
///
/// - [localOnly]: only on this device; not yet uploaded.
/// - [uploading]: local file, upload to PocketBase in progress.
/// - [uploaded]: present locally AND in the cloud (cloud_record_id is set).
/// - [cloudOnly]: present in the cloud catalog, not yet downloaded locally.
/// - [downloading]: user requested a download, in flight.
/// - [failed]: last sync operation failed; can be retried.
enum TrackCloudState {
  localOnly,
  uploading,
  uploaded,
  cloudOnly,
  downloading,
  failed,
}

/// A single audio item in the user's library.
///
/// [id] is a stable content hash (filename + size) so the same file imported
/// on iOS and Windows resolves to the same record for cloud sync.
///
/// [filePath] is empty for cloud-only tracks (catalog entries that haven't
/// been downloaded to this device yet). Use [isLocal] to branch UI/playback.
class Track {
  final String id;
  final String filePath;
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final String? artworkPath;
  final DateTime addedAt;

  /// PocketBase record id if this track has been synced (either pushed up
  /// from this device or pulled down from the catalog). null = not synced.
  final String? cloudRecordId;
  final TrackCloudState cloudState;

  const Track({
    required this.id,
    required this.filePath,
    required this.title,
    required this.addedAt,
    this.artist,
    this.album,
    this.duration,
    this.artworkPath,
    this.cloudRecordId,
    this.cloudState = TrackCloudState.localOnly,
  });

  /// True if we have a usable local copy to play. False for cloud-only or
  /// downloading entries — those need a download first.
  bool get isLocal => filePath.isNotEmpty;
  bool get isCloudOnly => cloudState == TrackCloudState.cloudOnly;
  bool get isDownloading => cloudState == TrackCloudState.downloading;
  bool get isUploading => cloudState == TrackCloudState.uploading;

  bool get fileExists => filePath.isNotEmpty && File(filePath).existsSync();

  /// Best-effort audiobook detection from the file extension. M4B is the
  /// standard audiobook container. Other long-form formats fall through to
  /// "music" — this is a display heuristic, not a guarantee.
  bool get isAudiobook => filePath.toLowerCase().endsWith('.m4b');

  Track copyWith({
    String? filePath,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? artworkPath,
    String? cloudRecordId,
    TrackCloudState? cloudState,
  }) {
    return Track(
      id: id,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artworkPath: artworkPath ?? this.artworkPath,
      addedAt: addedAt,
      cloudRecordId: cloudRecordId ?? this.cloudRecordId,
      cloudState: cloudState ?? this.cloudState,
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
        'cloud_record_id': cloudRecordId,
        'cloud_state': cloudState.name,
      };

  factory Track.fromRow(Map<String, Object?> row) {
    final ms = row['duration_ms'] as int?;
    final stateName = row['cloud_state'] as String?;
    return Track(
      id: row['id'] as String,
      filePath: row['file_path'] as String? ?? '',
      title: row['title'] as String,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      duration: ms == null ? null : Duration(milliseconds: ms),
      artworkPath: row['artwork_path'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int),
      cloudRecordId: row['cloud_record_id'] as String?,
      cloudState: TrackCloudState.values.firstWhere(
        (e) => e.name == stateName,
        orElse: () => TrackCloudState.localOnly,
      ),
    );
  }
}
