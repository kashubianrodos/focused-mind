import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_engine.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/headband/models.dart';

import '../support/fake_estimator.dart';

void main() {
  late StreamController<List<EegSample>> samples;
  late List<FakeEstimator> estimators;
  late FocusEngine engine;
  late List<FocusReading> readings;
  Timer? feeder;

  FakeEstimator estimator() => estimators.last;

  void create() {
    samples = StreamController<List<EegSample>>.broadcast();
    estimators = [];
    engine = FocusEngine(
      samples: samples.stream,
      createEstimator: () {
        final e = FakeEstimator();
        estimators.add(e);
        return e;
      },
    );
    readings = [];
    engine.readings.listen(readings.add);
  }

  /// Streams 25 samples every 100 ms, like a 250 Hz headband.
  void startFeeding() {
    feeder = Timer.periodic(const Duration(milliseconds: 100), (_) {
      samples.add(List.filled(25, const EegSample(0, 0, 0, 0)));
    });
  }

  void stopFeeding() => feeder?.cancel();

  Future<CalibrationResult> calibrated(FakeAsync async) {
    final result = engine.calibrate();
    async.elapse(const Duration(seconds: 3));
    return result;
  }

  group('calibration', () {
    test('completes, reports progress and starts tracking', () {
      fakeAsync((async) {
        create();
        startFeeding();
        CalibrationResult? result;
        final progress = <int>[];
        engine.calibrationPercent.addListener(
          () => progress.add(engine.calibrationPercent.value),
        );
        engine.calibrate().then((r) => result = r);
        async.elapse(const Duration(seconds: 3));
        expect(result?.succeeded, isTrue);
        expect(progress.last, 100);
        expect(progress, contains(50));
        expect(engine.isTracking, isTrue);
        stopFeeding();
      });
    });

    test(
      'disturbed calibration fails after 60 s with a reason, then restarts',
      () {
        fakeAsync((async) {
          create();
          startFeeding();
          estimator().calibrationCanProgress = false;
          CalibrationResult? result;
          engine.calibrate().then((r) => result = r);
          async.elapse(const Duration(seconds: 59));
          expect(result, isNull);
          async.elapse(const Duration(seconds: 1));
          expect(result?.succeeded, isFalse);
          expect(result?.failure, CalibrationFailure.poorSignal);
          expect(result?.message, contains('movement'));
          expect(estimators.first.disposed, isTrue);

          // A restart uses a fresh estimator and can succeed.
          CalibrationResult? retry;
          engine.calibrate().then((r) => retry = r);
          async.elapse(const Duration(seconds: 3));
          expect(retry?.succeeded, isTrue);
          stopFeeding();
        });
      },
    );

    test('no data at all fails as noData', () {
      fakeAsync((async) {
        create();
        CalibrationResult? result;
        engine.calibrate().then((r) => result = r);
        async.elapse(const Duration(seconds: 60));
        expect(result?.failure, CalibrationFailure.noData);
      });
    });
  });

  group('rhythm shares', () {
    void expectSumsTo100(RhythmShares r) =>
        expect(r.theta + r.alpha + r.beta, closeTo(100, 1e-9));

    test('are published with each reading and add up to 100', () {
      fakeAsync((async) {
        create();
        startFeeding();
        calibrated(async);
        estimator().rhythms = RhythmShares.normalized(20, 30, 50);
        async.elapse(const Duration(seconds: 20));
        final r = readings.last.rhythms!;
        expectSumsTo100(r);
        expect(r.beta, closeTo(50, 0.5));
        stopFeeding();
      });
    });

    test(
      'are null while the score is unavailable and resume without reset',
      () {
        fakeAsync((async) {
          create();
          startFeeding();
          calibrated(async);
          estimator().rhythms = RhythmShares.normalized(20, 30, 50);
          async.elapse(const Duration(seconds: 20));

          estimator().artifacted = true;
          async.elapse(const Duration(seconds: 3));
          expect(readings.last.score, isNull);
          expect(readings.last.rhythms, isNull);

          estimator()
            ..artifacted = false
            ..rhythms = RhythmShares.normalized(50, 30, 20);
          async.elapse(const Duration(seconds: 2));
          final r = readings.last.rhythms!;
          expectSumsTo100(r);
          // Held, not reset: still between the old and the new shares.
          expect(r.beta, inExclusiveRange(20, 50));
          stopFeeding();
        });
      },
    );

    test('one outlier second is dampened', () {
      fakeAsync((async) {
        create();
        startFeeding();
        calibrated(async);
        estimator().rhythms = RhythmShares.normalized(20, 30, 50);
        async.elapse(const Duration(seconds: 20));
        estimator().rhythms = RhythmShares.normalized(80, 10, 10);
        async.elapse(const Duration(seconds: 1));
        final r = readings.last.rhythms!;
        expect(50 - r.beta, lessThan(40 / 2), reason: 'raw drop was 40');
        stopFeeding();
      });
    });
  });

  group('live focus score', () {
    test('publishes a 0–100 score at least once per second', () {
      fakeAsync((async) {
        create();
        startFeeding();
        calibrated(async);
        readings.clear();
        estimator().score = 72;
        async.elapse(const Duration(seconds: 10));
        expect(readings, hasLength(10));
        for (final r in readings) {
          expect(r.score, inInclusiveRange(0, 100));
        }
        // The EMA (τ = 3 s) runs on the focus index, from the baseline
        // (index 0, score 50) towards the index of 72: e^(−10/3) ≈ 3.57%
        // of the way is left after 10 s.
        const scale = ScoreScale();
        expect(
          readings.last.score,
          closeTo(scale.toScore(scale.toIndex(72) * (1 - 0.0357)), 0.05),
        );
        stopFeeding();
      });
    });

    test(
      'one outlier second is dampened and returns toward the steady level',
      () {
        fakeAsync((async) {
          create();
          startFeeding();
          calibrated(async);
          estimator().score = 70;
          async.elapse(const Duration(seconds: 20));
          final steady = readings.last.score!;

          estimator().score = 10;
          async.elapse(const Duration(seconds: 1));
          final afterOutlier = readings.last.score!;
          estimator().score = 70;
          async.elapse(const Duration(seconds: 6));

          final drop = steady - afterOutlier;
          expect(drop, greaterThan(0));
          expect(drop, lessThan(60 / 2), reason: 'raw drop was 60 points');
          expect(readings.last.score, closeTo(steady, 6));
          stopFeeding();
        });
      },
    );

    test(
      'artifacts make the score unavailable, not low, and it resumes in 3 s',
      () {
        fakeAsync((async) {
          create();
          startFeeding();
          calibrated(async);
          estimator().score = 65;
          async.elapse(const Duration(seconds: 10));

          estimator().artifacted = true;
          async.elapse(const Duration(seconds: 3));
          expect(readings.last.score, isNull);
          expect(readings.last.isAvailable, isFalse);
          expect(readings.last.left, SideQuality.poor);

          estimator().artifacted = false;
          async.elapse(const Duration(seconds: 3));
          expect(readings.last.score, closeTo(65, 1));
          stopFeeding();
        });
      },
    );

    test('no incoming data makes the score unavailable', () {
      fakeAsync((async) {
        create();
        startFeeding();
        calibrated(async);
        stopFeeding();
        async.elapse(const Duration(seconds: 2));
        expect(readings.last.score, isNull);
      });
    });

    test('per-side quality follows the side that is artifacted', () {
      fakeAsync((async) {
        create();
        startFeeding();
        calibrated(async);
        estimator().leftArtifacted = true;
        async.elapse(const Duration(seconds: 2));
        expect(readings.last.left, SideQuality.poor);
        expect(readings.last.right, SideQuality.good);
        expect(readings.last.score, isNotNull);
        stopFeeding();
      });
    });
  });
}
