import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../models/chapter.dart';
import 'database.dart';

/// Parses chapter metadata from audio files and persists it.
///
/// Supported sources, in priority order:
///   1. MP4 `moov.udta.chpl` (Nero-style chapter list — most common in
///      mp4chaps-produced M4B files and Audible rips).
///   2. Sidecar `<basename>.chapters.txt` (Audacity-style: `HH:MM:SS.mmm\tTitle`).
///   3. Sidecar `<basename>.cue` (CUE sheet).
///
/// Returns an empty list rather than throwing when nothing is found, so the
/// import path can fall through silently.
class ChapterService {
  ChapterService(this._db);
  final AppDatabase _db;

  Future<List<Chapter>> listForTrack(String trackId) async {
    final rows = await _db.db.query(
      'chapters',
      where: 'track_id = ?',
      whereArgs: [trackId],
      orderBy: 'idx ASC',
    );
    return rows.map(Chapter.fromRow).toList();
  }

  Future<bool> hasChapters(String trackId) async {
    final rows = await _db.db.rawQuery(
      'SELECT 1 FROM chapters WHERE track_id = ? LIMIT 1',
      [trackId],
    );
    return rows.isNotEmpty;
  }

  Future<void> save(String trackId, List<Chapter> chapters) async {
    final batch = _db.db.batch();
    batch.delete('chapters', where: 'track_id = ?', whereArgs: [trackId]);
    for (final c in chapters) {
      batch.insert(
        'chapters',
        c.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteForTrack(String trackId) async {
    await _db.db.delete('chapters', where: 'track_id = ?', whereArgs: [trackId]);
  }

  /// Parse chapters from any supported container. Always returns — never
  /// throws — so callers can use it inline during import.
  Future<List<Chapter>> parseFromFile({
    required String trackId,
    required File file,
    required Duration? trackDuration,
  }) async {
    final lower = file.path.toLowerCase();
    try {
      if (lower.endsWith('.m4b') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.mov')) {
        final mp4 = _parseMp4(trackId, file, trackDuration);
        if (mp4.isNotEmpty) return mp4;
      }
    } catch (_) {
      // Fall through to sidecar attempts.
    }
    try {
      return _parseSidecar(trackId, file, trackDuration);
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // MP4 chpl parsing
  // ---------------------------------------------------------------------------

  List<Chapter> _parseMp4(
    String trackId,
    File file,
    Duration? trackDuration,
  ) {
    final raf = file.openSync();
    try {
      final size = raf.lengthSync();
      final chpl = _findAtom(raf, 0, size, ['moov', 'udta', 'chpl']);
      if (chpl == null || chpl.isEmpty) return const [];
      return _decodeChpl(trackId, chpl, trackDuration);
    } finally {
      raf.closeSync();
    }
  }

  /// Walks the MP4 atom tree to locate a nested atom by [path]. Returns the
  /// raw payload bytes (header stripped) or `null` if not present.
  Uint8List? _findAtom(
    RandomAccessFile raf,
    int start,
    int end,
    List<String> path,
  ) {
    if (path.isEmpty) return null;
    var pos = start;
    final target = path.first;
    while (pos + 8 <= end) {
      raf.setPositionSync(pos);
      final header = raf.readSync(8);
      if (header.length < 8) return null;
      var size = _u32(header, 0);
      final type = String.fromCharCodes(header.sublist(4, 8));
      var headerSize = 8;
      if (size == 1) {
        final ext = raf.readSync(8);
        if (ext.length < 8) return null;
        size = _u64(ext, 0);
        headerSize = 16;
      } else if (size == 0) {
        size = end - pos;
      }
      if (size < headerSize || pos + size > end) return null;
      if (type == target) {
        final innerLen = size - headerSize;
        if (path.length == 1) {
          raf.setPositionSync(pos + headerSize);
          return Uint8List.fromList(raf.readSync(innerLen));
        }
        return _findAtom(
          raf,
          pos + headerSize,
          pos + size,
          path.sublist(1),
        );
      }
      pos += size;
    }
    return null;
  }

  /// chpl payload layout:
  ///   v0: [version:1][flags:3][count:1][entries...]
  ///   v1: [version:1][flags:3][reserved:4][count:1][entries...]
  /// Each entry: [timestamp_100ns:8][title_len:1][title:title_len]
  List<Chapter> _decodeChpl(
    String trackId,
    Uint8List data,
    Duration? trackDuration,
  ) {
    if (data.length < 5) return const [];
    final version = data[0];
    var off = 4; // version + flags
    if (version == 1) {
      if (data.length < off + 5) return const [];
      off += 4; // reserved
    }
    final count = data[off];
    off += 1;

    final raw = <_RawChapter>[];
    for (var i = 0; i < count; i++) {
      if (off + 9 > data.length) break;
      final ts100ns = _u64(data, off);
      off += 8;
      final titleLen = data[off];
      off += 1;
      if (off + titleLen > data.length) break;
      String? title;
      try {
        title = utf8.decode(data.sublist(off, off + titleLen)).trim();
      } catch (_) {
        title = String.fromCharCodes(data.sublist(off, off + titleLen)).trim();
      }
      if (title.isEmpty) title = null;
      off += titleLen;
      raw.add(_RawChapter(
        start: Duration(microseconds: ts100ns ~/ 10),
        title: title,
      ));
    }
    return _buildChapters(trackId, raw, trackDuration);
  }

  // ---------------------------------------------------------------------------
  // Sidecar parsing
  // ---------------------------------------------------------------------------

  List<Chapter> _parseSidecar(
    String trackId,
    File file,
    Duration? trackDuration,
  ) {
    final base = file.path.replaceAll(RegExp(r'\.[^.\\/]+$'), '');
    final txt = File('$base.chapters.txt');
    if (txt.existsSync()) {
      final r = _parseChaptersTxt(txt);
      if (r.isNotEmpty) return _buildChapters(trackId, r, trackDuration);
    }
    final cue = File('$base.cue');
    if (cue.existsSync()) {
      final r = _parseCue(cue);
      if (r.isNotEmpty) return _buildChapters(trackId, r, trackDuration);
    }
    return const [];
  }

  static final _txtRe = RegExp(
    r'^\s*(\d+):(\d+):(\d+)(?:\.(\d+))?\s+(.*)$',
  );

  List<_RawChapter> _parseChaptersTxt(File file) {
    final out = <_RawChapter>[];
    for (final line in file.readAsLinesSync()) {
      final m = _txtRe.firstMatch(line);
      if (m == null) continue;
      final h = int.parse(m.group(1)!);
      final mi = int.parse(m.group(2)!);
      final s = int.parse(m.group(3)!);
      final fracStr = (m.group(4) ?? '0').padRight(3, '0').substring(0, 3);
      final ms = int.parse(fracStr);
      final title = m.group(5)!.trim();
      out.add(_RawChapter(
        start: Duration(hours: h, minutes: mi, seconds: s, milliseconds: ms),
        title: title.isEmpty ? null : title,
      ));
    }
    return out;
  }

  static final _cueIndexRe = RegExp(r'^\s*INDEX\s+01\s+(\d+):(\d+):(\d+)');
  static final _cueTitleRe = RegExp(r'^\s*TITLE\s+"(.*)"');

  List<_RawChapter> _parseCue(File file) {
    final out = <_RawChapter>[];
    String? pending;
    var sawTrack = false;
    for (final line in file.readAsLinesSync()) {
      if (line.trimLeft().startsWith('TRACK')) {
        sawTrack = true;
        pending = null;
        continue;
      }
      final tm = _cueTitleRe.firstMatch(line);
      if (tm != null && sawTrack) {
        pending = tm.group(1);
        continue;
      }
      final im = _cueIndexRe.firstMatch(line);
      if (im != null && sawTrack) {
        final mi = int.parse(im.group(1)!);
        final s = int.parse(im.group(2)!);
        final frames = int.parse(im.group(3)!);
        final ms = (frames * 1000) ~/ 75; // CD frames @ 75/sec
        out.add(_RawChapter(
          start: Duration(minutes: mi, seconds: s, milliseconds: ms),
          title: pending,
        ));
        pending = null;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<Chapter> _buildChapters(
    String trackId,
    List<_RawChapter> raw,
    Duration? trackDuration,
  ) {
    if (raw.isEmpty) return const [];
    raw.sort((a, b) => a.start.compareTo(b.start));
    final endTotal = trackDuration ?? Duration.zero;
    return [
      for (var i = 0; i < raw.length; i++)
        Chapter(
          id: '${trackId}_$i',
          trackId: trackId,
          index: i,
          title: raw[i].title,
          start: raw[i].start,
          end: i + 1 < raw.length ? raw[i + 1].start : endTotal,
        ),
    ];
  }

  int _u32(List<int> b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  // Dart ints are 64-bit signed; audio atoms never approach 2^63.
  int _u64(List<int> b, int o) {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v = (v << 8) | b[o + i];
    }
    return v;
  }
}

class _RawChapter {
  final Duration start;
  final String? title;
  const _RawChapter({required this.start, this.title});
}
