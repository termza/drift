import 'package:sqflite/sqflite.dart';

import '../models/playback_state.dart';
import 'database.dart';

/// Local source of truth for playback positions. The [SyncService] reconciles
/// this with the cloud when online; reads/writes here never block on network.
class ProgressStore {
  ProgressStore(this._db);
  final AppDatabase _db;

  Future<TrackProgress?> get(String trackId) async {
    final rows = await _db.db.query(
      'progress',
      where: 'track_id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TrackProgress.fromRow(rows.first);
  }

  Future<Map<String, TrackProgress>> getAll() async {
    final rows = await _db.db.query('progress');
    return {
      for (final r in rows) r['track_id'] as String: TrackProgress.fromRow(r),
    };
  }

  Future<void> save(TrackProgress progress) async {
    await _db.db.insert(
      'progress',
      progress.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markCompleted(String trackId) async {
    await save(TrackProgress(
      trackId: trackId,
      position: Duration.zero,
      updatedAt: DateTime.now(),
      completed: true,
    ));
  }
}
