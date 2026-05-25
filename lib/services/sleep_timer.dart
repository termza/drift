import 'dart:async';

import 'package:flutter/foundation.dart';

/// Pauses the player after a chosen duration. Listenable so UI can show the
/// active state + remaining time.
class SleepTimer extends ChangeNotifier {
  SleepTimer(this._onExpire);

  final VoidCallback _onExpire;
  Timer? _timer;
  DateTime? _endsAt;

  bool get isActive => _timer != null && _timer!.isActive;
  Duration? get remaining {
    final end = _endsAt;
    if (end == null) return null;
    final r = end.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  void start(Duration d) {
    cancel();
    _endsAt = DateTime.now().add(d);
    _timer = Timer(d, () {
      _onExpire();
      _timer = null;
      _endsAt = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
