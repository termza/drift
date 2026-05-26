/// Persisted, user-tunable playback preferences. Loaded once at startup and
/// re-applied to the player on every track load — also live whenever changed,
/// so the speed sheet's slider takes effect immediately.
class PlaybackPrefs {
  final double speed;
  final int skipForwardSeconds;
  final int skipBackSeconds;

  /// If > 0, on resume after a pause longer than this many minutes, rewind
  /// by [autoRewindSeconds] before starting. 0 disables auto-rewind.
  final int autoRewindThresholdMinutes;
  final int autoRewindSeconds;

  const PlaybackPrefs({
    this.speed = 1.0,
    this.skipForwardSeconds = 30,
    this.skipBackSeconds = 15,
    this.autoRewindThresholdMinutes = 5,
    this.autoRewindSeconds = 10,
  });

  PlaybackPrefs copyWith({
    double? speed,
    int? skipForwardSeconds,
    int? skipBackSeconds,
    int? autoRewindThresholdMinutes,
    int? autoRewindSeconds,
  }) =>
      PlaybackPrefs(
        speed: speed ?? this.speed,
        skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
        skipBackSeconds: skipBackSeconds ?? this.skipBackSeconds,
        autoRewindThresholdMinutes:
            autoRewindThresholdMinutes ?? this.autoRewindThresholdMinutes,
        autoRewindSeconds: autoRewindSeconds ?? this.autoRewindSeconds,
      );

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'skipForwardSeconds': skipForwardSeconds,
        'skipBackSeconds': skipBackSeconds,
        'autoRewindThresholdMinutes': autoRewindThresholdMinutes,
        'autoRewindSeconds': autoRewindSeconds,
      };

  factory PlaybackPrefs.fromJson(Map<String, dynamic> j) => PlaybackPrefs(
        speed: (j['speed'] as num?)?.toDouble() ?? 1.0,
        skipForwardSeconds: (j['skipForwardSeconds'] as num?)?.toInt() ?? 30,
        skipBackSeconds: (j['skipBackSeconds'] as num?)?.toInt() ?? 15,
        autoRewindThresholdMinutes:
            (j['autoRewindThresholdMinutes'] as num?)?.toInt() ?? 5,
        autoRewindSeconds: (j['autoRewindSeconds'] as num?)?.toInt() ?? 10,
      );
}
