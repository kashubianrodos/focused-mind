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

enum Soundscape { birds, ocean }

extension SoundscapeInfo on Soundscape {
  String get label => switch (this) {
    Soundscape.birds => 'Birds chirping',
    Soundscape.ocean => 'Ocean waves',
  };

  String get asset => switch (this) {
    Soundscape.birds => 'assets/sounds/birds.m4a',
    Soundscape.ocean => 'assets/sounds/ocean.m4a',
  };
}

const endChimeAsset = 'assets/sounds/end_chime.m4a';

class FeedbackSettings {
  const FeedbackSettings({
    this.mode = FeedbackMode.alert,
    this.soundscape = Soundscape.birds,
    this.volume = 0.7,
    this.threshold = 40,
    this.baseline = ScoreScale.defaultBaseline,
    this.triggerDelay = const Duration(seconds: 5),
  });

  static const minTriggerDelay = Duration(seconds: 3);
  static const maxTriggerDelay = Duration(seconds: 30);

  final FeedbackMode mode;
  final Soundscape soundscape;

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
    double? volume,
    double? threshold,
    double? baseline,
    Duration? triggerDelay,
  }) => FeedbackSettings(
    mode: mode ?? this.mode,
    soundscape: soundscape ?? this.soundscape,
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
      other.volume == volume &&
      other.threshold == threshold &&
      other.baseline == baseline &&
      other.triggerDelay == triggerDelay;

  @override
  int get hashCode =>
      Object.hash(mode, soundscape, volume, threshold, baseline, triggerDelay);
}
