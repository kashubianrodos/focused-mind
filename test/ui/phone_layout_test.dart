import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Pixel 8 in logical pixels, at its 115 % text size. Any RenderFlex
/// overflow fails the test.
const phone = Size(412, 915);

void main() {
  testWidgets('every screen fits a phone, idle and in a live session', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.15;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = await pumpApp(tester, size: phone);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await connectSimulator(tester);
    await tester.tap(find.byKey(const ValueKey('start-session')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    h.estimator.score = 80;
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const ValueKey('live-score')), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(seconds: 1));
    await shutDown(tester, h);
  });
}
