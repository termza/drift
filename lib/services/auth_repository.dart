import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/server_url.dart';
import 'media_server_client.dart';

/// Tracks the user's connection to a Drift Media Server: server URL +
/// bearer token. Persisted across launches via [SharedPreferences].
///
/// This used to wrap PocketBase. The Docker media server uses a single
/// shared-password auth scheme, so the email is purely cosmetic here.
class AuthRepository extends ChangeNotifier {
  AuthRepository._(this._prefs, this._serverUrl, this._token);

  static const _kServerUrl = 'sync.server_url';
  static const _kAuthToken = 'sync.auth_token';
  static const _kRecentServers = 'sync.recent_servers';
  static const _maxRecents = 5;

  /// Default server URL shown to the user on a fresh install — points at
  /// the local Drift Media Server's default port.
  static const _defaultUrl = 'http://127.0.0.1:8090';

  final SharedPreferences _prefs;
  String _serverUrl;
  String? _token;

  static Future<AuthRepository> init() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kServerUrl) ?? _defaultUrl;
    final token = prefs.getString(_kAuthToken);
    return AuthRepository._(prefs, url, token);
  }

  String get serverUrl => _serverUrl;
  String? get token => _token;
  bool get isSignedIn => _token != null && _serverUrl.isNotEmpty;

  /// Synthetic user identity — the media server doesn't have per-user
  /// accounts, but the rest of the app expects these fields.
  String? get userId => isSignedIn ? 'drift-local' : null;
  String? get userEmail => isSignedIn ? 'drift@local' : null;

  /// Build a fresh [MediaServerClient] for the current server + token.
  MediaServerClient client() =>
      MediaServerClient(serverUrl: _serverUrl, token: _token);

  Future<void> setServerUrl(String url) async {
    final normalized = normalizeServerUrl(url);
    if (normalized.url == _serverUrl) return;
    _serverUrl = normalized.url;
    // Swapping servers invalidates the cached token — different server,
    // probably different shared password.
    _token = null;
    await _prefs.setString(_kServerUrl, _serverUrl);
    await _prefs.remove(_kAuthToken);
    await _rememberServer(_serverUrl);
    notifyListeners();
  }

  /// Sign in with the media server's shared password. `email` is accepted
  /// for UI compatibility but ignored on the wire.
  Future<void> signIn(String _email, String password) async {
    final token = await client().signIn(password);
    _token = token;
    await _prefs.setString(_kAuthToken, token);
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    await _prefs.remove(_kAuthToken);
    notifyListeners();
  }

  /// Sign-up doesn't exist on a media server — there's just the one
  /// shared password. Kept for UI compatibility; routes to [signIn].
  Future<void> signUp({required String email, required String password}) =>
      signIn(email, password);

  // ---------------------------------------------------------------------------
  // Recent servers
  // ---------------------------------------------------------------------------

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

  /// Probe `/api/health` without touching saved state. Lets the sign-in
  /// screen offer a "Test connection" affordance.
  Future<ConnectionTest> testConnection(String url) async {
    final NormalizedServerUrl normalized;
    try {
      normalized = normalizeServerUrl(url);
    } on ServerUrlError catch (e) {
      return ConnectionTest(ok: false, message: e.message);
    } catch (_) {
      return const ConnectionTest(ok: false, message: 'Invalid URL');
    }

    final probe = MediaServerClient(serverUrl: normalized.url);
    final ok = await probe.ping();
    return ConnectionTest(
      ok: ok,
      message: ok
          ? 'Reached ${normalized.display}'
          : "Couldn't reach the server",
      normalizedUrl: ok ? normalized.url : null,
    );
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
