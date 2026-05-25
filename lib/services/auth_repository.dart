import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the PocketBase client + persisted auth.
///
/// The server URL and auth token are saved in [SharedPreferences] so the user
/// stays signed in across launches. Listeners are notified whenever auth or
/// the server URL changes so the UI (and sync service) can react.
class AuthRepository extends ChangeNotifier {
  AuthRepository._(this._prefs, this._pb);

  static const _kServerUrl = 'sync.server_url';
  static const _kAuthPayload = 'sync.auth_payload';

  /// Default server during development. Override in the sign-in screen.
  static const _defaultUrl = 'http://127.0.0.1:8090';

  final SharedPreferences _prefs;
  PocketBase _pb;

  static Future<AuthRepository> init() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kServerUrl) ?? _defaultUrl;

    final authStore = AsyncAuthStore(
      save: (data) async => prefs.setString(_kAuthPayload, data),
      initial: prefs.getString(_kAuthPayload),
    );

    final pb = PocketBase(url, authStore: authStore);
    final repo = AuthRepository._(prefs, pb);

    // Refresh the cached auth in the background — if the server invalidated
    // the token (password change, etc.) we'll cleanly fall back to signed-out.
    if (pb.authStore.isValid) {
      unawaited(repo._refresh());
    }
    return repo;
  }

  PocketBase get pb => _pb;
  String get serverUrl => _pb.baseUrl;
  bool get isSignedIn => _pb.authStore.isValid;
  String? get userId => _pb.authStore.record?.id;
  String? get userEmail => _pb.authStore.record?.data['email'] as String?;

  Future<void> setServerUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned == _pb.baseUrl) return;

    await _prefs.setString(_kServerUrl, cleaned);
    // Tearing down and rebuilding is simpler than mutating the existing client.
    final authStore = AsyncAuthStore(
      save: (data) async => _prefs.setString(_kAuthPayload, data),
      initial: _prefs.getString(_kAuthPayload),
    );
    _pb = PocketBase(cleaned, authStore: authStore);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _pb.collection('users').authWithPassword(email, password);
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _pb.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
    });
    await signIn(email, password);
  }

  Future<void> signOut() async {
    _pb.authStore.clear();
    notifyListeners();
  }

  Future<void> _refresh() async {
    try {
      await _pb.collection('users').authRefresh();
      notifyListeners();
    } catch (_) {
      _pb.authStore.clear();
      notifyListeners();
    }
  }
}
