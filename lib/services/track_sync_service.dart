import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ignore: implementation_imports — ClientException is exported via package root
import 'package:pocketbase/pocketbase.dart';
import 'package:sqflite/sqflite.dart';

import '../models/track.dart';
import 'auth_repository.dart';
import 'database.dart';

/// Pushes locally-imported tracks up to PocketBase and pulls the user's
/// cloud catalog down. Files larger than the PB instance's `maxBodySize`
/// will fail to upload — the caller surfaces that as a generic sync error.
///
/// This is a minimum-viable implementation:
/// - Uploads are sequential and fire-and-forget from import.
/// - Downloads are blocking (caller waits and shows UI).
/// - No retry queue, no partial-resume, no artwork sync yet.
class TrackSyncService extends ChangeNotifier {
  TrackSyncService(this._db, this._auth);

  final AppDatabase _db;
  final AuthRepository _auth;

  /// Per-track progress (0.0–1.0) while an upload or download is in flight.
  /// Read by the per-tile sync bar; entries are cleared on completion.
  final Map<String, double> _progressByTrack = {};
  double? progressFor(String trackId) => _progressByTrack[trackId];

  /// Most recent per-track sync failures (newest first). Surfaced in the
  /// Cloud Status screen so silent server-side errors stop being invisible.
  final List<SyncFailure> _recentFailures = [];
  List<SyncFailure> get recentFailures => List.unmodifiable(_recentFailures);
  static const _maxFailures = 20;

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

  /// Summary of the last bulk-sync run, for the "Sync now" snackbar.
  int _lastSyncUploaded = 0;
  int _lastSyncFailed = 0;
  int get lastSyncUploaded => _lastSyncUploaded;
  int get lastSyncFailed => _lastSyncFailed;

  PocketBase get _pb => _auth.pb;
  bool get _signedIn => _auth.isSignedIn;
  String? get _userId => _auth.userId;

  /// Pull the user's track catalog from PocketBase and merge into the local
  /// `tracks` table. Cloud-only entries are inserted with empty `file_path`
  /// and `cloud_state = cloudOnly`; existing local rows that match by
  /// `track_id` just get their `cloud_record_id` filled in.
  ///
  /// Best-effort: swallows network errors so the library still loads.
  Future<void> pullCatalog() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final records = await _pb.collection('tracks').getFullList(
            filter: 'user = "$uid"',
            batch: 200,
          );

      for (final r in records) {
        final trackId = r.data['track_id'] as String?;
        if (trackId == null) continue;

        final existingRows = await _db.db.query(
          'tracks',
          where: 'id = ?',
          whereArgs: [trackId],
          limit: 1,
        );

        if (existingRows.isNotEmpty) {
          // Local copy already exists — just remember the cloud id and bump
          // state to 'uploaded' if it was previously local-only.
          final existing = Track.fromRow(existingRows.first);
          if (existing.cloudRecordId == r.id &&
              existing.cloudState == TrackCloudState.uploaded) {
            continue;
          }
          await _db.db.update(
            'tracks',
            {
              'cloud_record_id': r.id,
              'cloud_state': existing.isLocal
                  ? TrackCloudState.uploaded.name
                  : TrackCloudState.cloudOnly.name,
            },
            where: 'id = ?',
            whereArgs: [trackId],
          );
        } else {
          // New catalog entry — insert as cloud-only.
          final durationMs = (r.data['duration_ms'] as num?)?.toInt();
          final addedAt = DateTime.now().millisecondsSinceEpoch;
          await _db.db.insert(
            'tracks',
            {
              'id': trackId,
              'file_path': '',
              'title': (r.data['title'] as String?) ?? trackId,
              'artist': r.data['artist'] as String?,
              'album': r.data['album'] as String?,
              'duration_ms': durationMs,
              'artwork_path': null,
              'added_at': addedAt,
              'cloud_record_id': r.id,
              'cloud_state': TrackCloudState.cloudOnly.name,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    } catch (_) {
      // Best-effort. Catalog pulls happen in the background; UI is unaffected.
    }
  }

  /// Upload a freshly-imported local track to PocketBase. Sets cloud_state
  /// to [TrackCloudState.uploading] for the duration, then [uploaded] on
  /// success or [failed] on error.
  ///
  /// Skips silently when not signed in or when the track is already uploaded.
  Future<void> uploadIfLocal(Track track) async {
    if (!_signedIn) return;
    if (!track.isLocal) return;
    if (track.cloudState == TrackCloudState.uploaded ||
        track.cloudState == TrackCloudState.uploading) {
      return;
    }
    final uid = _userId;
    if (uid == null) return;

    final file = File(track.filePath);
    if (!await file.exists()) return;

    await _setState(track.id, TrackCloudState.uploading);

    try {
      final ext = p.extension(track.filePath).replaceFirst('.', '');
      final fileSize = await file.length();

      final files = <http.MultipartFile>[
        await http.MultipartFile.fromPath('file', track.filePath),
      ];
      if (track.artworkPath != null &&
          File(track.artworkPath!).existsSync()) {
        files.add(
          await http.MultipartFile.fromPath('artwork', track.artworkPath!),
        );
      }

      final body = <String, dynamic>{
        'user': uid,
        'track_id': track.id,
        'title': track.title,
        if (track.artist != null) 'artist': track.artist,
        if (track.album != null) 'album': track.album,
        if (track.duration != null)
          'duration_ms': track.duration!.inMilliseconds,
        'file_size': fileSize,
        'file_ext': ext,
        'client_updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final created = await _pb.collection('tracks').create(
            body: body,
            files: files,
          );

      await _db.db.update(
        'tracks',
        {
          'cloud_record_id': created.id,
          'cloud_state': TrackCloudState.uploaded.name,
        },
        where: 'id = ?',
        whereArgs: [track.id],
      );
      notifyListeners();
    } catch (e) {
      final reason = e is ClientException
          ? 'HTTP ${e.statusCode}: ${e.response['message'] ?? e.toString()}'
          : e.toString();
      _recordFailure(track.id, track.title, reason);
      await _setState(track.id, TrackCloudState.failed);
    }
  }

  /// Resolve the PocketBase file URL for a cloud-backed track. Returns null
  /// when the track has no cloud record or the lookup fails. Callers can
  /// hand the URL straight to `AudioSource.uri()` for HTTP streaming
  /// instead of force-downloading the whole file before play.
  Future<Uri?> streamUrl(Track track) async {
    if (track.cloudRecordId == null) return null;
    try {
      final record =
          await _pb.collection('tracks').getOne(track.cloudRecordId!);
      final fileName = record.data['file'] as String?;
      if (fileName == null || fileName.isEmpty) return null;
      return _pb.files.getUrl(record, fileName);
    } catch (_) {
      return null;
    }
  }

  /// Delete the cloud record for a track. Local file/row are not touched —
  /// the caller decides whether to keep or also remove the local copy.
  /// Returns true on success (or no-op when there's nothing to delete).
  Future<bool> deleteRemote(Track track) async {
    if (track.cloudRecordId == null) return true;
    if (!_signedIn) return false;
    try {
      await _pb.collection('tracks').delete(track.cloudRecordId!);
      await _db.db.update(
        'tracks',
        {
          'cloud_record_id': null,
          'cloud_state': TrackCloudState.localOnly.name,
        },
        where: 'id = ?',
        whereArgs: [track.id],
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete the locally cached file for a cloud-backed track. The row stays
  /// in the library as cloud-only so the user can re-download later.
  /// For tracks without a cloud copy, the row is deleted entirely.
  Future<void> deleteLocalCopy(Track track) async {
    if (track.filePath.isNotEmpty) {
      try {
        final f = File(track.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (track.cloudRecordId == null) {
      // No cloud backup — drop the row entirely; otherwise tile would be
      // orphaned with no playable source.
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

  /// Download a cloud-only track's file to local storage. Returns the local
  /// path on success; throws on failure (so the caller can show an error).
  Future<String> downloadFile(Track track) async {
    if (track.cloudRecordId == null) {
      throw StateError('Track ${track.id} has no cloud record');
    }
    await _setState(track.id, TrackCloudState.downloading);

    try {
      final record = await _pb
          .collection('tracks')
          .getOne(track.cloudRecordId!);
      final fileName = record.data['file'] as String?;
      if (fileName == null || fileName.isEmpty) {
        throw StateError('Cloud record has no file');
      }

      final url = _pb.files.getURL(record, fileName).toString();
      final localPath = await _localPathFor(track.id, fileName);

      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 400) {
        throw HttpException(
          'Download failed (${response.statusCode})',
          uri: Uri.parse(url),
        );
      }

      final out = File(localPath);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(response.bodyBytes);

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

  /// Public so callers that *do* know byte-level progress (future
  /// streamed-multipart upload, chunked download) can drive the per-tile bar.
  /// The sync bar shows an indeterminate sweep when no value has been set.
  // ignore: use_setters_to_change_properties
  void setProgress(String trackId, double fraction) {
    _progressByTrack[trackId] = fraction.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<String> _localPathFor(String trackId, String pbFileName) async {
    final dir = await getApplicationSupportDirectory();
    final ext = p.extension(pbFileName);
    final synced = Directory(p.join(dir.path, 'synced_tracks'));
    if (!await synced.exists()) await synced.create(recursive: true);
    return p.join(synced.path, '$trackId$ext');
  }

  /// Walk the local tracks table and push anything that's still
  /// [TrackCloudState.localOnly] up to the server. Records counts so the
  /// "Sync now" snackbar can report progress.
  Future<void> syncAllLocal() async {
    if (!_signedIn) {
      _lastSyncUploaded = 0;
      _lastSyncFailed = 0;
      return;
    }
    final rows = await _db.db.query(
      'tracks',
      where: 'cloud_state = ? OR cloud_state IS NULL',
      whereArgs: [TrackCloudState.localOnly.name],
    );
    var uploaded = 0;
    var failed = 0;
    for (final row in rows) {
      final t = Track.fromRow(row);
      if (!t.isLocal) continue;
      final before = _recentFailures.length;
      await uploadIfLocal(t);
      // Refresh from DB to see the resulting state.
      final after = await _db.db
          .query('tracks', where: 'id = ?', whereArgs: [t.id], limit: 1);
      if (after.isNotEmpty) {
        final state = (after.first['cloud_state'] as String?) ?? '';
        if (state == TrackCloudState.uploaded.name) {
          uploaded++;
        } else if (_recentFailures.length > before) {
          failed++;
        }
      }
    }
    _lastSyncUploaded = uploaded;
    _lastSyncFailed = failed;
    notifyListeners();
  }

  /// Total bytes currently held in the synced-tracks cache directory. Cheap
  /// non-recursive scan — synced files are flat under one directory.
  /// How many local tracks haven't been pushed up yet. Drives the UI hint
  /// "12 tracks pending sync".
  Future<int> pendingUploadCount() async {
    final rows = await _db.db.query(
      'tracks',
      where:
          'file_path != "" AND (cloud_state = ? OR cloud_state IS NULL OR cloud_state = ?)',
      whereArgs: [
        TrackCloudState.localOnly.name,
        TrackCloudState.failed.name,
      ],
    );
    return rows.length;
  }

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
