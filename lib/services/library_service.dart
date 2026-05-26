import 'dart:async';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/track.dart';
import '../utils/filename_cleaner.dart';
import 'chapter_service.dart';
import 'database.dart';
import 'import_result.dart';
import 'track_sync_service.dart';

/// Owns the user's library of imported tracks.
class LibraryService {
  LibraryService(this._db, this._chapters, this._sync);
  final AppDatabase _db;
  final ChapterService _chapters;
  final TrackSyncService _sync;

  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.aac',
    '.wav',
    '.flac',
    '.ogg',
    '.opus',
    '.wma',
    '.aiff',
    '.aif',
    '.alac',
    '.mka',
    '.m4r',
  };

  Future<List<Track>> listAll() async {
    final rows = await _db.db.query('tracks', orderBy: 'added_at DESC');
    return rows.map(Track.fromRow).toList();
  }

  Future<Track?> byId(String id) async {
    final rows = await _db.db.query(
      'tracks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Track.fromRow(rows.first);
  }

  /// Prompt the user to pick audio files and import them. Returns a structured
  /// [ImportResult] so the caller can surface skips and per-file failures
  /// instead of silently dropping them.
  Future<ImportResult> pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _audioExtensions
          .map((e) => e.replaceFirst('.', ''))
          .toList(),
    );
    if (picked == null) return const ImportResult();

    final added = <Track>[];
    var skipped = 0;
    final failed = <ImportFailure>[];

    for (final f in picked.files) {
      final path = f.path;
      if (path == null) continue;
      final name = p.basename(path);
      try {
        final file = File(path);
        final ext = p.extension(path).toLowerCase();
        if (!_audioExtensions.contains(ext)) {
          failed.add(ImportFailure(
            fileName: name,
            reason: 'Unsupported format ($ext)',
          ));
          continue;
        }
        if (!await file.exists()) {
          failed.add(ImportFailure(
            fileName: name,
            reason: 'File not found',
          ));
          continue;
        }
        final stat = await file.stat();
        final id = _stableId(file.path, stat.size);

        // On iOS/Android, file_picker hands us a *temporary* path that the OS
        // purges later — playing the track tomorrow would fail with the
        // cryptic AVFoundation -11800 "could not be completed" error. Copy
        // into a persistent app-owned location and use *that* path from now
        // on. Desktop file picks already return stable paths so we skip
        // the copy there to avoid duplicating large M4B files.
        var persistent = file;
        if (Platform.isIOS || Platform.isAndroid) {
          persistent = await _ensurePersistentCopy(file, id);
        }

        // Already in library — count as skipped, *unless* the existing row
        // is a cloud-only catalog entry, in which case this import "adopts"
        // it: we attach the local file_path and flip state to uploaded.
        final existing = await byId(id);
        if (existing != null) {
          if (existing.cloudState == TrackCloudState.cloudOnly) {
            await _db.db.update(
              'tracks',
              {
                'file_path': persistent.path,
                'cloud_state': TrackCloudState.uploaded.name,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            final reloaded = await byId(id);
            if (reloaded != null) added.add(reloaded);
            continue;
          }
          skipped++;
          continue;
        }

        final track = await _importNew(persistent, id);
        added.add(track);
        // Background upload — never blocks import.
        unawaited(_sync.uploadIfLocal(track));
      } catch (e) {
        failed.add(ImportFailure(fileName: name, reason: _shortError(e)));
      }
    }

    return ImportResult(added: added, skipped: skipped, failed: failed);
  }

  Future<Track> _importNew(File file, String id) async {
    final baseName = p.basenameWithoutExtension(file.path);
    String title = baseName;
    String? artist;
    String? album;
    Duration? duration;
    String? artworkPath;
    var titleFromMetadata = false;

    try {
      final meta = readMetadata(file, getImage: true);
      final t = (meta.title ?? '').trim();
      if (t.isNotEmpty) {
        title = t;
        titleFromMetadata = true;
      }
      final ar = (meta.artist ?? '').trim();
      if (ar.isNotEmpty) artist = ar;
      final al = (meta.album ?? '').trim();
      if (al.isNotEmpty) album = al;
      if (meta.duration != null) duration = meta.duration;
      if (meta.pictures.isNotEmpty) {
        artworkPath = await _saveArtwork(id, meta.pictures.first.bytes);
      }
    } catch (_) {
      // Metadata read failures are non-fatal — we still index the file.
    }

    // Filename-cleanup fallback: when metadata is missing, derive title /
    // artist / album from common naming patterns rather than dumping a raw
    // basename in the UI.
    if (!titleFromMetadata || artist == null || album == null) {
      final cleaned = cleanFilename(baseName);
      if (!titleFromMetadata) title = cleaned.title;
      artist ??= cleaned.artist;
      album ??= cleaned.album;
    }

    final track = Track(
      id: id,
      filePath: file.path,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artworkPath: artworkPath,
      addedAt: DateTime.now(),
    );

    await _db.db.insert(
      'tracks',
      track.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Chapter parsing is best-effort and never blocks an import. Failures here
    // just mean the track plays without chapter nav.
    try {
      final chapters = await _chapters.parseFromFile(
        trackId: id,
        file: file,
        trackDuration: duration,
      );
      if (chapters.isNotEmpty) {
        await _chapters.save(id, chapters);
      }
    } catch (_) {}

    return track;
  }

  Future<void> remove(String trackId) async {
    await _db.db.delete('tracks', where: 'id = ?', whereArgs: [trackId]);
  }

  /// Copy a freshly-picked file into a persistent app-owned directory so
  /// iOS doesn't garbage-collect it out from under us. Returns the new file.
  /// Idempotent — re-importing the same content reuses the existing copy.
  Future<File> _ensurePersistentCopy(File src, String trackId) async {
    final dir = await getApplicationSupportDirectory();
    final importsDir = Directory(p.join(dir.path, 'imports'));
    if (!await importsDir.exists()) await importsDir.create(recursive: true);
    final ext = p.extension(src.path).toLowerCase();
    final dest = File(p.join(importsDir.path, '$trackId$ext'));
    if (await dest.exists()) {
      final destLen = await dest.length();
      final srcLen = await src.length();
      if (destLen == srcLen) return dest;
    }
    await src.copy(dest.path);
    return dest;
  }

  Future<String?> _saveArtwork(String trackId, List<int> bytes) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final artDir = Directory(p.join(dir.path, 'artwork'));
      if (!await artDir.exists()) await artDir.create(recursive: true);
      final out = File(p.join(artDir.path, '$trackId.jpg'));
      await out.writeAsBytes(bytes);
      return out.path;
    } catch (_) {
      return null;
    }
  }

  /// Content-addressed ID — same file on two devices yields same key for sync.
  String _stableId(String path, int size) {
    final name = p.basename(path).toLowerCase();
    return '${name}_$size'.hashCode.toRadixString(16).padLeft(8, '0') +
        size.toRadixString(16);
  }

  String _shortError(Object e) {
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 197)}…' : s;
  }
}
