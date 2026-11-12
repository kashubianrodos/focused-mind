import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/session_kind.dart';
import 'package:focused_mind/ui/format.dart';

void main() {
  for (final baseline in [30.0, 50.0, 70.0]) {
    test('calm below the baseline, restless from it (baseline $baseline)', () {
      final scale = ScoreScale(baseline: baseline);
      expect(classifyCalm(baseline - 0.1, scale), FocusState.focused);
      expect(classifyCalm(baseline, scale), FocusState.distracted);
      expect(classifyCalm(1, scale), FocusState.focused);
      expect(classifyCalm(99, scale), FocusState.distracted);
      expect(classifyCalm(null, scale), FocusState.unavailable);
    });
  }

  test('calm exactly covers the two relaxation zones', () {
    const scale = ScoreScale();
    for (var s = 0.0; s <= 100; s += 0.5) {
      final zone = scale.zoneOf(s);
      final relaxed =
          zone == FocusZone.relaxation || zone == FocusZone.deepRelaxation;
      expect(
        classifyCalm(s, scale),
        relaxed ? FocusState.focused : FocusState.distracted,
        reason: 'score $s',
      );
    }
  });

  test('state labels per session type', () {
    expect(stateLabel(FocusState.focused, SessionKind.focus), 'Focused');
    expect(stateLabel(FocusState.neutral, SessionKind.focus), 'Neutral');
    expect(stateLabel(FocusState.distracted, SessionKind.focus), 'Distracted');
    expect(stateLabel(FocusState.focused, SessionKind.meditation), 'Calm');
    expect(
      stateLabel(FocusState.distracted, SessionKind.meditation),
      'Restless',
    );
    for (final kind in SessionKind.values) {
      expect(stateLabel(FocusState.unavailable, kind), 'Signal unavailable');
    }
    expect(SessionKind.focus.label, 'Focus session');
    expect(SessionKind.meditation.label, 'Meditation session');
    expect(SessionKind.fromName('bogus'), SessionKind.focus);
  });
}
