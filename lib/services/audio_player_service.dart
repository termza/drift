import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../models/playback_state.dart';
import '../models/track.dart';
import 'progress_store.dart';

/// Wraps [AudioPlayer] with progress persistence.
///
/// On every track change we resume from the last saved position. Position is
/// flushed to [ProgressStore] on a low-frequency timer to avoid SQLite spam.
class AudioPlayerService {
  AudioPlayerService(this._progress) {
    _player = AudioPlayer();
    _attachListeners();
  }

  final ProgressStore _progress;
  late final AudioPlayer _player;
  Track? _current;
  Timer? _flushTimer;

  Stream<PlayerState> get stateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;

  /// Combined stream so the UI can rebuild from a single source. Includes
  /// speed because [setSpeed] mutates the player without changing provider
  /// identity — without speed in this stream, UI bound to it goes stale.
  Stream<PlaybackSnapshot> get snapshotStream =>
      Rx.combineLatest4<Duration, Duration?, bool, double, PlaybackSnapshot>(
        _player.positionStream,
        _player.durationStream,
        _player.playingStream,
        _player.speedStream,
        (pos, dur, playing, speed) => PlaybackSnapshot(
          position: pos,
          duration: dur ?? Duration.zero,
          playing: playing,
          speed: speed,
        ),
      );

  Track? get current => _current;
  bool get isPlaying => _player.playing;

  Future<void> load(Track track, {bool autoplay = true}) async {
    _current = track;

    final saved = await _progress.get(track.id);
    final start = (saved != null && !saved.completed) ? saved.position : null;

    await _player.setAudioSource(
      AudioSource.file(
        track.filePath,
        tag: MediaItem(
          id: track.id,
          title: track.title,
          artist: track.artist,
          album: track.album,
          duration: track.duration,
        ),
      ),
      initialPosition: start,
    );

    if (autoplay) await _player.play();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> togglePlay() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> skipBack([Duration amount = const Duration(seconds: 15)]) =>
      seek((_player.position - amount).clamp());
  Future<void> skipForward([Duration amount = const Duration(seconds: 30)]) =>
      seek((_player.position + amount).clamp(max: _player.duration));

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  double get speed => _player.speed;

  void _attachListeners() {
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _flushProgress();
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _current != null) {
        _progress.markCompleted(_current!.id);
      }
    });
  }

  Future<void> _flushProgress() async {
    final track = _current;
    if (track == null) return;
    final pos = _player.position;
    if (pos == Duration.zero) return;
    await _progress.save(TrackProgress(
      trackId: track.id,
      position: pos,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flushProgress();
    await _player.dispose();
  }
}

class PlaybackSnapshot {
  final Duration position;
  final Duration duration;
  final bool playing;
  final double speed;
  const PlaybackSnapshot({
    required this.position,
    required this.duration,
    required this.playing,
    this.speed = 1.0,
  });
}

extension on Duration {
  Duration clamp({Duration? min, Duration? max}) {
    var v = this;
    if (min != null && v < min) v = min;
    if (max != null && v > max) v = max;
    if (v < Duration.zero) v = Duration.zero;
    return v;
  }
}
