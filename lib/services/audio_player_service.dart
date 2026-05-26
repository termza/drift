import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../models/chapter.dart';
import '../models/playback_state.dart';
import '../models/track.dart';
import 'chapter_service.dart';
import 'playback_prefs_service.dart';
import 'progress_store.dart';

/// Wraps [AudioPlayer] with progress persistence, chapter awareness, and
/// live application of [PlaybackPrefsService].
///
/// On every track change we resume from the last saved position (with
/// optional auto-rewind if the user was paused for a while), load any
/// chapters parsed at import time, and apply the persisted speed. Position
/// is flushed to [ProgressStore] on a low-frequency timer to avoid SQLite
/// spam; pause is the moment we stamp `last_paused_at`.
class AudioPlayerService {
  AudioPlayerService(this._progress, this._chapters, this._prefs) {
    _player = AudioPlayer();
    _prefs.addListener(_onPrefsChanged);
    _attachListeners();
  }

  final ProgressStore _progress;
  final ChapterService _chapters;
  final PlaybackPrefsService _prefs;
  late final AudioPlayer _player;
  Track? _current;
  List<Chapter> _currentChapters = const [];
  final BehaviorSubject<int?> _chapterIndex = BehaviorSubject.seeded(null);
  StreamSubscription<Duration>? _chapterSub;
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

  // ---------------------------------------------------------------------------
  // Chapters
  // ---------------------------------------------------------------------------

  List<Chapter> get currentChapters => _currentChapters;
  bool get hasChapters => _currentChapters.isNotEmpty;
  Stream<int?> get chapterIndexStream => _chapterIndex.stream;
  int? get currentChapterIndex => _chapterIndex.valueOrNull;
  Chapter? get currentChapter {
    final i = _chapterIndex.valueOrNull;
    if (i == null || i < 0 || i >= _currentChapters.length) return null;
    return _currentChapters[i];
  }

  Future<void> seekToChapter(int idx) async {
    if (idx < 0 || idx >= _currentChapters.length) return;
    await seek(_currentChapters[idx].start);
  }

  Future<void> nextChapter() async {
    if (_currentChapters.isEmpty) return;
    final i = _chapterIndex.valueOrNull ?? -1;
    if (i + 1 < _currentChapters.length) {
      await seekToChapter(i + 1);
    }
  }

  /// Go to the start of the current chapter, unless we're already near it
  /// (< 3s in), in which case jump to the previous chapter — matching the
  /// behavior most podcast / audiobook players use.
  Future<void> prevChapter() async {
    if (_currentChapters.isEmpty) return;
    final i = _chapterIndex.valueOrNull;
    if (i == null) return;
    final pos = _player.position;
    final ch = _currentChapters[i];
    if (pos - ch.start > const Duration(seconds: 3) || i == 0) {
      await seekToChapter(i);
    } else {
      await seekToChapter(i - 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> load(Track track, {bool autoplay = true}) async {
    _current = track;

    final saved = await _progress.get(track.id);
    Duration? initial =
        (saved != null && !saved.completed) ? saved.position : null;
    initial = _maybeAutoRewind(initial, saved);

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
      initialPosition: initial,
    );

    await _loadChapters(track);
    await _player.setSpeed(_prefs.current.speed);

    if (autoplay) await _player.play();
  }

  Duration? _maybeAutoRewind(Duration? initial, TrackProgress? saved) {
    if (initial == null || saved?.lastPausedAt == null) return initial;
    final p = _prefs.current;
    if (p.autoRewindThresholdMinutes <= 0) return initial;
    final elapsed = DateTime.now().difference(saved!.lastPausedAt!);
    if (elapsed.inMinutes < p.autoRewindThresholdMinutes) return initial;
    final rewound = initial - Duration(seconds: p.autoRewindSeconds);
    return rewound.isNegative ? Duration.zero : rewound;
  }

  Future<void> _loadChapters(Track track) async {
    var chapters = await _chapters.listForTrack(track.id);
    // Patch the final chapter's end if it was saved as 0 (unknown duration at
    // import time). Now we have the real duration from the player.
    if (chapters.isNotEmpty && chapters.last.end == Duration.zero) {
      final dur = _player.duration ?? track.duration ?? Duration.zero;
      if (dur > Duration.zero) {
        chapters = [
          ...chapters.take(chapters.length - 1),
          chapters.last.copyWith(end: dur),
        ];
      }
    }
    _currentChapters = chapters;
    _chapterIndex.add(_indexAt(_player.position));
  }

  int? _indexAt(Duration pos) {
    if (_currentChapters.isEmpty) return null;
    for (var i = 0; i < _currentChapters.length; i++) {
      if (_currentChapters[i].contains(pos)) return i;
    }
    return _currentChapters.length - 1;
  }

  Future<void> play() => _player.play();

  /// Pause + stamp `last_paused_at` for auto-rewind. Sleep-timer expiry,
  /// the in-app pause button, and play/pause toggle all route through here.
  Future<void> pause() async {
    await _player.pause();
    final t = _current;
    if (t == null) return;
    final pos = _player.position;
    if (pos == Duration.zero) return;
    await _progress.markPaused(
      t.id,
      pos,
      chapter: _chapterIndex.valueOrNull,
    );
  }

  Future<void> togglePlay() => _player.playing ? pause() : play();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> skipBack([Duration? amount]) {
    final d = amount ?? Duration(seconds: _prefs.current.skipBackSeconds);
    return seek((_player.position - d).clamp());
  }

  Future<void> skipForward([Duration? amount]) {
    final d = amount ?? Duration(seconds: _prefs.current.skipForwardSeconds);
    return seek((_player.position + d).clamp(max: _player.duration));
  }

  /// Apply *and* persist a new speed. The footer pill and speed sheet both
  /// call this so the user's choice survives restart.
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    await _prefs.setSpeed(speed);
  }

  double get speed => _player.speed;

  void _onPrefsChanged() {
    // Pick up changes that came from elsewhere (e.g. settings screen).
    // Comparing to the current player speed avoids needless setSpeed roundtrips.
    final desired = _prefs.current.speed;
    if ((_player.speed - desired).abs() > 0.001) {
      _player.setSpeed(desired);
    }
  }

  void _attachListeners() {
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _flushProgress();
    });

    _chapterSub = _player.positionStream.listen((pos) {
      if (_currentChapters.isEmpty) return;
      final next = _indexAt(pos);
      if (next != _chapterIndex.valueOrNull) _chapterIndex.add(next);
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
    await _progress.savePosition(
      track.id,
      pos,
      chapter: _chapterIndex.valueOrNull,
    );
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _chapterSub?.cancel();
    _prefs.removeListener(_onPrefsChanged);
    await _flushProgress();
    await _chapterIndex.close();
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
