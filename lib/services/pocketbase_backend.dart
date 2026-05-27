import 'package:pocketbase/pocketbase.dart';

import '../models/playback_state.dart';
import 'auth_repository.dart';
import 'sync_service.dart';

/// PocketBase implementation of [SyncBackend].
///
/// Maintains an in-memory cache of (track_id → server record id) so we can do
/// per-track upserts without an extra round trip. The cache is populated
/// lazily on the first [pull].
class PocketBaseBackend implements SyncBackend {
  PocketBaseBackend(this._auth);

  final AuthRepository _auth;
  final Map<String, String> _recordIdByTrack = {};
  bool _primed = false;

  PocketBase get _pb => _auth.pb;

  @override
  String? get userId => _auth.userId;

  @override
  Future<List<TrackProgress>> pull({DateTime? since}) async {
    final uid = userId;
    if (uid == null) return const [];

    final filterParts = ['user = "$uid"'];
    if (since != null) {
      filterParts.add('updated >= "${_pbDate(since)}"');
    }

    final records = await _pb.collection('progress').getFullList(
          filter: filterParts.join(' && '),
          batch: 500,
        );

    final result = <TrackProgress>[];
    for (final r in records) {
      final trackId = r.data['track_id'] as String?;
      if (trackId == null) continue;
      _recordIdByTrack[trackId] = r.id;

      final clientUpdated = r.data['client_updated_at'] as String?;
      final ts = clientUpdated != null
          ? DateTime.tryParse(clientUpdated) ?? _parseUpdated(r)
          : _parseUpdated(r);

      result.add(TrackProgress(
        trackId: trackId,
        position: Duration(
          milliseconds: (r.data['position_ms'] as num?)?.toInt() ?? 0,
        ),
        updatedAt: ts,
        completed: (r.data['completed'] as bool?) ?? false,
      ));
    }

    _primed = true;
    return result;
  }

  @override
  Future<void> push(List<TrackProgress> dirty) async {
    final uid = userId;
    if (uid == null || dirty.isEmpty) return;

    // Prime the record-id cache the first time we push so we know what
    // already exists on the server.
    if (!_primed) await pull();

    for (final p in dirty) {
      final body = <String, dynamic>{
        'user': uid,
        'track_id': p.trackId,
        'position_ms': p.position.inMilliseconds,
        'completed': p.completed,
        'client_updated_at': p.updatedAt.toUtc().toIso8601String(),
      };

      final existing = _recordIdByTrack[p.trackId];
      try {
        if (existing != null) {
          await _pb.collection('progress').update(existing, body: body);
        } else {
          final created =
              await _pb.collection('progress').create(body: body);
          _recordIdByTrack[p.trackId] = created.id;
        }
      } on ClientException catch (e) {
        // 404 on update → record was deleted server-side, drop cache & retry.
        if (existing != null && e.statusCode == 404) {
          _recordIdByTrack.remove(p.trackId);
          final created =
              await _pb.collection('progress').create(body: body);
          _recordIdByTrack[p.trackId] = created.id;
          continue;
        }
        // Unique-index conflict on create → another device beat us; refresh
        // the cache and update instead.
        if (existing == null && (e.statusCode == 400 || e.statusCode == 409)) {
          await pull();
          final id = _recordIdByTrack[p.trackId];
          if (id != null) {
            await _pb.collection('progress').update(id, body: body);
            continue;
          }
        }
        rethrow;
      }
    }
  }

  /// Forget the record-id cache (call on sign-out / server URL change).
  @override
  void reset() {
    _recordIdByTrack.clear();
    _primed = false;
  }

  static String _pbDate(DateTime dt) {
    // PocketBase 0.22+ strictly expects 'YYYY-MM-DD HH:mm:ss.SSSZ' with
    // *exactly* three fractional digits. Dart's toIso8601String emits up to
    // six (microseconds), which PocketBase rejects with HTTP 400 and a
    // useless error body, so the periodic sync silently stops working.
    final u = dt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)} '
        '${two(u.hour)}:${two(u.minute)}:${two(u.second)}.${three(u.millisecond)}Z';
  }

  static DateTime _parseUpdated(RecordModel r) {
    final raw = r.get<String>('updated');
    if (raw.isEmpty) return DateTime.now().toUtc();
    return DateTime.tryParse(raw.replaceFirst(' ', 'T')) ??
        DateTime.now().toUtc();
  }
}
