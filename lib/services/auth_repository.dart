import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/server_url.dart';

/// Holds the PocketBase client + persisted auth.
///
/// The server URL and auth token are saved in [SharedPreferences] so the user
/// stays signed in across launches. Listeners are notified whenever auth or
/// the server URL changes so the UI (and sync service) can react.
class AuthRepository extends ChangeNotifier {
  AuthRepository._(this._prefs, this._pb);

  static const _kServerUrl = 'sync.server_url';
  static const _kAuthPayload = 'sync.auth_payload';
  static const _kRecentServers = 'sync.recent_servers';
  static const _maxRecents = 5;

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
  String get serverUrl => _pb.baseURL;
  bool get isSignedIn => _pb.authStore.isValid;
  String? get userId => _pb.authStore.record?.id;
  String? get userEmail => _pb.authStore.record?.data['email'] as String?;

  /// Accepts any of the shapes [normalizeServerUrl] supports: bare IP,
  /// IP:port, hostname, full URL. Throws [ServerUrlError] for inputs that
  /// can't be coerced into a valid origin.
  Future<void> setServerUrl(String url) async {
    final normalized = normalizeServerUrl(url);
    if (normalized.url == _pb.baseURL) return;

    await _prefs.setString(_kServerUrl, normalized.url);
    await _rememberServer(normalized.url);
    // Tearing down and rebuilding is simpler than mutating the existing client.
    final authStore = AsyncAuthStore(
      save: (data) async => _prefs.setString(_kAuthPayload, data),
      initial: _prefs.getString(_kAuthPayload),
    );
    _pb = PocketBase(normalized.url, authStore: authStore);
    notifyListeners();
  }

  /// Recent server URLs (most-recent first), persisted across launches so the
  /// user can hop between dev / home / remote without retyping.
  List<String> get recentServers =>
      _prefs.getStringList(_kRecentServers) ?? const [];

  Future<void> _rememberServer(String url) async {
    final list = recentServers.toList();
    list.remove(url);
    list.insert(0, url);
    while (list.length > _maxRecents) {
      list.removeLast();
    }
    await _prefs.setStringList(_kRecentServers, list);
  }

  Future<void> forgetServer(String url) async {
    final list = recentServers.toList()..remove(url);
    await _prefs.setStringList(_kRecentServers, list);
    notifyListeners();
  }

  /// Try to reach PocketBase's health endpoint without changing the saved
  /// URL. Returns a friendly result the UI can render.
  Future<ConnectionTest> testConnection(String url) async {
    final NormalizedServerUrl normalized;
    try {
      normalized = normalizeServerUrl(url);
    } on ServerUrlError catch (e) {
      return ConnectionTest(ok: false, message: e.message);
    } catch (e) {
      return ConnectionTest(ok: false, message: 'Invalid URL');
    }

    try {
      final resp = await http
          .get(Uri.parse('${normalized.url}/api/health'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return ConnectionTest(
          ok: true,
          message: 'Connected to ${normalized.display}',
          normalizedUrl: normalized.url,
        );
      }
      return ConnectionTest(
        ok: false,
        message: 'Server responded ${resp.statusCode}',
      );
    } on TimeoutException {
      return ConnectionTest(
        ok: false,
        message: 'Timed out — check the host and port',
      );
    } catch (_) {
      return ConnectionTest(
        ok: false,
        message: "Couldn't reach the server",
      );
    }
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

class ConnectionTest {
  const ConnectionTest({
    required this.ok,
    required this.message,
    this.normalizedUrl,
  });
  final bool ok;
  final String message;
  final String? normalizedUrl;
}
