import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('the wellness notice appears on first launch only', (
    tester,
  ) async {
    final first = await pumpApp(tester, noticeSeen: false);
    await tester.pump();
    expect(find.text('Before you start'), findsOneWidget);
    expect(find.textContaining('not a medical device'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pump();
    expect(find.text('Before you start'), findsNothing);
    expect(first.services.settingsRepository.wellnessNoticeSeen, isTrue);
    await shutDown(tester, first);

    // Next launch: the flag is stored, so no dialog.
    final second = await pumpApp(tester);
    await tester.pump();
    expect(find.text('Before you start'), findsNothing);
    await shutDown(tester, second);
  });

  testWidgets('the same wording is in Settings › About', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('not a medical device'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('not a medical device'), findsOneWidget);
    await shutDown(tester, h);
  });
}
