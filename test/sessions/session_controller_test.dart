import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_controller.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/focus_engine.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/session_kind.dart';
import 'package:focused_mind/headband/headband_connection.dart';
import 'package:focused_mind/headband/models.dart';
import 'package:focused_mind/headband/simulated_headband_source.dart';
import 'package:focused_mind/sessions/session_controller.dart';
import 'package:focused_mind/sessions/session_models.dart';

import '../support/fake_audio_output.dart';
import '../support/fake_estimator.dart';
import '../support/memory_session_repository.dart';

class Harness {
  Harness() {
    connection = HeadbandConnection(sim);
    feedback = FeedbackController(audio, settings: settings.value);
    controller = SessionController(
      connection: connection,
      feedback: feedback,
      repository: repository,
      settings: settings,
      createEngine: () => FocusEngine(
        samples: connection.samples,
        createEstimator: () {
          final e = FakeEstimator();
          estimators.add(e);
          return e;
        },
      ),
    );
  }

  final sim = SimulatedHeadbandSource();
  final audio = FakeAudioOutput();
  final repository = MemorySessionRepository();
  final settings = ValueNotifier(
    const FeedbackSettings(volume: 1, threshold: 40),
  );
  final estimators = <FakeEstimator>[];
  late final HeadbandConnection connection;
  late final FeedbackController feedback;
  late final SessionController controller;

  void connect(FakeAsync async) {
    connection.connect(SimulatedHeadbandSource.device);
    async.elapse(const Duration(seconds: 1));
    expect(connection.isConnected, isTrue);
  }

  /// Starts a session and runs through signal check and calibration.
  void startTracking(
    FakeAsync async, {
    Duration? planned,
    SessionKind kind = SessionKind.focus,
  }) {
    controller.start(planned: planned, kind: kind);
    async.elapse(const Duration(seconds: 2)); // contact report + calibration
    async.elapse(const Duration(seconds: 3));
    expect(controller.phase.value, SessionPhase.running);
  }

  void setScore(double s) => estimators.last.score = s;
}

void main() {
  test('start is blocked while no headband is connected', () {
    fakeAsync((async) {
      final h = Harness();
      expect(h.controller.canStart, isFalse);
      bool? started;
      h.controller.start().then((v) => started = v);
      async.flushMicrotasks();
      expect(started, isFalse);
      expect(h.controller.phase.value, SessionPhase.idle);
    });
  });

  test('poor contact blocks calibration until the band is adjusted', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.sim.ohms[Electrode.o2] = double.infinity;
      h.controller.start();
      async.elapse(const Duration(seconds: 5));
      expect(h.controller.phase.value, SessionPhase.signalCheck);
      expect(h.controller.contact!.poorElectrodes, [Electrode.o2]);
      expect(h.estimators, isEmpty, reason: 'calibration has not started');

      h.sim.ohms[Electrode.o2] = 200e3;
      async.elapse(const Duration(seconds: 1));
      expect(h.controller.phase.value, SessionPhase.calibrating);
      async.elapse(const Duration(seconds: 3));
      expect(h.controller.phase.value, SessionPhase.running);
    });
  });

  test('failed calibration can be retried', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.controller.start();
      async.elapse(const Duration(seconds: 1, milliseconds: 100));
      expect(h.controller.phase.value, SessionPhase.calibrating);
      h.estimators.last.calibrationCanProgress = false;
      async.elapse(const Duration(seconds: 61));
      expect(h.controller.phase.value, SessionPhase.calibrationFailed);
      expect(h.controller.calibrationError, isNotNull);

      h.controller.retryCalibration();
      async.elapse(const Duration(seconds: 5));
      expect(h.controller.phase.value, SessionPhase.running);
    });
  });

  test(
    'planned duration elapses: end chime, feedback stopped, summary saved',
    () {
      fakeAsync((async) {
        final h = Harness();
        h.connect(async);
        h.startTracking(async, planned: const Duration(seconds: 30));
        h.setScore(10); // distracted → alert feedback plays
        async.elapse(const Duration(seconds: 20));
        expect(h.audio.volume, greaterThan(0));

        async.elapse(const Duration(seconds: 12));
        expect(h.controller.phase.value, SessionPhase.ended);
        expect(h.audio.chimes, 1);
        async.elapse(const Duration(seconds: 3));
        expect(h.audio.volume, 0, reason: 'feedback fades out on end');

        final record = h.controller.lastRecord!;
        expect(record.summary.duration, const Duration(seconds: 30));
        expect(record.summary.drops, 1);
        expect(h.repository.saved.keys, [record.summary.id]);
      });
    },
  );

  test('a 20 s disconnect pauses and resumes without recalibrating', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.startTracking(async);
      h.setScore(80);
      async.elapse(const Duration(seconds: 10));
      final elapsedBefore = h.controller.live.value!.elapsed;

      h.sim.dropLink(restoreAfter: const Duration(seconds: 18));
      async.elapse(const Duration(seconds: 1));
      expect(h.controller.phase.value, SessionPhase.paused);
      async.elapse(const Duration(seconds: 10));
      expect(
        h.controller.live.value!.elapsed,
        elapsedBefore,
        reason: 'timing is paused',
      );

      async.elapse(const Duration(seconds: 10)); // reconnects at ~20 s
      expect(h.connection.isConnected, isTrue);
      expect(h.controller.phase.value, SessionPhase.running);
      expect(h.estimators, hasLength(1), reason: 'no recalibration');

      async.elapse(const Duration(seconds: 10));
      final record = (h.controller.end()..ignore());
      async.flushMicrotasks();
      record.then((r) {
        expect(
          r!.marks.map((m) => m.kind),
          containsAll([MarkKind.gapStart, MarkKind.gapEnd]),
        );
        expect(r.timeline.where((p) => p.gap), isNotEmpty);
        // Gap seconds are excluded from the session duration.
        expect(r.summary.duration.inSeconds, lessThan(r.timeline.length));
      });
      async.flushMicrotasks();
      expect(h.controller.phase.value, SessionPhase.ended);
    });
  });

  test('a headband that never comes back ends the session and keeps it', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.startTracking(async);
      async.elapse(const Duration(seconds: 10));
      h.sim.dropLink(); // never restored
      async.elapse(const Duration(seconds: 61));
      expect(h.connection.state.value, HeadbandConnectionState.disconnected);
      expect(h.controller.phase.value, SessionPhase.ended);
      expect(h.repository.saved, hasLength(1));
    });
  });

  test('settings changed mid-session apply to feedback immediately', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.startTracking(async);
      h.setScore(100);
      async.elapse(const Duration(seconds: 5));
      expect(h.audio.volume, 0, reason: 'alert mode is quiet while focused');

      h.settings.value = h.settings.value.copyWith(
        mode: FeedbackMode.continuous,
      );
      async.elapse(const Duration(seconds: 3));
      // The smoothed score is still just under 100, so slightly below full.
      expect(h.audio.volume, greaterThan(0.9));
    });
  });

  test('a baseline change mid-session rescales the score at once', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.startTracking(async);
      h.setScore(50); // the calibration level
      async.elapse(const Duration(seconds: 10));
      expect(h.controller.live.value!.reading!.score, closeTo(50, 0.5));

      h.settings.value = h.settings.value.copyWith(baseline: 70);
      async.elapse(const Duration(seconds: 1));
      expect(h.controller.live.value!.reading!.score, closeTo(70, 0.5));
    });
  });

  test('recorded zones follow the scale in force at each second', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.startTracking(async);
      h.setScore(45);
      async.elapse(const Duration(seconds: 15));
      var last = h.controller.live.value!.points.last;
      expect(last.zone, FocusZone.relaxation);
      expect(last.rhythms, isNotNull);

      // A baseline change moves the score and the zone edges together:
      // the same brain activity stays in the same zone.
      h.settings.value = h.settings.value.copyWith(baseline: 70);
      async.elapse(const Duration(seconds: 2));
      last = h.controller.live.value!.points.last;
      expect(last.score, greaterThan(50), reason: 'score rescaled');
      expect(last.zone, FocusZone.relaxation);
      expect(last.zone, const ScoreScale(baseline: 70).zoneOf(last.score!));
    });
  });

  test('mute keeps tracking and recording drops', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.startTracking(async);
      h.controller.mute();
      h.setScore(5);
      async.elapse(const Duration(seconds: 15));
      expect(h.audio.volume, 0);
      expect(
        h.controller.live.value!.marks.map((m) => m.kind),
        contains(MarkKind.drop),
      );
    });
  });

  test('a meditation session rewards calm: sound while relaxed, silence '
      'after a restless stretch, back after recovery', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      // Alert in settings must not matter for meditation.
      h.startTracking(async, kind: SessionKind.meditation);
      expect(h.controller.live.value!.kind, SessionKind.meditation);

      h.setScore(10); // Deep relaxation
      async.elapse(const Duration(seconds: 15));
      expect(h.controller.live.value!.state, FocusState.focused); // Calm
      expect(h.audio.volume, greaterThan(0.8));

      h.setScore(85); // Concentration and above: restless
      async.elapse(const Duration(seconds: 20));
      expect(h.controller.live.value!.state, FocusState.distracted);
      expect(
        h.controller.live.value!.marks.map((m) => m.kind),
        contains(MarkKind.drop),
      );
      expect(h.audio.volume, 0);

      h.setScore(10);
      async.elapse(const Duration(seconds: 20));
      expect(
        h.controller.live.value!.marks.map((m) => m.kind),
        contains(MarkKind.recovery),
      );
      expect(h.audio.volume, greaterThan(0.8));

      h.controller.end();
      async.flushMicrotasks();
      final summary = h.controller.lastRecord!.summary;
      expect(summary.kind, SessionKind.meditation);
      expect(summary.drops, 1);
      expect(summary.timeIn(FocusState.focused), greaterThan(Duration.zero));
      expect(summary.timeIn(FocusState.neutral), Duration.zero);
      expect(
        h.repository.saved[summary.id]!.summary.kind,
        SessionKind.meditation,
      );
    });
  });

  test('focus sessions record their kind', () {
    fakeAsync((async) {
      final h = Harness();
      h.connect(async);
      h.startTracking(async);
      expect(h.controller.live.value!.kind, SessionKind.focus);
      async.elapse(const Duration(seconds: 5));
      h.controller.end();
      async.flushMicrotasks();
      expect(h.controller.lastRecord!.summary.kind, SessionKind.focus);
    });
  });
}
