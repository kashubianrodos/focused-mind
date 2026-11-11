import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/sessions/session_models.dart';
import 'package:focused_mind/ui/rhythm_charts.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('the pie lists the three percentages', (tester) async {
    await tester.pumpWidget(
      host(RhythmPie(shares: RhythmShares.normalized(20, 30, 50))),
    );
    expect(find.text('Theta 20%'), findsOneWidget);
    expect(find.text('Alpha 30%'), findsOneWidget);
    expect(find.text('Beta 50%'), findsOneWidget);
    final pie = tester.widget<PieChart>(find.byType(PieChart));
    expect(pie.data.sections.map((s) => s.value), [20, 30, 50]);
  });

  testWidgets('unavailable shares show no segments', (tester) async {
    await tester.pumpWidget(host(const RhythmPie(shares: null)));
    expect(find.byType(PieChart), findsNothing);
    expect(find.byKey(const ValueKey('rhythms-unavailable')), findsOneWidget);
    expect(find.text('Beta –'), findsOneWidget);
  });

  testWidgets('the stacked chart has three layers that break at a gap', (
    tester,
  ) async {
    final shares = RhythmShares.normalized(20, 30, 50);
    final points = [
      for (var i = 0; i < 5; i++)
        TimelinePoint(
          second: i,
          score: 60,
          state: FocusState.neutral,
          rhythms: shares,
        ),
      const TimelinePoint(
        second: 5,
        score: null,
        state: FocusState.unavailable,
        gap: true,
      ),
      TimelinePoint(
        second: 6,
        score: 60,
        state: FocusState.neutral,
        rhythms: shares,
      ),
    ];
    await tester.pumpWidget(
      host(SizedBox(height: 200, child: RhythmStackedChart(points: points))),
    );
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.lineBarsData, hasLength(3));
    expect(data.betweenBarsData, hasLength(2));
    expect(data.lineBarsData[0].belowBarData.show, isTrue);
    for (final bar in data.lineBarsData) {
      expect(bar.spots[5].isNull(), isTrue, reason: 'gap breaks every layer');
    }
    expect(data.lineBarsData[0].spots[0].y, closeTo(20, 1e-9));
    expect(data.lineBarsData[1].spots[0].y, closeTo(50, 1e-9));
    expect(data.lineBarsData[2].spots[0].y, 100);
    expect(tester.takeException(), isNull);
  });
}
