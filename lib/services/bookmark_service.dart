import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/bookmark.dart';
import 'database.dart';

/// CRUD for user-saved positions within a track.
class BookmarkService {
  BookmarkService(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Bookmark>> listForTrack(String trackId) async {
    final rows = await _db.db.query(
      'bookmarks',
      where: 'track_id = ?',
      whereArgs: [trackId],
      orderBy: 'position_ms ASC',
    );
    return rows.map(Bookmark.fromRow).toList();
  }

  Future<int> countForTrack(String trackId) async {
    final rows = await _db.db.rawQuery(
      'SELECT COUNT(*) AS c FROM bookmarks WHERE track_id = ?',
      [trackId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<Bookmark> add({
    required String trackId,
    required Duration position,
    String? note,
  }) async {
    final b = Bookmark(
      id: _uuid.v4(),
      trackId: trackId,
      position: position,
      note: (note != null && note.isEmpty) ? null : note,
      createdAt: DateTime.now(),
    );
    await _db.db.insert(
      'bookmarks',
      b.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return b;
  }

  Future<void> updateNote(String id, String? note) async {
    await _db.db.update(
      'bookmarks',
      {'note': (note != null && note.isEmpty) ? null : note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remove(String id) async {
    await _db.db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}
