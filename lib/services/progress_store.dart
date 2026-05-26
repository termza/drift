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

  /// Full-record replace. Used by [SyncService] which carries authoritative
  /// records — overwrites local fields including [TrackProgress.completed].
  Future<void> save(TrackProgress progress) async {
    await _db.db.insert(
      'progress',
      progress.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Periodic position flush. Preserves the existing `last_paused_at` so a
  /// running save doesn't clobber the auto-rewind anchor.
  Future<void> savePosition(
    String trackId,
    Duration position, {
    int? chapter,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, Object?>{
      'position_ms': position.inMilliseconds,
      'updated_at': now,
    };
    if (chapter != null) updates['current_chapter'] = chapter;
    final affected = await _db.db.update(
      'progress',
      updates,
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
    if (affected == 0) {
      await _db.db.insert('progress', {
        'track_id': trackId,
        'position_ms': position.inMilliseconds,
        'updated_at': now,
        'completed': 0,
        'current_chapter': chapter,
        'last_paused_at': null,
      });
    }
  }

  /// Pause flush — stamps `last_paused_at` so the next load can decide
  /// whether to auto-rewind.
  Future<void> markPaused(
    String trackId,
    Duration position, {
    int? chapter,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, Object?>{
      'position_ms': position.inMilliseconds,
      'updated_at': now,
      'last_paused_at': now,
    };
    if (chapter != null) updates['current_chapter'] = chapter;
    final affected = await _db.db.update(
      'progress',
      updates,
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
    if (affected == 0) {
      await _db.db.insert('progress', {
        'track_id': trackId,
        'position_ms': position.inMilliseconds,
        'updated_at': now,
        'completed': 0,
        'current_chapter': chapter,
        'last_paused_at': now,
      });
    }
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
