import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appearance_prefs.dart';

// Re-export for convenience so consumers only need one import.
export '../models/appearance_prefs.dart' show LibraryViewMode;

/// Owns [AppearancePrefs] and persists them to [SharedPreferences].
///
/// Watched by [AudioListenApp] so a change to the theme mode or accent key
/// triggers an immediate full-app rebuild with a fresh [ThemeData].
class AppearancePrefsService extends ChangeNotifier {
  AppearancePrefsService._(this._prefs, this._current);

  final SharedPreferences _prefs;
  AppearancePrefs _current;

  AppearancePrefs get current => _current;

  static const _key = 'appearance_prefs_v1';

  static Future<AppearancePrefsService> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    var initial = const AppearancePrefs();
    if (raw != null) {
      try {
        initial = AppearancePrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        // Corrupt JSON — fall back to defaults.
      }
    }
    return AppearancePrefsService._(p, initial);
  }

  Future<void> update(AppearancePrefs next) async {
    _current = next;
    await _prefs.setString(_key, jsonEncode(next.toJson()));
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) =>
      update(_current.copyWith(themeMode: m));
  Future<void> setAccentKey(String key) =>
      update(_current.copyWith(accentKey: key));
  Future<void> setLibraryViewMode(LibraryViewMode m) =>
      update(_current.copyWith(libraryViewMode: m));
}
