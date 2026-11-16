import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/ui/focus_scale_gauge.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    double? score,
    ScoreScale scale, {
    bool mirrored = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FocusScaleGauge(score: score, scale: scale, mirrored: mirrored),
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

  group('mirrored (meditation)', () {
    double labelX(WidgetTester tester, FocusZone z) =>
        tester.getCenter(find.byKey(ValueKey('zone-label-${z.name}'))).dx;

    testWidgets('Deep relaxation is the rightmost zone', (tester) async {
      await pump(tester, 50, const ScoreScale(), mirrored: true);
      final xs = [for (final z in FocusZone.values) labelX(tester, z)];
      expect(xs, [...xs]..sort((a, b) => b.compareTo(a)));
      expect(labelX(tester, FocusZone.deepRelaxation), xs.reduce(math.max));
    });

    testWidgets('unmirrored keeps Deep relaxation on the left', (tester) async {
      await pump(tester, 50, const ScoreScale());
      expect(
        labelX(tester, FocusZone.deepRelaxation),
        lessThan(labelX(tester, FocusZone.deepConcentration)),
      );
    });

    test('a low focus score puts the needle on the right', () {
      expect(gaugeFraction(10, mirrored: true), closeTo(0.9, 1e-9));
      expect(gaugeFraction(10), closeTo(0.1, 1e-9));
      expect(gaugeFraction(90, mirrored: true), closeTo(0.1, 1e-9));
    });

    testWidgets('the same score names the same zone either way', (
      tester,
    ) async {
      for (final score in [5.0, 30.0, 60.0, 95.0]) {
        await pump(tester, score, const ScoreScale());
        await tester.pumpAndSettle();
        final plain = semanticsValue(tester);
        await pump(tester, score, const ScoreScale(), mirrored: true);
        await tester.pumpAndSettle();
        expect(semanticsValue(tester), plain);
      }
    });
  });
}
