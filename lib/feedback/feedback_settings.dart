import '../focus/focus_score.dart';

enum FeedbackMode {
  /// Sound plays while focus is lost (default).
  alert,

  /// Sound plays while focused and goes quiet when focus is lost.
  continuous,
}

extension FeedbackModeText on FeedbackMode {
  String get label => switch (this) {
    FeedbackMode.alert => 'Alert',
    FeedbackMode.continuous => 'Continuous',
  };

  String get description => switch (this) {
    FeedbackMode.alert =>
      'Quiet while you are focused; the soundscape fades in when your '
          'focus drops and fades out when you are back.',
    FeedbackMode.continuous =>
      'The soundscape plays while you are focused, louder the more '
          'focused you are, and goes quiet when your focus drops.',
  };
}

enum Soundscape { birds, ocean, forest }

extension SoundscapeInfo on Soundscape {
  String get label => switch (this) {
    Soundscape.birds => 'Birds chirping',
    Soundscape.ocean => 'Ocean waves',
    Soundscape.forest => 'Forest',
  };

  /// The stereo file, or with [mono] the same signal in both ears.
  String assetFor({required bool mono}) => switch (this) {
    Soundscape.birds => 'assets/sounds/birds${mono ? '_mono' : ''}.m4a',
    Soundscape.ocean => 'assets/sounds/ocean${mono ? '_mono' : ''}.m4a',
    // The forest field recording is mono already.
    Soundscape.forest => 'assets/sounds/forest.m4a',
  };
}

const endChimeAsset = 'assets/sounds/end_chime.m4a';

class FeedbackSettings {
  const FeedbackSettings({
    this.mode = FeedbackMode.alert,
    this.soundscape = Soundscape.birds,
    this.mono = false,
    this.volume = 0.7,
    this.threshold = 40,
    this.baseline = ScoreScale.defaultBaseline,
    this.triggerDelay = const Duration(seconds: 5),
  });

  static const minTriggerDelay = Duration(seconds: 3);
  static const maxTriggerDelay = Duration(seconds: 30);

  final FeedbackMode mode;
  final Soundscape soundscape;

  /// Play soundscapes in mono (same sound in both ears) instead of stereo.
  final bool mono;

  /// Maximum feedback loudness, 0–1.
  final double volume;

  /// Focus threshold, 0–100.
  final double threshold;

  /// Score given to the calibration level (see [ScoreScale]), 20–80.
  final double baseline;
  final Duration triggerDelay;

  ScoreScale get scoreScale => ScoreScale(baseline: baseline);

  FeedbackSettings copyWith({
    FeedbackMode? mode,
    Soundscape? soundscape,
    bool? mono,
    double? volume,
    double? threshold,
    double? baseline,
    Duration? triggerDelay,
  }) => FeedbackSettings(
    mode: mode ?? this.mode,
    soundscape: soundscape ?? this.soundscape,
    mono: mono ?? this.mono,
    volume: (volume ?? this.volume).clamp(0.0, 1.0),
    threshold: (threshold ?? this.threshold).clamp(0.0, 100.0),
    baseline: (baseline ?? this.baseline).clamp(
      ScoreScale.minBaseline,
      ScoreScale.maxBaseline,
    ),
    triggerDelay: _clampDelay(triggerDelay ?? this.triggerDelay),
  );

  static Duration _clampDelay(Duration d) => d < minTriggerDelay
      ? minTriggerDelay
      : (d > maxTriggerDelay ? maxTriggerDelay : d);

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'soundscape': soundscape.name,
    'mono': mono,
    'volume': volume,
    'threshold': threshold,
    'baseline': baseline,
    'triggerDelaySeconds': triggerDelay.inSeconds,
  };

  factory FeedbackSettings.fromJson(Map<String, Object?> json) {
    const d = FeedbackSettings();
    return d.copyWith(
      mode: FeedbackMode.values
          .where((m) => m.name == json['mode'])
          .firstOrNull,
      soundscape: Soundscape.values
          .where((s) => s.name == json['soundscape'])
          .firstOrNull,
      mono: json['mono'] is bool ? json['mono']! as bool : null,
      volume: (json['volume'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble(),
      baseline: (json['baseline'] as num?)?.toDouble(),
      triggerDelay: json['triggerDelaySeconds'] is int
          ? Duration(seconds: json['triggerDelaySeconds']! as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeedbackSettings &&
      other.mode == mode &&
      other.soundscape == soundscape &&
      other.mono == mono &&
      other.volume == volume &&
      other.threshold == threshold &&
      other.baseline == baseline &&
      other.triggerDelay == triggerDelay;

  @override
  int get hashCode => Object.hash(
    mode,
    soundscape,
    mono,
    volume,
    threshold,
    baseline,
    triggerDelay,
  );
}
