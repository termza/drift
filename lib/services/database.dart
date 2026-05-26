import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Cross-platform SQLite handle.
///
/// Mobile (iOS/Android) uses the default sqflite plugin; desktop (Windows,
/// macOS, Linux) needs the FFI implementation initialized once at startup.
class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;
  Database get db => _db;

  static Future<AppDatabase> open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}${Platform.pathSeparator}audio_listen.db';

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT,
        album TEXT,
        duration_ms INTEGER,
        artwork_path TEXT,
        added_at INTEGER NOT NULL,
        cloud_record_id TEXT,
        cloud_state TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE progress (
        track_id TEXT PRIMARY KEY,
        position_ms INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        current_chapter INTEGER,
        last_paused_at INTEGER,
        FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_tracks_added ON tracks(added_at DESC)');

    await _createFavorites(db);
    await _createChapters(db);
    await _createBookmarks(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int from,
    int to,
  ) async {
    if (from < 2) await _createFavorites(db);
    if (from < 3) {
      await _createChapters(db);
      await _createBookmarks(db);
      await db.execute('ALTER TABLE progress ADD COLUMN current_chapter INTEGER');
      await db.execute('ALTER TABLE progress ADD COLUMN last_paused_at INTEGER');
    }
    if (from < 4) {
      await db.execute('ALTER TABLE tracks ADD COLUMN cloud_record_id TEXT');
      await db.execute('ALTER TABLE tracks ADD COLUMN cloud_state TEXT');
    }
  }

  static Future<void> _createFavorites(Database db) async {
    await db.execute('''
      CREATE TABLE favorites (
        track_id TEXT PRIMARY KEY,
        added_at INTEGER NOT NULL,
        FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_favorites_added ON favorites(added_at DESC)',
    );
  }

  static Future<void> _createChapters(Database db) async {
    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        track_id TEXT NOT NULL,
        idx INTEGER NOT NULL,
        title TEXT,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_chapters_track ON chapters(track_id, idx)',
    );
  }

  static Future<void> _createBookmarks(Database db) async {
    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        track_id TEXT NOT NULL,
        position_ms INTEGER NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_bookmarks_track ON bookmarks(track_id, position_ms)',
    );
  }
}
