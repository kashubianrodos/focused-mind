import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/ui/focus_scale_gauge.dart';

void main() {
  Future<void> pump(WidgetTester tester, double? score, ScoreScale scale) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusScaleGauge(score: score, scale: scale),
          ),
        ),
      );

  String semanticsValue(WidgetTester tester) =>
      tester.getSemantics(find.byKey(const ValueKey('scale-gauge'))).value;

  testWidgets('names the current zone and places the needle at the score', (
    tester,
  ) async {
    await pump(tester, 70, const ScoreScale());
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('scale-zone'))).data,
      'Concentration',
    );
    expect(semanticsValue(tester), '70 Concentration');

    await pump(tester, 95, const ScoreScale());
    await tester.pumpAndSettle();
    expect(semanticsValue(tester), '95 Deep concentration');
  });

  testWidgets('labels all four zones', (tester) async {
    await pump(tester, 50, const ScoreScale());
    for (final z in FocusZone.values) {
      expect(find.text(z.label.replaceAll(' ', '\n')), findsWidgets);
    }
  });

  testWidgets('shows unavailable instead of a position', (tester) async {
    await pump(tester, null, const ScoreScale());
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('scale-zone'))).data,
      'Signal unavailable',
    );
    expect(semanticsValue(tester), 'unavailable');
  });

  testWidgets('a baseline change moves the zone boundaries', (tester) async {
    await pump(tester, 45, const ScoreScale());
    await tester.pumpAndSettle();
    expect(semanticsValue(tester), '45 Relaxation');
    await pump(tester, 45, const ScoreScale(baseline: 40));
    await tester.pumpAndSettle();
    expect(semanticsValue(tester), '45 Concentration');
  });
}
