import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/app/services.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/e2e_scenario.dart';
import '../support/fake_audio_output.dart';
import '../support/memory_session_repository.dart';
import '../support/native_libs.dart';

/// The 7.1 scenario on the host, on fake time, with BrainBit's real
/// EmotionalMath processing the simulator's EEG.
void main() {
  setUpAll(loadVendorLibraries);

  for (final mode in FeedbackMode.values) {
    test('full simulated session in ${mode.name} mode', () {
      SharedPreferences.setMockInitialValues({});
      fakeAsync((async) {
        final audio = FakeAudioOutput();
        AppServices? services;
        AppServices.create(
          includeSimulator: true,
          includeDevices: false,
          audio: audio,
          sessionRepository: MemorySessionRepository(),
        ).then((s) => services = s);
        async.flushMicrotasks();
        expect(services, isNotNull);

        Object? error;
        StackTrace? stack;
        var done = false;
        runSimulatedSession(
          services: services!,
          audio: audio,
          mode: mode,
          advance: Future<void>.delayed,
        ).then(
          (_) => done = true,
          onError: (Object e, StackTrace s) {
            error = e;
            stack = s;
          },
        );
        async.elapse(const Duration(minutes: 3));
        if (error != null) Error.throwWithStackTrace(error!, stack!);
        expect(done, isTrue);

        services!.connection.disconnect();
        async.elapse(const Duration(seconds: 10));
      });
    });
  }

  test('full simulated meditation session', () {
    SharedPreferences.setMockInitialValues({});
    fakeAsync((async) {
      final audio = FakeAudioOutput();
      AppServices? services;
      AppServices.create(
        includeSimulator: true,
        includeDevices: false,
        audio: audio,
        sessionRepository: MemorySessionRepository(),
      ).then((s) => services = s);
      async.flushMicrotasks();

      Object? error;
      StackTrace? stack;
      var done = false;
      runSimulatedMeditation(
        services: services!,
        audio: audio,
        advance: Future<void>.delayed,
      ).then(
        (_) => done = true,
        onError: (Object e, StackTrace s) {
          error = e;
          stack = s;
        },
      );
      async.elapse(const Duration(minutes: 3));
      if (error != null) Error.throwWithStackTrace(error!, stack!);
      expect(done, isTrue);

      services!.connection.disconnect();
      async.elapse(const Duration(seconds: 10));
    });
  });
}
