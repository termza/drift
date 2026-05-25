import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/track.dart';
import 'database.dart';

/// Owns the user's library of imported tracks.
class LibraryService {
  LibraryService(this._db);
  final AppDatabase _db;

  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.aac',
    '.wav',
    '.flac',
    '.ogg',
    '.opus',
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

  /// Prompt the user to pick audio files, import them, and return the new
  /// tracks (skipping duplicates).
  Future<List<Track>> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _audioExtensions
          .map((e) => e.replaceFirst('.', ''))
          .toList(),
    );
    if (result == null) return const [];

    final added = <Track>[];
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      final t = await _importFile(File(path));
      if (t != null) added.add(t);
    }
    return added;
  }

  Future<Track?> _importFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (!_audioExtensions.contains(ext)) return null;

    final stat = await file.stat();
    final id = _stableId(file.path, stat.size);

    // Skip if we already have this track.
    final existing = await byId(id);
    if (existing != null) return existing;

    String title = p.basenameWithoutExtension(file.path);
    String? artist;
    String? album;
    Duration? duration;
    String? artworkPath;

    try {
      final meta = readMetadata(file, getImage: true);
      final t = (meta.title ?? '').trim();
      if (t.isNotEmpty) title = t;
      final ar = (meta.artist ?? '').trim();
      if (ar.isNotEmpty) artist = ar;
      final al = (meta.album ?? '').trim();
      if (al.isNotEmpty) album = al;
      if (meta.duration != null) duration = meta.duration;
      if (meta.pictures.isNotEmpty) {
        artworkPath = await _saveArtwork(id, meta.pictures.first.bytes);
      }
    } catch (_) {
      // Metadata read failures are non-fatal; we still index the file.
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
    return track;
  }

  Future<void> remove(String trackId) async {
    await _db.db.delete('tracks', where: 'id = ?', whereArgs: [trackId]);
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
}
