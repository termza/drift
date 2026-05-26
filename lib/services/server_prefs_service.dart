import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_prefs.dart';

/// Owns [ServerPrefs] and persists them to [SharedPreferences].
///
/// Generates the hidden admin credentials lazily on first enable, so a fresh
/// install doesn't pre-create them until the user actually opts in.
class ServerPrefsService extends ChangeNotifier {
  ServerPrefsService._(this._prefs, this._current);
  final SharedPreferences _prefs;
  ServerPrefs _current;

  ServerPrefs get current => _current;

  static const _key = 'server_prefs_v1';

  static Future<ServerPrefsService> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    var initial = const ServerPrefs();
    if (raw != null) {
      try {
        initial =
            ServerPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt JSON — fall back to defaults.
      }
    }
    return ServerPrefsService._(p, initial);
  }

  Future<void> update(ServerPrefs next) async {
    _current = next;
    await _prefs.setString(_key, jsonEncode(next.toJson()));
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    var next = _current.copyWith(enabled: v);
    if (v && next.adminEmail.isEmpty) {
      // Generate admin credentials on first enable.
      next = next.copyWith(
        adminEmail: _genAdminEmail(),
        adminPassword: _genPassword(),
      );
    }
    await update(next);
  }

  Future<void> setSyncPassword(String pw) =>
      update(_current.copyWith(syncPassword: pw));
  Future<void> setPort(int port) => update(_current.copyWith(port: port));

  // ---------------------------------------------------------------------------

  static String _genAdminEmail() {
    final rnd = Random.secure();
    final tag = List.generate(8, (_) => rnd.nextInt(36).toRadixString(36)).join();
    return 'admin-$tag@drift.local';
  }

  static String _genPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(32, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
