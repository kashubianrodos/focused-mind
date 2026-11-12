import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/session_kind.dart';

import '../support/app_harness.dart';

String _kindChip(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('session-kind')),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  Future<void> startSession(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('start-session')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('start screen defaults to a focus session', (tester) async {
    final h = await pumpApp(tester);
    expect(find.text('Start a focus session'), findsOneWidget);
    expect(find.byKey(const ValueKey('kind-focus')), findsOneWidget);
    expect(find.byKey(const ValueKey('kind-meditation')), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('the chosen type is remembered once a session starts', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await tester.tap(find.byKey(const ValueKey('kind-meditation')));
    await tester.pump();
    expect(find.text('Start a meditation session'), findsOneWidget);
    await startSession(tester);
    expect(
      h.services.settingsRepository.lastSessionKind,
      SessionKind.meditation,
    );
    await shutDown(tester, h);

    // A fresh app with the saved preference preselects Meditation.
    final again = await pumpApp(
      tester,
      prefs: {'last_session_kind': 'meditation'},
    );
    expect(find.text('Start a meditation session'), findsOneWidget);
    await shutDown(tester, again);
  });

  testWidgets('the session type shows during calibration and the session', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await tester.tap(find.byKey(const ValueKey('kind-meditation')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-session')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Calibrating'), findsOneWidget);
    expect(_kindChip(tester), 'Meditation session');

    await tester.pump(const Duration(seconds: 3));
    h.estimator.score = 20;
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('live-score')), findsOneWidget);
    expect(_kindChip(tester), 'Meditation session');

    await h.services.session.end();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Session summary'), findsOneWidget);
    expect(_kindChip(tester), 'Meditation session');
    await shutDown(tester, h);
  });

  testWidgets('a focus session is labelled as such', (tester) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await startSession(tester);
    h.estimator.score = 70;
    await tester.pump(const Duration(seconds: 3));
    expect(_kindChip(tester), 'Focus session');
    await shutDown(tester, h);
  });

  testWidgets('meditation shows the calm score and Calm/Restless', (
    tester,
  ) async {
    final h = await pumpApp(tester, size: const Size(412, 915));
    await connectSimulator(tester);
    await tester.tap(find.byKey(const ValueKey('kind-meditation')));
    await tester.pump();
    await startSession(tester);

    String shown() =>
        tester.widget<Text>(find.byKey(const ValueKey('live-score'))).data!;
    String state() =>
        tester.widget<Text>(find.byKey(const ValueKey('live-state'))).data!;
    double focus() => h.services.session.live.value!.reading!.score!;

    h.estimator.score = 22;
    await tester.pump(const Duration(seconds: 25));
    expect(focus(), closeTo(22, 1));
    expect(shown(), (100 - focus()).round().toString());
    expect(state(), 'Calm');

    h.estimator.score = 82;
    await tester.pump(const Duration(seconds: 25));
    expect(focus(), closeTo(82, 1));
    expect(shown(), (100 - focus()).round().toString());
    expect(state(), 'Restless');

    h.estimator.artifacted = true;
    await tester.pump(const Duration(seconds: 3));
    expect(shown(), '–');
    expect(state(), 'Signal unavailable');
    await shutDown(tester, h);
  });
}
