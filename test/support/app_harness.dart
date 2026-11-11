import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/app/app.dart';
import 'package:focused_mind/app/services.dart';
import 'package:focused_mind/focus/focus_estimator.dart';
import 'package:focused_mind/sessions/export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio_output.dart';
import 'fake_estimator.dart';
import 'memory_session_repository.dart';

class AppHarness {
  AppHarness(this.services, this.audio, this.repository, this.estimators);

  final AppServices services;
  final FakeAudioOutput audio;
  final MemorySessionRepository repository;
  final List<FakeEstimator> estimators;

  FakeEstimator get estimator => estimators.last;
}

/// Builds the real app with the simulated headband, fake audio, an
/// in-memory session store and (by default) a scriptable estimator.
Future<AppHarness> pumpApp(
  WidgetTester tester, {
  bool noticeSeen = true,
  Map<String, Object> prefs = const {},
  MemorySessionRepository? repository,
  FocusEstimator Function()? createEstimator,
  PickFolder? pickExportFolder,
}) async {
  SharedPreferences.setMockInitialValues({
    if (noticeSeen) 'wellness_notice_seen': true,
    ...prefs,
  });
  await tester.binding.setSurfaceSize(const Size(1280, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final audio = FakeAudioOutput();
  final repo = repository ?? MemorySessionRepository();
  final estimators = <FakeEstimator>[];
  final services = await AppServices.create(
    includeSimulator: true,
    includeDevices: false,
    audio: audio,
    sessionRepository: repo,
    pickExportFolder: pickExportFolder,
    createEstimator:
        createEstimator ??
        () {
          final e = FakeEstimator();
          estimators.add(e);
          return e;
        },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const FocusedMindApp(),
    ),
  );
  await tester.pump();
  return AppHarness(services, audio, repo, estimators);
}

/// Stops every timer so the test ends cleanly.
Future<void> shutDown(WidgetTester tester, AppHarness h) async {
  await h.services.session.end();
  await h.services.connection.disconnect();
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpWidget(const SizedBox());
  await h.services.dispose();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> connectSimulator(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('scan')));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const ValueKey('device-SIM-0001')));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}
