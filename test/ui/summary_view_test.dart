import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/sessions/session_models.dart';
import 'package:focused_mind/sessions/session_recorder.dart';
import 'package:focused_mind/ui/summary_view.dart';

Future<void> show(WidgetTester tester, SessionRecord record) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SummaryView(record: record, threshold: 40),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a new session shows zone times and rhythm views', (
    tester,
  ) async {
    final r = SessionRecorder(id: 'n', startedAt: DateTime(2026, 11, 11, 9));
    for (var i = 0; i < 90; i++) {
      r.record(
        score: 70,
        state: FocusState.focused,
        rhythms: RhythmShares.normalized(20, 30, 50),
      );
    }
    for (var i = 0; i < 30; i++) {
      r.record(
        score: 30,
        state: FocusState.distracted,
        rhythms: RhythmShares.normalized(40, 40, 20),
      );
    }
    await show(tester, r.finish());

    String stat(FocusZone z) =>
        tester.widget<Text>(find.byKey(ValueKey('stat-zone-${z.name}'))).data!;
    expect(stat(FocusZone.concentration), '1 min 30 s');
    expect(stat(FocusZone.relaxation), '30 s');
    expect(stat(FocusZone.deepConcentration), '0 s');
    // (90·50 + 30·20) / 120 = 42.5 → shown rounded.
    expect(find.text('Beta 43%'), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-rhythm-chart')), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
  });

  testWidgets('a pre-change session omits the rhythm views', (tester) async {
    final summary = SessionSummary.fromJson({
      'id': 'old',
      'startedAt': '2026-11-01T10:00:00.000',
      'durationSeconds': 2,
      'plannedSeconds': null,
      'averageScore': 48.0,
      'timeInState': {'neutral': 2},
      'drops': 0,
      'recoveries': 0,
      'longestFocusedSeconds': 0,
      'mode': 'alert',
    });
    final timeline = [
      TimelinePoint.fromJson({
        's': 0,
        'v': 48.0,
        'st': 'neutral',
        'm': 'alert',
      }),
      TimelinePoint.fromJson({
        's': 1,
        'v': 48.0,
        'st': 'neutral',
        'm': 'alert',
      }),
    ];
    await show(
      tester,
      SessionRecord(summary: summary, timeline: timeline, marks: const []),
    );
    expect(find.byKey(const ValueKey('stat-Average focus')), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-rhythm-chart')), findsNothing);
    expect(find.byKey(const ValueKey('stat-zone-relaxation')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
