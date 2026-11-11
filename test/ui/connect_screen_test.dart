import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/headband/models.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('scan lists the simulated headband and connects to it', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    expect(find.text('Connect your headband'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Simulated headband'), findsOneWidget);
    expect(find.text('Serial SIM-0001'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('device-SIM-0001')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Connected'), findsOneWidget);
    expect(find.text('Battery 80%'), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('per-electrode contact quality is shown outside a session', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    h.services.simulator!.ohms[Electrode.t4] = double.infinity;
    await connectSimulator(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('O1 (back left): good'), findsOneWidget);
    expect(find.text('T4 (right temple): poor'), findsOneWidget);
    expect(find.textContaining('Adjust the band'), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('low battery shows a warning', (tester) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    h.services.simulator!.setBattery(15);
    await tester.pump();
    expect(find.text('Battery low: 15%'), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('remembered headband is offered as one-click connect', (
    tester,
  ) async {
    final first = await pumpApp(tester);
    await connectSimulator(tester);
    await shutDown(tester, first);

    // Same preferences, as on the next launch.
    final saved = first.services.settingsRepository.loadLastDevice()!;
    final h = await pumpApp(
      tester,
      prefs: {
        'last_device':
            '{"name":"${saved.name}","serialNumber":'
            '"${saved.serialNumber}","address":"${saved.address}",'
            '"family":"${saved.family.name}","model":0}',
      },
    );
    expect(find.text('Connect to Simulated headband'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick-connect')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Connected'), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('a failed connection reports it and offers to retry', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    h.services.simulator!.connectable = false;
    await tester.tap(find.byKey(const ValueKey('scan')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('device-SIM-0001')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Could not connect'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan')), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('start is disabled until a headband is connected', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    final start = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Start session'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(start.onPressed, isNull);
    expect(find.text('Connect a headband to start a session.'), findsOneWidget);
    await shutDown(tester, h);
  });
}
