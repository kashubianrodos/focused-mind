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
    await tester.pump();
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

  testWidgets('forest is listed and previewable', (tester) async {
    final h = await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.text('Forest'));
    await tester.pump();
    expect(h.services.settings.value.soundscape, Soundscape.forest);
    await tester.tap(find.byKey(const ValueKey('preview-forest')));
    await tester.pump();
    expect(h.audio.previews, [Soundscape.forest]);
    await shutDown(tester, h);
  });

  testWidgets('mono switch saves the setting and previews follow it', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await openSettings(tester);
    final toggle = find.byKey(const ValueKey('mono'));
    await tester.ensureVisible(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pump();
    expect(h.services.settings.value.mono, isTrue);
    expect(h.services.settingsRepository.loadFeedback().mono, isTrue);
    final preview = find.byKey(const ValueKey('preview-birds'));
    await tester.scrollUntilVisible(preview, -300);
    await tester.pump();
    await tester.tap(preview);
    await tester.pump();
    expect(h.audio.previewMono, [true]);
    await shutDown(tester, h);
  });

  testWidgets('test mode is off by default and persists', (tester) async {
    final h = await pumpApp(tester);
    await openSettings(tester);
    final toggle = find.byKey(const ValueKey('test-mode'));
    await tester.scrollUntilVisible(toggle, 300);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pump();
    expect(h.services.testMode.value, isTrue);
    expect(h.services.settingsRepository.testMode, isTrue);
    await shutDown(tester, h);
  });

  testWidgets('licenses button opens the license page', (tester) async {
    final h = await pumpApp(tester);
    await openSettings(tester);
    final button = find.byKey(const ValueKey('licenses'));
    await tester.scrollUntilVisible(button, 300);
    // Scroll to the very end so the button sits fully inside the window.
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
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
