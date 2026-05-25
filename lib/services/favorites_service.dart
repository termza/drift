import 'database.dart';

/// Heart/star toggle per track. Persistence lives in SQLite; the
/// favoritesProvider streams the current set to the UI.
class FavoritesService {
  FavoritesService(this._db);
  final AppDatabase _db;

  Future<Set<String>> all() async {
    final rows = await _db.db.query('favorites', orderBy: 'added_at DESC');
    return {for (final r in rows) r['track_id'] as String};
  }

  Future<List<String>> orderedIds() async {
    final rows = await _db.db.query('favorites', orderBy: 'added_at DESC');
    return [for (final r in rows) r['track_id'] as String];
  }

  Future<bool> isFavorite(String trackId) async {
    final rows = await _db.db.query(
      'favorites',
      where: 'track_id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> add(String trackId) async {
    await _db.db.insert(
      'favorites',
      {
        'track_id': trackId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> remove(String trackId) async {
    await _db.db.delete(
      'favorites',
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }

  Future<bool> toggle(String trackId) async {
    final fav = await isFavorite(trackId);
    if (fav) {
      await remove(trackId);
    } else {
      await add(trackId);
    }
    return !fav;
  }
}
