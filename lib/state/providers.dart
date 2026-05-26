import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../models/playback_state.dart';
import '../models/track.dart';
import '../services/appearance_prefs_service.dart';
import '../services/audio_player_service.dart';
import '../services/auth_repository.dart';
import '../services/bookmark_service.dart';
import '../services/chapter_service.dart';
import '../services/database.dart';
import '../services/embedded_server_service.dart';
import '../services/favorites_service.dart';
import '../services/library_service.dart';
import '../services/playback_prefs_service.dart';
import '../services/pocketbase_backend.dart';
import '../services/progress_store.dart';
import '../services/server_prefs_service.dart';
import '../services/sleep_timer.dart';
import '../services/sync_service.dart';
import '../services/track_sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override in main()');
});

final authRepositoryProvider = ChangeNotifierProvider<AuthRepository>((ref) {
  throw UnimplementedError('Override in main()');
});

final chapterServiceProvider = Provider<ChapterService>((ref) {
  return ChapterService(ref.watch(databaseProvider));
});

final bookmarkServiceProvider = Provider<BookmarkService>((ref) {
  return BookmarkService(ref.watch(databaseProvider));
});

final playbackPrefsServiceProvider =
    ChangeNotifierProvider<PlaybackPrefsService>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final appearancePrefsServiceProvider =
    ChangeNotifierProvider<AppearancePrefsService>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final serverPrefsServiceProvider =
    ChangeNotifierProvider<ServerPrefsService>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final embeddedServerServiceProvider =
    ChangeNotifierProvider<EmbeddedServerService>((ref) {
  final svc = EmbeddedServerService(ref.watch(serverPrefsServiceProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService(
    ref.watch(databaseProvider),
    ref.watch(chapterServiceProvider),
    ref.watch(trackSyncServiceProvider),
  );
});

final progressStoreProvider = Provider<ProgressStore>((ref) {
  return ProgressStore(ref.watch(databaseProvider));
});

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService(ref.watch(databaseProvider));
});

final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  // `read` for prefs — the service listens to the ChangeNotifier directly, so
  // we don't want the provider to rebuild (and dispose the player) on changes.
  final service = AudioPlayerService(
    ref.watch(progressStoreProvider),
    ref.watch(chapterServiceProvider),
    ref.read(playbackPrefsServiceProvider),
    ref.watch(trackSyncServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final bookmarksForTrackProvider =
    FutureProvider.family<List<Bookmark>, String>((ref, trackId) async {
  return ref.watch(bookmarkServiceProvider).listForTrack(trackId);
});

final trackSyncServiceProvider =
    ChangeNotifierProvider<TrackSyncService>((ref) {
  return TrackSyncService(
    ref.watch(databaseProvider),
    ref.watch(authRepositoryProvider),
  );
});

final chaptersForTrackProvider =
    FutureProvider.family<List<Chapter>, String>((ref, trackId) async {
  return ref.watch(chapterServiceProvider).listForTrack(trackId);
});

final currentChapterIndexProvider = StreamProvider<int?>((ref) {
  return ref.watch(audioPlayerProvider).chapterIndexStream;
});

final sleepTimerProvider = ChangeNotifierProvider<SleepTimer>((ref) {
  final player = ref.watch(audioPlayerProvider);
  final timer = SleepTimer(() => player.pause());
  ref.onDispose(timer.dispose);
  return timer;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final store = ref.watch(progressStoreProvider);
  final backend =
      auth.isSignedIn ? PocketBaseBackend(auth) : OfflineBackend();
  final service = SyncService(store, backend);
  ref.onDispose(service.dispose);
  return service;
});

final libraryProvider = FutureProvider<List<Track>>((ref) async {
  return ref.watch(libraryServiceProvider).listAll();
});

final allProgressProvider = FutureProvider<Map<String, TrackProgress>>(
  (ref) async => ref.watch(progressStoreProvider).getAll(),
);

final favoritesProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(favoritesServiceProvider).all();
});

final favoriteTracksProvider = FutureProvider<List<Track>>((ref) async {
  final ids = await ref.watch(favoritesServiceProvider).orderedIds();
  final tracks = await ref.watch(libraryProvider.future);
  final byId = {for (final t in tracks) t.id: t};
  return [for (final id in ids) if (byId.containsKey(id)) byId[id]!];
});

final continueListeningProvider =
    FutureProvider<({Track track, TrackProgress progress})?>((ref) async {
  final tracks = await ref.watch(libraryProvider.future);
  final progress = await ref.watch(allProgressProvider.future);
  if (tracks.isEmpty || progress.isEmpty) return null;

  final byId = {for (final t in tracks) t.id: t};
  final candidates = progress.values
      .where((p) => !p.completed && byId.containsKey(p.trackId))
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  if (candidates.isEmpty) return null;

  final best = candidates.first;
  return (track: byId[best.trackId]!, progress: best);
});

final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) {
  return ref.watch(audioPlayerProvider).snapshotStream;
});

final currentTrackProvider = StateProvider<Track?>((ref) => null);

enum LibrarySort { recentlyAdded, title, artist }

final librarySortProvider =
    StateProvider<LibrarySort>((ref) => LibrarySort.recentlyAdded);

/// What's currently shown in the library list — segmented control state.
enum LibraryFilter { all, audiobooks, music, downloaded }

final libraryFilterProvider =
    StateProvider<LibraryFilter>((ref) => LibraryFilter.all);

/// Total bytes held in the synced-tracks cache. Re-fetched each time the
/// library mounts; the value is also nudged when downloads complete via
/// ref.invalidate.
final cacheSizeProvider = FutureProvider<int>((ref) async {
  return ref.watch(trackSyncServiceProvider).cacheSizeBytes();
});

/// Top-level navigation destinations. Mobile bottom-nav surfaces library /
/// playing / cloudStatus / settings; the desktop sidebar adds favorites and
/// playlists.
enum AppSection {
  library,
  favorites,
  playlists,
  playing,
  cloudStatus,
  settings,
}

final currentSectionProvider =
    StateProvider<AppSection>((ref) => AppSection.library);
