import '../focus/focus_score.dart';
import '../focus/session_kind.dart';
import 'feedback_settings.dart';

/// How long the score may be unavailable before feedback fades to silence.
const unavailableSilenceAfter = Duration(seconds: 10);

/// Lowest audible fraction of the user volume while feedback plays.
const _minFraction = 0.4;

/// Target feedback gain (0–1) for the current situation (design D6a).
///
/// | Mode       | No drop active        | Drop active              |
/// |------------|-----------------------|--------------------------|
/// | Alert      | 0                     | scaled by focus deficit  |
/// | Continuous | scaled by focus level | 0                        |
///
/// In a meditation session [mode] is ignored (meditation-sessions spec,
/// design D5): the sound plays outside a restless episode, from the floor at
/// the Relaxation/Concentration boundary up to [volume] in Deep relaxation of
/// [scale].
///
/// Muted, or unavailable for more than [unavailableSilenceAfter], gives 0.
/// While unavailable for less than that, the last known [score] is used.
double targetGain({
  SessionKind kind = SessionKind.focus,
  ScoreScale scale = const ScoreScale(),
  required FeedbackMode mode,
  required bool dropActive,
  required double? score,
  required double threshold,
  required double volume,
  required bool muted,
  required Duration unavailableFor,
}) {
  if (muted || unavailableFor > unavailableSilenceAfter || volume <= 0) {
    return 0;
  }
  if (kind == SessionKind.meditation) {
    if (dropActive || score == null) return 0;
    final boundary = scale.baseline;
    final deep = scale.zoneBoundaries.first;
    final range = boundary - deep;
    final level = range <= 0 ? 1.0 : (boundary - score) / range;
    return volume * _fraction(level);
  }
  switch (mode) {
    case FeedbackMode.alert:
      if (!dropActive) return 0;
      final deficit = threshold <= 0 || score == null
          ? 0.0
          : (threshold - score) / threshold;
      return volume * _fraction(deficit);
    case FeedbackMode.continuous:
      if (dropActive || score == null) return 0;
      final headroom = 100 - threshold;
      final level = headroom <= 0 ? 1.0 : (score - threshold) / headroom;
      return volume * _fraction(level);
  }
}

double _fraction(double x) =>
    (_minFraction + (1 - _minFraction) * x).clamp(_minFraction, 1.0);
