import 'dart:math' as math;

/// The four zones of the relaxation–concentration scale (focus-scale spec),
/// from low to high, as in BrainBit's EEGWaves app.
enum FocusZone {
  deepRelaxation('Deep relaxation'),
  relaxation('Relaxation'),
  concentration('Concentration'),
  deepConcentration('Deep concentration');

  const FocusZone(this.label);
  final String label;
}

/// Maps EmotionalMath's calibration-relative output to the 0–100 focus score
/// (design D5).
///
/// `relAttention` rises above 0 only when the wearer is more focused than at
/// calibration, and `relRelaxation` only when they are less focused. Their
/// difference is a signed focus index in percent: 0 at the calibration
/// level, unbounded either way. The scale puts the calibration level at
/// [baseline] and saturates towards 0 and 100:
///
///     score = baseline + (100 − baseline) · tanh(index / span)   index ≥ 0
///     score = baseline +        baseline  · tanh(index / span)   index < 0
class ScoreScale {
  const ScoreScale({this.baseline = defaultBaseline, this.span = defaultSpan});

  static const defaultBaseline = 50.0;
  static const minBaseline = 20.0;
  static const maxBaseline = 80.0;

  /// Index (percent) at which the score has covered ~76% of the way from
  /// the baseline to 0 or 100.
  static const defaultSpan = 50.0;

  /// Score of the calibration level, 0–100.
  final double baseline;
  final double span;

  /// Indexes beyond this no longer change the score noticeably; the engine
  /// clamps to it so one huge reading cannot dominate the smoothing.
  double get indexLimit => 3 * span;

  double toScore(double index) {
    final t = _tanh(index / span);
    final range = index >= 0 ? 100 - baseline : baseline;
    return (baseline + range * t).clamp(0, 100).toDouble();
  }

  /// Scores where the zones meet, low to high: the "deep" zones start one
  /// [span] of focus index away from the calibration level (design D1).
  /// The middle boundary is the [baseline].
  List<double> get zoneBoundaries => [toScore(-span), baseline, toScore(span)];

  /// Zone of a focus [score] on this scale.
  FocusZone zoneOf(double score) {
    final b = zoneBoundaries;
    if (score < b[0]) return FocusZone.deepRelaxation;
    if (score < b[1]) return FocusZone.relaxation;
    if (score < b[2]) return FocusZone.concentration;
    return FocusZone.deepConcentration;
  }

  /// Inverse of [toScore], for tests and tooling. [score] is clamped to
  /// (0, 100) so the result stays finite.
  double toIndex(double score) {
    final s = score.clamp(0.01, 99.99);
    final range = s >= baseline ? 100 - baseline : baseline;
    if (range == 0) return 0;
    return span * _atanh((s - baseline) / range);
  }

  static double _tanh(double x) {
    if (x > 20) return 1;
    if (x < -20) return -1;
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static double _atanh(double x) {
    final c = x.clamp(-0.999999, 0.999999);
    return 0.5 * math.log((1 + c) / (1 - c));
  }

  @override
  bool operator ==(Object other) =>
      other is ScoreScale && other.baseline == baseline && other.span == span;

  @override
  int get hashCode => Object.hash(baseline, span);
}
