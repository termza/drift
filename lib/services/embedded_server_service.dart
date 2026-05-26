import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/server_prefs.dart';
import 'server_prefs_service.dart';

/// What the embedded sync server is currently doing.
enum EmbeddedServerStatus {
  /// Disabled by user.
  off,

  /// Looking for / launching the pocketbase binary.
  starting,

  /// Server is reachable on the local network.
  running,

  /// Tried to start but failed — see [EmbeddedServerService.errorMessage].
  failed,

  /// Stopping in response to a user toggle / app shutdown.
  stopping,
}

/// Manages a `pocketbase.exe` (or `pocketbase` on macOS/Linux) subprocess so
/// the Drift desktop app *is* the sync server other devices connect to.
///
/// First-run flow when the user toggles the server on:
///   1. Locate the PocketBase binary (next to the app exe, in app-support, or
///      on PATH). If missing, transition to [EmbeddedServerStatus.failed]
///      with a friendly message telling the user where to drop it.
///   2. Run `pocketbase superuser upsert <admin> <pwd> --dir <data>` to
///      create / refresh the hidden admin account.
///   3. Spawn `pocketbase serve --http 0.0.0.0:<port>` so LAN devices can
///      reach it.
///   4. Poll `/api/health` until it responds (~10s timeout).
///   5. Authenticate as the admin via raw HTTP and upsert the sync user with
///      the user's chosen password.
///   6. Detect the LAN IP so the UI can show "iPhone connect to <ip:port>".
///
/// The service exposes itself as a [ChangeNotifier]; the Settings UI watches
/// it for live status updates.
class EmbeddedServerService extends ChangeNotifier {
  EmbeddedServerService(this._prefs) {
    _prefs.addListener(_onPrefsChanged);
    _maybeReact();
  }

  final ServerPrefsService _prefs;
  Process? _process;
  EmbeddedServerStatus _status = EmbeddedServerStatus.off;
  String? _errorMessage;
  String? _lanIp;
  final List<String> _logLines = [];
  static const _maxLogLines = 200;

  /// Hosts the server can run on. Windows/macOS/Linux desktop only — mobile
  /// platforms simply skip everything in this class.
  static bool get supportedOnThisPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  EmbeddedServerStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get lanIp => _lanIp;
  int get port => _prefs.current.port;
  String get syncEmail => _prefs.current.syncEmail;
  List<String> get tail => List.unmodifiable(_logLines);

  /// URL other devices can plug into the Drift sign-in screen.
  String? get lanUrl {
    if (_lanIp == null) return null;
    return 'http://$_lanIp:$port';
  }

  void _onPrefsChanged() => _maybeReact();

  Future<void> _maybeReact() async {
    final prefs = _prefs.current;
    if (!supportedOnThisPlatform) return;

    if (prefs.enabled && _status == EmbeddedServerStatus.off) {
      await _start();
    } else if (!prefs.enabled && _status != EmbeddedServerStatus.off) {
      await _stop();
    } else if (prefs.enabled && _status == EmbeddedServerStatus.running) {
      // Already running — sync password may have changed; reapply it.
      await _ensureSyncUser(prefs);
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _start() async {
    final prefs = _prefs.current;
    if (prefs.syncPassword.isEmpty) {
      _set(EmbeddedServerStatus.failed,
          error:
              'Set a sync password first — other devices use it to connect.');
      return;
    }
    if (!prefs.hasCredentials) {
      _set(EmbeddedServerStatus.failed,
          error:
              'Server credentials missing. Toggle off and back on to regenerate.');
      return;
    }

    _set(EmbeddedServerStatus.starting);
    _logLines.clear();

    final exe = await _findBinary();
    if (exe == null) {
      _set(
        EmbeddedServerStatus.failed,
        error: 'PocketBase binary not found.\n'
            'Place pocketbase${Platform.isWindows ? '.exe' : ''} next to Drift '
            'or in ${(await _supportDir()).path}, then toggle this back on.',
      );
      return;
    }

    final dataDir = await _dataDir();

    // Step 2 — ensure superuser exists (idempotent upsert).
    final adminOk = await _upsertSuperuser(
      exe: exe,
      dataDir: dataDir.path,
      email: prefs.adminEmail,
      password: prefs.adminPassword,
    );
    if (!adminOk) {
      _set(EmbeddedServerStatus.failed,
          error: 'Failed to provision sync server admin. '
              'Check that your PocketBase binary is v0.22 or newer.');
      return;
    }

    // Step 3 — spawn `serve`.
    try {
      _process = await Process.start(
        exe,
        ['serve', '--http=0.0.0.0:${prefs.port}', '--dir=${dataDir.path}'],
        mode: ProcessStartMode.normal,
      );
    } catch (e) {
      _set(EmbeddedServerStatus.failed, error: 'Could not start: $e');
      return;
    }

    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_appendLog);
    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_appendLog);
    unawaited(_process!.exitCode.then(_onProcessExit));

    // Step 4 — wait for health.
    final ready = await _waitForHealth(prefs.port);
    if (!ready) {
      _set(EmbeddedServerStatus.failed,
          error: 'Started, but never became reachable on port ${prefs.port}. '
              'Another process may be using the port.');
      await _stop();
      return;
    }

    // Step 5 — ensure sync user.
    final userOk = await _ensureSyncUser(prefs);
    if (!userOk) {
      _set(EmbeddedServerStatus.failed,
          error: 'Server running, but provisioning the sync user failed.');
      return;
    }

    // Step 6 — detect LAN IP.
    _lanIp = await _detectLanIp();

    _set(EmbeddedServerStatus.running);
  }

  Future<void> _stop() async {
    if (_status == EmbeddedServerStatus.off) return;
    _set(EmbeddedServerStatus.stopping);
    try {
      _process?.kill(ProcessSignal.sigterm);
      // Give it a beat to flush, then nuke if needed.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _process?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    _process = null;
    _lanIp = null;
    _set(EmbeddedServerStatus.off);
  }

  void _onProcessExit(int code) {
    if (_status == EmbeddedServerStatus.stopping) return; // expected
    _process = null;
    _set(EmbeddedServerStatus.failed,
        error: 'Sync server stopped unexpectedly (exit $code).');
  }

  // ---------------------------------------------------------------------------
  // Binary + data dir discovery
  // ---------------------------------------------------------------------------

  Future<String?> _findBinary() async {
    final name = Platform.isWindows ? 'pocketbase.exe' : 'pocketbase';

    // 1. Next to the running executable.
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final guess = File(p.join(exeDir, name));
      if (await guess.exists()) return guess.path;
    } catch (_) {}

    // 2. App-support directory (where we could auto-download to in future).
    try {
      final dir = await _supportDir();
      final guess = File(p.join(dir.path, name));
      if (await guess.exists()) return guess.path;
    } catch (_) {}

    // 3. CWD as a last resort.
    final cwdGuess = File(p.join(Directory.current.path, name));
    if (await cwdGuess.exists()) return cwdGuess.path;

    return null;
  }

  Future<Directory> _supportDir() => getApplicationSupportDirectory();

  Future<Directory> _dataDir() async {
    final base = await _supportDir();
    final dir = Directory(p.join(base.path, 'pb_data'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ---------------------------------------------------------------------------
  // PocketBase admin + user provisioning
  // ---------------------------------------------------------------------------

  Future<bool> _upsertSuperuser({
    required String exe,
    required String dataDir,
    required String email,
    required String password,
  }) async {
    // PocketBase 0.22+ uses `superuser`. Try that first; older versions used
    // `admin`. Both support idempotent upsert.
    for (final group in ['superuser', 'admin']) {
      try {
        final result = await Process.run(
          exe,
          [group, 'upsert', email, password, '--dir', dataDir],
        );
        if (result.exitCode == 0) return true;
      } catch (_) {
        // Try next group.
      }
    }
    return false;
  }

  Future<bool> _waitForHealth(int port) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final r = await http
            .get(Uri.parse('http://127.0.0.1:$port/api/health'))
            .timeout(const Duration(milliseconds: 800));
        if (r.statusCode == 200) return true;
      } catch (_) {
        // Not yet ready.
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    return false;
  }

  Future<bool> _ensureSyncUser(ServerPrefs prefs) async {
    final base = 'http://127.0.0.1:${prefs.port}/api';
    // Sign in as admin (try v0.22+ endpoint, then legacy).
    String? token;
    for (final ep in [
      '/collections/_superusers/auth-with-password',
      '/admins/auth-with-password',
    ]) {
      try {
        final r = await http.post(
          Uri.parse('$base$ep'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identity': prefs.adminEmail,
            'password': prefs.adminPassword,
          }),
        );
        if (r.statusCode == 200) {
          token = (jsonDecode(r.body) as Map)['token'] as String?;
          if (token != null) break;
        }
      } catch (_) {}
    }
    if (token == null) return false;

    // Find existing user by email.
    String? existingId;
    try {
      final r = await http.get(
        Uri.parse(
            '$base/collections/users/records?filter=' +
                Uri.encodeQueryComponent('email = "${prefs.syncEmail}"')),
        headers: {'Authorization': token},
      );
      if (r.statusCode == 200) {
        final items = (jsonDecode(r.body) as Map)['items'] as List?;
        if (items != null && items.isNotEmpty) {
          existingId = (items.first as Map)['id'] as String?;
        }
      }
    } catch (_) {}

    final body = jsonEncode({
      'email': prefs.syncEmail,
      'password': prefs.syncPassword,
      'passwordConfirm': prefs.syncPassword,
      'emailVisibility': true,
      'verified': true,
    });
    try {
      if (existingId == null) {
        final r = await http.post(
          Uri.parse('$base/collections/users/records'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': token,
          },
          body: body,
        );
        return r.statusCode >= 200 && r.statusCode < 300;
      } else {
        final r = await http.patch(
          Uri.parse('$base/collections/users/records/$existingId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': token,
          },
          body: body,
        );
        return r.statusCode >= 200 && r.statusCode < 300;
      }
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // LAN IP detection
  // ---------------------------------------------------------------------------

  Future<String?> _detectLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      // Prefer typical private LAN ranges in this order.
      String? best;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.')) return ip;
          if (ip.startsWith('10.')) best ??= ip;
          if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip)) {
            best ??= ip;
          }
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // State helpers
  // ---------------------------------------------------------------------------

  void _set(EmbeddedServerStatus s, {String? error}) {
    _status = s;
    _errorMessage = error;
    notifyListeners();
  }

  void _appendLog(String line) {
    _logLines.add(line);
    while (_logLines.length > _maxLogLines) {
      _logLines.removeAt(0);
    }
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    unawaited(_stop());
    super.dispose();
  }
}
