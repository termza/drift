import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/track.dart';
import 'auth_repository.dart';
import 'database.dart';
import 'media_server_client.dart';

/// Catalog client for the Drift Media Server. Pulls the server's library
/// down into the local SQLite tracks table as cloud-only rows so the
/// existing library UI can render them uniformly with local imports.
///
/// No uploads — files live on the server's disk, never get copied into
/// the app. Tap-to-play streams from /api/stream/<id> via just_audio,
/// authenticated with the bearer token.
class TrackSyncService extends ChangeNotifier {
  TrackSyncService(this._db, this._auth);

  final AppDatabase _db;
  final AuthRepository _auth;

  MediaServerClient get _client => _auth.client();
  bool get _signedIn => _auth.isSignedIn;

  /// In-flight transfer progress (download fallback, mostly). Per-tile
  /// sync bar reads this to render a determinate fill.
  final Map<String, double> _progressByTrack = {};
  double? progressFor(String trackId) => _progressByTrack[trackId];

  /// Most recent per-track sync failures (newest first). Surfaced in the
  /// Cloud Status screen.
  final List<SyncFailure> _recentFailures = [];
  List<SyncFailure> get recentFailures => List.unmodifiable(_recentFailures);
  static const _maxFailures = 20;

  int _lastSyncSeen = 0;
  int _lastSyncAdded = 0;
  int get lastSyncSeen => _lastSyncSeen;
  int get lastSyncAdded => _lastSyncAdded;

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  /// Fetch the server's library and upsert into the local tracks table.
  /// Existing local-only tracks are left untouched.
  Future<void> pullCatalog() async {
    if (!_signedIn) return;
    final List<MediaServerTrack> remote;
    try {
      remote = await _client.library();
    } catch (e) {
      _recordFailure('catalog', 'Library fetch', e.toString());
      return;
    }
    var added = 0;
    for (final r in remote) {
      // Use the server's id directly as both our local id AND the cloud id.
      final id = r.id;
      final existingRows = await _db.db.query(
        'tracks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        // Keep local file_path if it exists; otherwise refresh metadata
        // from the server's authoritative copy.
        final existing = Track.fromRow(existingRows.first);
        final newState =
            existing.isLocal ? TrackCloudState.uploaded : TrackCloudState.cloudOnly;
        await _db.db.update(
          'tracks',
          {
            'title': r.title,
            'artist': r.artist,
            'album': r.album,
            'duration_ms': r.durationMs,
            'cloud_record_id': id,
            'cloud_state': newState.name,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await _db.db.insert('tracks', {
          'id': id,
          'file_path': '',
          'title': r.title,
          'artist': r.artist,
          'album': r.album,
          'duration_ms': r.durationMs,
          'artwork_path': null,
          'added_at': DateTime.now().millisecondsSinceEpoch,
          'cloud_record_id': id,
          'cloud_state': TrackCloudState.cloudOnly.name,
        });
        added++;
      }
    }
    // Mark cloud-only rows whose server records vanished as failed so the
    // user can see them go red instead of silently disappearing.
    final remoteIds = remote.map((r) => r.id).toSet();
    final cloudRows = await _db.db.query(
      'tracks',
      where: 'cloud_state = ? OR cloud_state = ?',
      whereArgs: [
        TrackCloudState.cloudOnly.name,
        TrackCloudState.uploaded.name,
      ],
    );
    for (final row in cloudRows) {
      final id = row['id'] as String;
      if (remoteIds.contains(id)) continue;
      // Track is no longer on the server. If we have a local copy, demote
      // to localOnly; otherwise drop the row.
      final isLocal = ((row['file_path'] as String?) ?? '').isNotEmpty;
      if (isLocal) {
        await _db.db.update(
          'tracks',
          {
            'cloud_state': TrackCloudState.localOnly.name,
            'cloud_record_id': null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await _db.db.delete('tracks', where: 'id = ?', whereArgs: [id]);
      }
    }
    _lastSyncSeen = remote.length;
    _lastSyncAdded = added;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  /// Build the streaming URL for a cloud-backed track. Returns null when
  /// the track has no server record (local-only) or when we're signed out.
  Future<Uri?> streamUrl(Track track) async {
    if (!_signedIn) return null;
    final id = track.cloudRecordId;
    if (id == null) return null;
    return _client.streamUri(id);
  }

  /// HTTP headers to attach to streaming requests (Bearer auth). Returned
  /// as a regular Map so just_audio's `headers:` parameter accepts it.
  Map<String, String> streamHeaders() => _client.streamHeaders;

  // ---------------------------------------------------------------------------
  // Local-copy management
  // ---------------------------------------------------------------------------

  /// Download a cloud track for offline use. Streams the file into the
  /// synced_tracks cache dir.
  Future<String> downloadFile(Track track) async {
    final id = track.cloudRecordId;
    if (id == null) {
      throw StateError('Track ${track.id} has no server record');
    }
    await _setState(track.id, TrackCloudState.downloading);
    try {
      final uri = _client.streamUri(id);
      final req = HttpClient();
      final r = await req.getUrl(uri);
      final headers = _client.streamHeaders;
      headers.forEach((k, v) => r.headers.set(k, v));
      final resp = await r.close();
      if (resp.statusCode >= 400) {
        throw HttpException(
          'Download failed (${resp.statusCode})',
          uri: uri,
        );
      }
      final localPath = await _localPathFor(track.id, _extOf(uri));
      final out = File(localPath);
      await out.parent.create(recursive: true);
      await resp.pipe(out.openWrite());
      await _db.db.update(
        'tracks',
        {
          'file_path': localPath,
          'cloud_state': TrackCloudState.uploaded.name,
        },
        where: 'id = ?',
        whereArgs: [track.id],
      );
      return localPath;
    } catch (e) {
      await _setState(track.id, TrackCloudState.cloudOnly);
      rethrow;
    }
  }

  /// Delete the locally cached file for a cloud-backed track. The row
  /// stays in the library as cloud-only so the user can re-download.
  /// For tracks without a server record, the row is deleted outright.
  Future<void> deleteLocalCopy(Track track) async {
    if (track.filePath.isNotEmpty) {
      try {
        final f = File(track.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (track.cloudRecordId == null) {
      await _db.db.delete('tracks', where: 'id = ?', whereArgs: [track.id]);
    } else {
      await _db.db.update(
        'tracks',
        {
          'file_path': '',
          'cloud_state': TrackCloudState.cloudOnly.name,
        },
        where: 'id = ?',
        whereArgs: [track.id],
      );
    }
    notifyListeners();
  }

  /// Compatibility shim — used to delete from PocketBase. The media server
  /// doesn't expose a delete endpoint (it's a read-only mirror of disk).
  /// Tell the user the truth instead of silently doing nothing.
  Future<bool> deleteRemote(Track track) async => false;

  /// Compatibility shim — uploads don't exist on the media-server model.
  Future<void> uploadIfLocal(Track _) async {}

  /// Compatibility shim — same.
  Future<void> syncAllLocal() async {}

  /// Total bytes currently held in the synced-tracks cache directory.
  Future<int> cacheSizeBytes() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final synced = Directory(p.join(dir.path, 'synced_tracks'));
      if (!await synced.exists()) return 0;
      var total = 0;
      await for (final entity
          in synced.list(recursive: false, followLinks: false)) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _setState(String trackId, TrackCloudState state) async {
    await _db.db.update(
      'tracks',
      {'cloud_state': state.name},
      where: 'id = ?',
      whereArgs: [trackId],
    );
    if (state != TrackCloudState.uploading &&
        state != TrackCloudState.downloading) {
      _progressByTrack.remove(trackId);
    }
    notifyListeners();
  }

  void _recordFailure(String trackId, String title, String reason) {
    _recentFailures.insert(
      0,
      SyncFailure(
        trackId: trackId,
        title: title,
        reason: reason,
        at: DateTime.now(),
      ),
    );
    while (_recentFailures.length > _maxFailures) {
      _recentFailures.removeLast();
    }
    notifyListeners();
  }

  Future<String> _localPathFor(String trackId, String ext) async {
    final dir = await getApplicationSupportDirectory();
    final synced = Directory(p.join(dir.path, 'synced_tracks'));
    if (!await synced.exists()) await synced.create(recursive: true);
    final safeExt = ext.isEmpty ? '.bin' : (ext.startsWith('.') ? ext : '.$ext');
    return p.join(synced.path, '$trackId$safeExt');
  }

  String _extOf(Uri uri) {
    final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    // Stream URL ends with /api/stream/<id> — no extension. Default to mp3.
    if (!last.contains('.')) return '.mp3';
    final i = last.lastIndexOf('.');
    return last.substring(i);
  }
}

/// One historical sync failure, surfaced in the Cloud Status screen.
class SyncFailure {
  const SyncFailure({
    required this.trackId,
    required this.title,
    required this.reason,
    required this.at,
  });
  final String trackId;
  final String title;
  final String reason;
  final DateTime at;
}
