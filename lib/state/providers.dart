import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/auth_repository.dart';
import '../services/database.dart';
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

/// Most-recently-updated track that still has time remaining. Powers the
/// "Continue listening" hero card on the library screen.
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

/// Library sort options.
enum LibrarySort { recentlyAdded, title, artist }

final librarySortProvider =
    StateProvider<LibrarySort>((ref) => LibrarySort.recentlyAdded);
