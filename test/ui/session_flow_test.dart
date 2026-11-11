import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/headband/models.dart';
import 'package:focused_mind/ui/rhythm_charts.dart';

import '../support/app_harness.dart';

void main() {
  Future<void> startSession(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('start-session')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('signal check guides the user, then calibration shows progress', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    h.services.simulator!.ohms[Electrode.o2] = 5e6;
    await tester.tap(find.byKey(const ValueKey('start-session')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Checking the signal'), findsOneWidget);
    expect(find.text('O2 (back right): poor'), findsOneWidget);

    h.services.simulator!.ohms[Electrode.o2] = 100e3;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Calibrating'), findsOneWidget);
    expect(find.byKey(const ValueKey('calibration-percent')), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('live view: score, state, graph, time, signal and feedback', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await tester.tap(find.text('50 min'));
    await tester.pump();
    await startSession(tester);

    h.estimator.score = 80;
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const ValueKey('live-score')), findsOneWidget);
    expect(find.text('Focused'), findsOneWidget);
    expect(find.textContaining('left'), findsWidgets);
    expect(find.textContaining('Elapsed 00:'), findsOneWidget);
    expect(find.textContaining(':'), findsWidgets);
    expect(find.text('Left: good'), findsOneWidget);
    expect(
      find.textContaining('Alert · Birds chirping · quiet'),
      findsOneWidget,
    );

    // A sustained drop starts the alert soundscape.
    h.estimator.score = 5;
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Distracted'), findsOneWidget);
    expect(find.textContaining('playing'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mute')));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('muted'), findsOneWidget);
    expect(h.audio.volume, 0);
    await shutDown(tester, h);
  });

  testWidgets('a disconnection pauses the live view', (tester) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await startSession(tester);
    await tester.pump(const Duration(seconds: 5));
    h.services.simulator!.dropLink(restoreAfter: const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('session paused'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(find.textContaining('session paused'), findsNothing);
    await shutDown(tester, h);
  });

  testWidgets('ending shows the summary; history opens and deletes it', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await startSession(tester);
    h.estimator.score = 80;
    await tester.pump(const Duration(seconds: 10));
    h.estimator.score = 5;
    await tester.pump(const Duration(seconds: 10));
    h.estimator.score = 90;
    await tester.pump(const Duration(seconds: 10));

    await tester.tap(find.byKey(const ValueKey('end-session')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Session summary'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stat-Focus drops'))).data,
      '1',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stat-Recoveries'))).data,
      '1',
    );
    expect(find.byKey(const ValueKey('stat-Average focus')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stat-Longest focused stretch')),
      findsOneWidget,
    );

    final id = h.repository.saved.keys.single;
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(ValueKey('history-$id')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('history-$id')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stat-Focus drops'))).data,
      '1',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('delete-$id')));
    await tester.pumpAndSettle();
    expect(find.text('Delete session?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('history-$id')), findsNothing);
    expect(h.repository.saved, isEmpty);
    await shutDown(tester, h);
  });

  testWidgets('at 800×600 the scale gauge stays pinned below the scrolling '
      'body, and the pie, rhythm chart and gauge follow each reading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await startSession(tester);

    h.estimator
      ..score = 80
      ..rhythms = RhythmShares.normalized(20, 30, 50);
    await tester.pump(const Duration(seconds: 15));
    final gauge = find.byKey(const ValueKey('scale-gauge'));
    expect(gauge, findsOneWidget);
    expect(
      tester.getBottomLeft(gauge).dy,
      greaterThan(500),
      reason: 'gauge sits at the bottom of the window',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('scale-zone'))).data,
      'Concentration',
    );
    expect(find.text('Beta 50%'), findsOneWidget);
    final chart = tester.widget<RhythmStackedChart>(
      find.byKey(const ValueKey('live-rhythm-chart')),
    );
    expect(chart.points.where((p) => p.rhythms != null), isNotEmpty);

    // Scroll the body to the end: the gauge does not move.
    final before = tester.getTopLeft(gauge);
    await tester.drag(
      find.byKey(const ValueKey('live-scroll')),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(tester.getTopLeft(gauge), before);
    expect(
      find.byKey(const ValueKey('end-session')).hitTestable(),
      findsOneWidget,
    );

    // The next readings move the pie and the gauge.
    h.estimator
      ..score = 20
      ..rhythms = RhythmShares.normalized(45, 40, 15);
    await tester.pump(const Duration(seconds: 20));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('scale-zone'))).data,
      'Relaxation',
    );
    expect(find.textContaining('Beta 1'), findsOneWidget);

    await shutDown(tester, h);
  });
}
