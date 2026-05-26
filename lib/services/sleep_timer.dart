import 'dart:async';

import 'package:flutter/foundation.dart';

/// What kind of sleep timer is running. `endOfChapter` requires the player
/// to have a non-null chapter index — see [SleepTimer.startUntilEndOfChapter].
enum SleepTimerMode { duration, endOfChapter }

/// Pauses the player after a chosen duration *or* at the next chapter
/// boundary. Listenable so UI can show the active state + remaining time.
class SleepTimer extends ChangeNotifier {
  SleepTimer(this._onExpire);

  final VoidCallback _onExpire;
  SleepTimerMode? _mode;
  Timer? _timer;
  DateTime? _endsAt;
  StreamSubscription<int?>? _chapterSub;
  int? _startChapterIndex;

  bool get isActive => _mode != null;
  SleepTimerMode? get mode => _mode;

  Duration? get remaining {
    final end = _endsAt;
    if (end == null) return null;
    final r = end.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  void start(Duration d) {
    cancel();
    _mode = SleepTimerMode.duration;
    _endsAt = DateTime.now().add(d);
    _timer = Timer(d, _expire);
    notifyListeners();
  }

  /// Pause when the player advances past the given chapter. Pass the current
  /// chapter index and the player's chapter-index stream.
  void startUntilEndOfChapter(
    int currentChapterIndex,
    Stream<int?> chapterIndexStream,
  ) {
    cancel();
    _mode = SleepTimerMode.endOfChapter;
    _startChapterIndex = currentChapterIndex;
    _chapterSub = chapterIndexStream.listen((idx) {
      if (idx != null && idx != _startChapterIndex) _expire();
    });
    notifyListeners();
  }

  void _expire() {
    _onExpire();
    _timer = null;
    _endsAt = null;
    _chapterSub?.cancel();
    _chapterSub = null;
    _startChapterIndex = null;
    _mode = null;
    notifyListeners();
  }

  void cancel() {
    _timer?.cancel();
    _chapterSub?.cancel();
    _timer = null;
    _chapterSub = null;
    _endsAt = null;
    _startChapterIndex = null;
    _mode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chapterSub?.cancel();
    super.dispose();
  }
}
