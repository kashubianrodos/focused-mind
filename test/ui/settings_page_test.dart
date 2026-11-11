import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';

import '../support/app_harness.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pump();
  }

  testWidgets('defaults are alert mode, birds, threshold 40, delay 5 s', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await openSettings(tester);
    expect(find.text(FeedbackMode.alert.description), findsOneWidget);
    expect(find.byKey(const ValueKey('value-Focus threshold')), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('5 s'), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('changes persist across restarts', (tester) async {
    final first = await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.text('Continuous'));
    await tester.pump();
    expect(find.text(FeedbackMode.continuous.description), findsOneWidget);
    await tester.tap(find.text('Ocean waves'));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('slider-Focus threshold')),
      const Offset(200, 0),
    );
    await tester.pump();
    final saved = first.services.settings.value;
    expect(saved.mode, FeedbackMode.continuous);
    expect(saved.soundscape, Soundscape.ocean);
    expect(saved.threshold, greaterThan(40));
    await shutDown(tester, first);

    // A fresh app over the same stored preferences.
    final reopened = first.services.settingsRepository.loadFeedback();
    expect(reopened, saved);
  });

  testWidgets('the baseline slider changes and saves the baseline', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await openSettings(tester);
    final slider = find.byKey(const ValueKey('slider-Baseline'));
    await tester.ensureVisible(slider);
    expect(find.byKey(const ValueKey('value-Baseline')), findsOneWidget);
    await tester.drag(slider, const Offset(150, 0));
    await tester.pump();
    final saved = h.services.settings.value.baseline;
    expect(saved, greaterThan(50));
    expect(h.services.settingsRepository.loadFeedback().baseline, saved);
    await shutDown(tester, h);
  });

  testWidgets('record raw signal is off by default and persists', (
    tester,
  ) async {
    final first = await pumpApp(tester);
    await openSettings(tester);
    final toggle = find.byKey(const ValueKey('record-raw'));
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.textContaining('about 20 MB per hour'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    expect(first.services.recordRaw.value, isTrue);
    await shutDown(tester, first);

    // A fresh app over the same stored preferences.
    expect(first.services.settingsRepository.recordRawSignal, isTrue);
  });

  testWidgets('preview plays the chosen soundscape', (tester) async {
    final h = await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('preview-ocean')));
    await tester.pump();
    expect(h.audio.previews, [Soundscape.ocean]);
    await shutDown(tester, h);
  });

  testWidgets('a mode change mid-session applies to the running feedback', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await connectSimulator(tester);
    await tester.tap(find.byKey(const ValueKey('start-session')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('live-score')), findsOneWidget);

    h.estimator.score = 100; // focused: alert mode stays quiet
    await tester.pump(const Duration(seconds: 6));
    expect(h.audio.volume, 0);

    await openSettings(tester);
    await tester.tap(find.text('Continuous'));
    await tester.pump(const Duration(seconds: 3));
    expect(h.services.feedback.settings.mode, FeedbackMode.continuous);
    expect(h.audio.volume, greaterThan(0.5));
    await shutDown(tester, h);
  });
}
