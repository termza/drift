import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/playback_prefs.dart';

/// Owns [PlaybackPrefs] and persists them to [SharedPreferences].
///
/// Implemented as a [ChangeNotifier] so the audio player and any settings
/// surfaces can react to live changes (e.g. speed slider drag) without
/// rebuilding the player provider.
class PlaybackPrefsService extends ChangeNotifier {
  PlaybackPrefsService._(this._prefs, this._current);

  final SharedPreferences _prefs;
  PlaybackPrefs _current;

  PlaybackPrefs get current => _current;

  static const _key = 'playback_prefs_v1';

  static Future<PlaybackPrefsService> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    var initial = const PlaybackPrefs();
    if (raw != null) {
      try {
        initial = PlaybackPrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        // Corrupt JSON — fall back to defaults.
      }
    }
    return PlaybackPrefsService._(p, initial);
  }

  Future<void> update(PlaybackPrefs next) async {
    _current = next;
    await _prefs.setString(_key, jsonEncode(next.toJson()));
    notifyListeners();
  }

  Future<void> setSpeed(double v) => update(_current.copyWith(speed: v));
  Future<void> setSkipForward(int s) =>
      update(_current.copyWith(skipForwardSeconds: s));
  Future<void> setSkipBack(int s) =>
      update(_current.copyWith(skipBackSeconds: s));
  Future<void> setAutoRewindThreshold(int minutes) =>
      update(_current.copyWith(autoRewindThresholdMinutes: minutes));
  Future<void> setAutoRewindSeconds(int seconds) =>
      update(_current.copyWith(autoRewindSeconds: seconds));
}
