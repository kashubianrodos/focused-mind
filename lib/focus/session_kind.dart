import 'focus_score.dart';
import 'focus_state.dart';

/// What a session rewards (meditation-sessions spec, design D1).
///
/// The recorded [FocusState] means "on goal" / "off goal" for the session's
/// kind (design D2):
///
/// | State        | Focus session | Meditation session                    |
/// |--------------|---------------|---------------------------------------|
/// | `focused`    | Focused       | Calm: Relaxation or Deep relaxation   |
/// | `neutral`    | Neutral       | (not used)                            |
/// | `distracted` | Distracted    | Restless: Concentration or deeper     |
///
/// So drops are restless episodes and `longestFocused` is the longest calm
/// stretch in a meditation session.
enum SessionKind {
  focus('Focus session'),
  meditation('Meditation session');

  const SessionKind(this.label);
  final String label;

  static SessionKind fromName(Object? name) =>
      values.where((k) => k.name == name).firstOrNull ?? focus;
}

/// Classifies a smoothed focus [score] for a meditation session: calm
/// (`focused`) at or below the Relaxation zones, restless (`distracted`) in
/// Concentration or Deep concentration (design D2).
FocusState classifyCalm(double? score, ScoreScale scale) {
  if (score == null) return FocusState.unavailable;
  return switch (scale.zoneOf(score)) {
    FocusZone.deepRelaxation || FocusZone.relaxation => FocusState.focused,
    FocusZone.concentration ||
    FocusZone.deepConcentration => FocusState.distracted,
  };
}
