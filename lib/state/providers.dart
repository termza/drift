import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/auth_repository.dart';
import '../services/database.dart';
import '../services/favorites_service.dart';
import '../services/library_service.dart';
import '../services/pocketbase_backend.dart';
import '../services/progress_store.dart';
import '../services/sleep_timer.dart';
import '../services/sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override in main()');
});

final authRepositoryProvider = ChangeNotifierProvider<AuthRepository>((ref) {
  throw UnimplementedError('Override in main()');
});

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService(ref.watch(databaseProvider));
});

final progressStoreProvider = Provider<ProgressStore>((ref) {
  return ProgressStore(ref.watch(databaseProvider));
});

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService(ref.watch(databaseProvider));
});

final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService(ref.watch(progressStoreProvider));
  ref.onDispose(service.dispose);
  return service;
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

/// Which top-level destination is selected in the sidebar.
enum AppSection { library, favorites }

final currentSectionProvider =
    StateProvider<AppSection>((ref) => AppSection.library);
