import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/app/menu_bar.dart';
import 'package:focused_mind/focus/focus_engine.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/sessions/session_controller.dart';

LiveSession live(double? score, FocusState state) => LiveSession(
  elapsed: const Duration(minutes: 3),
  planned: null,
  reading: FocusReading(
    score: score,
    rawScore: score,
    left: SideQuality.good,
    right: SideQuality.good,
  ),
  state: state,
  points: const [],
  marks: const [],
);

void main() {
  test('no menu bar item outside a session', () {
    expect(menuBarTitle(SessionPhase.idle, null), isNull);
    expect(menuBarTitle(SessionPhase.ended, null), isNull);
  });

  test('running session shows state and score', () {
    expect(
      menuBarTitle(SessionPhase.running, live(72.4, FocusState.focused)),
      '● 72 Focused',
    );
    expect(
      menuBarTitle(SessionPhase.running, live(31, FocusState.distracted)),
      '○ 31 Distracted',
    );
    expect(
      menuBarTitle(SessionPhase.running, live(null, FocusState.unavailable)),
      '– Signal unavailable',
    );
  });

  test('calibration, pause and mute are reflected', () {
    expect(menuBarTitle(SessionPhase.calibrating, null), 'Focus: calibrating');
    expect(menuBarTitle(SessionPhase.paused, null), 'Focus: paused');
    expect(
      menuBarTitle(
        SessionPhase.running,
        live(50, FocusState.neutral),
        muted: true,
      ),
      '◐ 50 Neutral 🔇',
    );
  });
}
