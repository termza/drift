import 'dart:async';

import '../models/playback_state.dart';
import 'progress_store.dart';

/// Cross-device sync of playback progress.
///
/// The local [ProgressStore] is always the source of truth for the UI; sync
/// reconciles in the background using last-write-wins on
/// [TrackProgress.updatedAt]. Implementations of [SyncBackend] handle a
/// specific server (PocketBase, Supabase, etc.).
abstract class SyncBackend {
  String? get userId;

  Future<void> push(List<TrackProgress> dirty);
  Future<List<TrackProgress>> pull({DateTime? since});

  /// Drop any cached state (record-id maps, etc.) on sign-out.
  void reset() {}
}

/// No-op backend so the app runs fully offline.
class OfflineBackend implements SyncBackend {
  @override
  String? get userId => null;

  @override
  Future<void> push(List<TrackProgress> dirty) async {}

  @override
  Future<List<TrackProgress>> pull({DateTime? since}) async => const [];

  @override
  void reset() {}
}

class SyncService {
  SyncService(this._store, this._backend);

  final ProgressStore _store;
  SyncBackend _backend;
  Timer? _periodic;
  bool _running = false;
  DateTime? _lastPullAt;

  SyncBackend get backend => _backend;
  bool get isSignedIn => _backend.userId != null;

  set backend(SyncBackend b) {
    _backend.reset();
    _backend = b;
    _lastPullAt = null;
  }

  /// Pull remote, merge with local using last-write-wins, push anything the
  /// remote didn't already have or that we updated more recently.
  ///
  /// Network errors are swallowed — sync is best-effort and must never crash
  /// the app. The most common failure mode (and the one this used to throw
  /// uncaught on) is "embedded server not up yet" which fixes itself on the
  /// next periodic tick.
  Future<void> reconcile() async {
    if (!isSignedIn || _running) return;
    _running = true;
    try {
      final local = await _store.getAll();
      final remote = await _backend.pull(since: _lastPullAt);
      _lastPullAt = DateTime.now().toUtc();

      final remoteByTrack = {for (final r in remote) r.trackId: r};

      // Remote wins where it's newer (or local has no record).
      for (final r in remote) {
        final l = local[r.trackId];
        if (l == null || r.updatedAt.isAfter(l.updatedAt)) {
          await _store.save(r);
        }
      }

      // Push anything local that's newer than (or missing from) remote.
      final toPush = <TrackProgress>[];
      for (final l in local.values) {
        final r = remoteByTrack[l.trackId];
        if (r == null || l.updatedAt.isAfter(r.updatedAt)) {
          toPush.add(l);
        }
      }
      if (toPush.isNotEmpty) await _backend.push(toPush);
    } catch (_) {
      // Best-effort: connection refused / 4xx / etc. all get retried next tick.
    } finally {
      _running = false;
    }
  }

  /// Periodic background reconcile (e.g. every minute while playing). Safe to
  /// call multiple times — replaces any existing timer.
  void startPeriodic({Duration interval = const Duration(minutes: 1)}) {
    _periodic?.cancel();
    _periodic = Timer.periodic(interval, (_) => reconcile());
  }

  void stopPeriodic() {
    _periodic?.cancel();
    _periodic = null;
  }

  void dispose() {
    stopPeriodic();
  }
}
