/// Forgiving server-URL parser. Lets the user paste any reasonable shape
/// (bare IP, IP:port, hostname, full URL) and produces something the
/// PocketBase client can actually use.
///
/// Examples:
///   192.168.1.10           → http://192.168.1.10:8090
///   192.168.1.10:8090      → http://192.168.1.10:8090
///   192.168.1.10:9001      → http://192.168.1.10:9001
///   localhost              → http://127.0.0.1:8090
///   localhost:9001         → http://127.0.0.1:9001
///   sync.example.com       → https://sync.example.com
///   sync.example.com:8090  → https://sync.example.com:8090
///   http://1.2.3.4:8090/   → http://1.2.3.4:8090
///   https://drift.foo/api  → https://drift.foo  (path stripped)
class ServerUrlError implements Exception {
  ServerUrlError(this.message);
  final String message;
  @override
  String toString() => message;
}

class NormalizedServerUrl {
  const NormalizedServerUrl({
    required this.url,
    required this.host,
    required this.port,
    required this.scheme,
  });
  final String url;
  final String host;
  final int port;
  final String scheme;

  /// Human-friendly summary for UI ("192.168.1.10:8090" / "sync.example.com").
  String get display {
    final defaultPort = scheme == 'https' ? 443 : 80;
    if (port == defaultPort) return host;
    return '$host:$port';
  }
}

final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
const _defaultPocketBasePort = 8090;

NormalizedServerUrl normalizeServerUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) throw ServerUrlError('Server URL is required');

  // Strip path, query, and trailing slash — PocketBase only needs the origin.
  if (s.contains('://')) {
    final u = Uri.tryParse(s);
    if (u == null) throw ServerUrlError('Invalid URL');
    if (u.scheme != 'http' && u.scheme != 'https') {
      throw ServerUrlError('URL must start with http:// or https://');
    }
    if (u.host.isEmpty) throw ServerUrlError('URL is missing a host');
    final port = u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80);
    return NormalizedServerUrl(
      url: _format(u.scheme, u.host, port),
      host: u.host,
      port: port,
      scheme: u.scheme,
    );
  }

  // No scheme — parse "host" or "host:port" ourselves.
  String host;
  int? port;
  final colonIdx = s.lastIndexOf(':');
  if (colonIdx >= 0 && _looksLikePort(s.substring(colonIdx + 1))) {
    host = s.substring(0, colonIdx);
    final p = int.tryParse(s.substring(colonIdx + 1));
    if (p == null || p <= 0 || p > 65535) {
      throw ServerUrlError('Port must be between 1 and 65535');
    }
    port = p;
  } else {
    host = s;
  }

  if (host.isEmpty) throw ServerUrlError('Missing host');

  // Decide scheme + default port based on host shape.
  final isLocalhost = host.toLowerCase() == 'localhost';
  final isIp = _ipv4.hasMatch(host);
  final scheme = (isLocalhost || isIp) ? 'http' : 'https';
  final resolvedHost = isLocalhost ? '127.0.0.1' : host;
  final defaultPort = scheme == 'https' ? 443 : _defaultPocketBasePort;
  final resolvedPort = port ?? defaultPort;

  return NormalizedServerUrl(
    url: _format(scheme, resolvedHost, resolvedPort),
    host: resolvedHost,
    port: resolvedPort,
    scheme: scheme,
  );
}

String _format(String scheme, String host, int port) {
  final defaultPort = scheme == 'https' ? 443 : 80;
  final portPart = port == defaultPort ? '' : ':$port';
  return '$scheme://$host$portPart';
}

bool _looksLikePort(String s) =>
    s.isNotEmpty && s.length <= 5 && int.tryParse(s) != null;
