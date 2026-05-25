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
        version: 1,
        onCreate: _onCreate,
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
        added_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE progress (
        track_id TEXT PRIMARY KEY,
        position_ms INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_tracks_added ON tracks(added_at DESC)');
  }
}
