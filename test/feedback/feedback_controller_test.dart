import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_controller.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';

import '../support/fake_audio_output.dart';

void main() {
  late FakeAudioOutput audio;
  late FeedbackController controller;

  void create(FeedbackSettings settings) {
    audio = FakeAudioOutput();
    controller = FeedbackController(audio, settings: settings);
    controller.start();
  }

  const alert = FeedbackSettings(volume: 1, threshold: 40);
  const continuous = FeedbackSettings(
    mode: FeedbackMode.continuous,
    volume: 1,
    threshold: 40,
  );

  group('alert mode', () {
    test('silent without a drop; fades in over ~2 s on a drop', () {
      fakeAsync((async) {
        create(alert);
        controller.update(score: 70, dropActive: false);
        async.elapse(const Duration(seconds: 3));
        expect(audio.volume, 0);
        expect(audio.playing, isFalse);

        controller.update(score: 0, dropActive: true);
        async.elapse(const Duration(milliseconds: 1000));
        expect(audio.playing, isTrue);
        expect(audio.volume, closeTo(0.5, 0.05), reason: 'halfway at 1 s');
        async.elapse(const Duration(milliseconds: 1000));
        expect(audio.volume, closeTo(1.0, 1e-9));
      });
    });

    test('fades out over ~2 s on recovery, then pauses the player', () {
      fakeAsync((async) {
        create(alert);
        controller.update(score: 0, dropActive: true);
        async.elapse(const Duration(seconds: 3));
        expect(audio.volume, 1);

        controller.update(score: 80, dropActive: false);
        async.elapse(const Duration(milliseconds: 1000));
        expect(audio.volume, closeTo(0.5, 0.05));
        async.elapse(const Duration(milliseconds: 1000));
        expect(audio.volume, 0);
        expect(audio.playing, isTrue, reason: 'stays loaded for a while');
        async.elapse(const Duration(seconds: 5));
        expect(audio.playing, isFalse);
      });
    });
  });

  group('continuous mode', () {
    test(
      'plays while focused, fades to silence on a drop and back on recovery',
      () {
        fakeAsync((async) {
          create(continuous);
          controller.update(score: 100, dropActive: false);
          async.elapse(const Duration(seconds: 2));
          expect(audio.playing, isTrue);
          expect(audio.volume, closeTo(1.0, 1e-9));

          controller.update(score: 20, dropActive: true);
          async.elapse(const Duration(seconds: 1));
          expect(audio.volume, closeTo(0.5, 0.05));
          async.elapse(const Duration(seconds: 1));
          expect(audio.volume, 0);

          controller.update(score: 100, dropActive: false);
          async.elapse(const Duration(seconds: 2));
          expect(audio.playing, isTrue);
          expect(audio.volume, closeTo(1.0, 1e-9));
        });
      },
    );

    test(
      'signal returning after a silent unavailable period fades back in',
      () {
        fakeAsync((async) {
          create(continuous);
          controller.update(score: 100, dropActive: false);
          async.elapse(const Duration(seconds: 2));
          for (var i = 0; i < 11; i++) {
            controller.update(score: null, dropActive: false);
            async.elapse(const Duration(seconds: 1));
          }
          async.elapse(const Duration(seconds: 2));
          expect(audio.volume, 0);
          controller.update(score: 100, dropActive: false);
          async.elapse(const Duration(seconds: 2));
          expect(audio.volume, closeTo(1.0, 1e-9));
        });
      },
    );
  });

  test('switching mode mid-session re-targets with a ~2 s fade', () {
    fakeAsync((async) {
      create(alert);
      controller.update(score: 100, dropActive: false);
      async.elapse(const Duration(seconds: 2));
      expect(audio.volume, 0);

      controller.applySettings(continuous);
      async.elapse(const Duration(seconds: 1));
      expect(audio.volume, closeTo(0.5, 0.05));
      async.elapse(const Duration(seconds: 1));
      expect(audio.volume, closeTo(1.0, 1e-9));

      controller.applySettings(alert);
      async.elapse(const Duration(seconds: 2));
      expect(audio.volume, 0);
    });
  });

  test('mute silences feedback for the session in either mode', () {
    fakeAsync((async) {
      create(continuous);
      controller.update(score: 100, dropActive: false);
      async.elapse(const Duration(seconds: 2));
      controller.mute();
      async.elapse(const Duration(seconds: 2));
      expect(audio.volume, 0);
      controller.update(score: 100, dropActive: false);
      async.elapse(const Duration(seconds: 2));
      expect(audio.volume, 0);
      expect(controller.muted, isTrue);
    });
  });

  test('volume change applies immediately and caps loudness', () {
    fakeAsync((async) {
      create(alert);
      controller.update(score: 0, dropActive: true);
      async.elapse(const Duration(seconds: 2));
      controller.applySettings(alert.copyWith(volume: 0.3));
      async.elapse(const Duration(seconds: 2));
      expect(audio.volume, closeTo(0.3, 1e-9));
    });
  });

  test('changing the soundscape reloads the loop', () {
    fakeAsync((async) {
      create(alert);
      expect(audio.loaded, Soundscape.birds);
      controller.applySettings(alert.copyWith(soundscape: Soundscape.ocean));
      async.flushMicrotasks();
      expect(audio.loaded, Soundscape.ocean);
    });
  });

  test('stop fades out', () {
    fakeAsync((async) {
      create(alert);
      controller.update(score: 0, dropActive: true);
      async.elapse(const Duration(seconds: 2));
      controller.stop();
      async.elapse(const Duration(seconds: 2));
      expect(audio.volume, 0);
    });
  });
}
