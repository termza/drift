import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin HTTP client for the Drift Media Server (see `server-media/`).
///
/// Stateless except for the `serverUrl` + `token` it was constructed with —
/// caller (usually [AuthRepository]) decides when to swap those out and
/// instantiate a new client.
class MediaServerClient {
  MediaServerClient({required this.serverUrl, this.token});

  final String serverUrl;
  final String? token;

  Map<String, String> get _authHeader =>
      token == null ? const {} : {'authorization': 'Bearer $token'};

  /// POST /api/auth — returns the bearer token to use on subsequent calls.
  /// Throws [MediaServerError] on any non-200.
  Future<String> signIn(String password) async {
    final r = await http.post(
      Uri.parse('$serverUrl/api/auth'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    if (r.statusCode != 200) {
      throw MediaServerError(
        'Sign-in failed (HTTP ${r.statusCode})',
        statusCode: r.statusCode,
      );
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final t = body['token'];
    if (t is! String || t.isEmpty) {
      throw MediaServerError('Server response missing token');
    }
    return t;
  }

  /// GET /api/health — returns true if the server is reachable.
  Future<bool> ping() async {
    try {
      final r = await http
          .get(Uri.parse('$serverUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/library — fetches the full track list.
  Future<List<MediaServerTrack>> library() async {
    final r = await http.get(
      Uri.parse('$serverUrl/api/library'),
      headers: _authHeader,
    );
    if (r.statusCode == 401) {
      throw MediaServerError('Not signed in', statusCode: 401);
    }
    if (r.statusCode != 200) {
      throw MediaServerError(
        'Library fetch failed (HTTP ${r.statusCode})',
        statusCode: r.statusCode,
      );
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final tracks = (body['tracks'] as List?) ?? const [];
    return tracks
        .cast<Map<String, dynamic>>()
        .map(MediaServerTrack.fromJson)
        .toList();
  }

  /// Build the streaming URL for [trackId]. Caller hands it to
  /// `AudioSource.uri(..., headers: streamHeaders)`.
  Uri streamUri(String trackId) =>
      Uri.parse('$serverUrl/api/stream/$trackId');

  /// Build the artwork URL for [trackId].
  Uri artworkUri(String trackId) =>
      Uri.parse('$serverUrl/api/artwork/$trackId');

  /// Headers to attach to streaming / artwork requests (Bearer token).
  Map<String, String> get streamHeaders => Map.unmodifiable(_authHeader);
}

class MediaServerError implements Exception {
  const MediaServerError(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// What `/api/library` returns per track. Mirrors the server's shape exactly.
class MediaServerTrack {
  const MediaServerTrack({
    required this.id,
    required this.title,
    required this.fileExt,
    this.artist,
    this.album,
    this.durationMs,
    this.fileSize,
    this.hasArtwork = false,
  });

  final String id;
  final String title;
  final String? artist;
  final String? album;
  final int? durationMs;
  final int? fileSize;
  final String fileExt;
  final bool hasArtwork;

  factory MediaServerTrack.fromJson(Map<String, dynamic> j) =>
      MediaServerTrack(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? j['id'] as String,
        artist: j['artist'] as String?,
        album: j['album'] as String?,
        durationMs: (j['duration_ms'] as num?)?.toInt(),
        fileSize: (j['file_size'] as num?)?.toInt(),
        fileExt: (j['file_ext'] as String?) ?? '',
        hasArtwork: (j['has_artwork'] as bool?) ?? false,
      );
}
