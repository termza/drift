import 'dart:async';

import '../models/playback_state.dart';
import 'progress_store.dart';

/// Cross-device sync of playback progress. The Drift Media Server doesn't
/// currently expose a progress endpoint — this stack stays in place as a
/// no-op so callers don't have to special-case the "no backend" path.
///
/// Local [ProgressStore] is the source of truth; if/when the server
/// learns to remember positions, swap [OfflineBackend] for a real
/// implementation and reconcile resumes working automatically.
abstract class SyncBackend {
  String? get userId;

  Future<void> push(List<TrackProgress> dirty);
  Future<List<TrackProgress>> pull({DateTime? since});

  void reset() {}
}

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

  // ignore: unused_field
  final ProgressStore _store;
  SyncBackend _backend;
  Timer? _periodic;
  bool _running = false;

  SyncBackend get backend => _backend;
  bool get isSignedIn => _backend.userId != null;

  set backend(SyncBackend b) {
    _backend.reset();
    _backend = b;
  }

  /// Best-effort reconcile. Always wrapped in try/catch — sync errors
  /// must never crash the app.
  Future<void> reconcile() async {
    if (_running) return;
    _running = true;
    try {
      // No remote progress backend right now — see class docs.
    } catch (_) {
    } finally {
      _running = false;
    }
  }

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
