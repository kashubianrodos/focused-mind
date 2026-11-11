import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_state.dart';

void main() {
  test('classifies scores around the threshold', () {
    const cases = <(double?, double, FocusState)>[
      (null, 40, FocusState.unavailable),
      (0, 40, FocusState.distracted),
      (39.9, 40, FocusState.distracted),
      (40, 40, FocusState.neutral),
      (54.9, 40, FocusState.neutral),
      (55, 40, FocusState.focused),
      (100, 40, FocusState.focused),
      (0, 0, FocusState.neutral),
      (15, 0, FocusState.focused),
      (99, 100, FocusState.distracted),
    ];
    for (final (score, threshold, expected) in cases) {
      expect(
        classifyFocus(score, threshold),
        expected,
        reason: 'score $score, threshold $threshold',
      );
    }
  });

  test('a raised threshold applies to the next score', () {
    expect(classifyFocus(50, 40), FocusState.neutral);
    expect(classifyFocus(50, 60), FocusState.distracted);
  });
}
