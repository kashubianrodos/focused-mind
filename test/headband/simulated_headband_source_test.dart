import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_estimator.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/headband/headband_source.dart';
import 'package:focused_mind/headband/models.dart';
import 'package:focused_mind/headband/simulated_headband_source.dart';

import '../support/native_libs.dart';

void main() {
  setUpAll(loadVendorLibraries);

  test('streams 250 samples per second in signal mode', () {
    fakeAsync((async) {
      final sim = SimulatedHeadbandSource();
      var count = 0;
      sim.signal.listen((b) => count += b.length);
      sim.connect(SimulatedHeadbandSource.device);
      async.elapse(const Duration(seconds: 1));
      sim.setMode(StreamMode.signal);
      async.flushMicrotasks();
      count = 0;
      async.elapse(const Duration(seconds: 4));
      expect(count, 1000);
      sim.dispose();
    });
  });

  test('reports contact once per second in resistance mode', () {
    fakeAsync((async) {
      final sim = SimulatedHeadbandSource()..ohms[Electrode.t3] = 5e6;
      final reports = <ContactReport>[];
      sim.resistance.listen(reports.add);
      sim.connect(SimulatedHeadbandSource.device);
      async.elapse(const Duration(seconds: 1));
      sim.setMode(StreamMode.resistance);
      async.elapse(const Duration(seconds: 3));
      expect(reports, hasLength(3));
      expect(reports.last[Electrode.t3], ContactQuality.poor);
      expect(reports.last[Electrode.o1], ContactQuality.good);
      sim.dispose();
    });
  });

  test('focus level moves the EmotionalMath focus index the same way', () {
    fakeAsync((async) {
      final sim = SimulatedHeadbandSource();
      final estimator = EmotionalMathEstimator();
      final index = <double>[];
      sim.signal.listen((b) {
        final i = estimator.process(b).index;
        if (i != null) index.add(i);
      });
      sim.connect(SimulatedHeadbandSource.device);
      async.elapse(const Duration(seconds: 1));
      sim.setMode(StreamMode.signal);
      async.flushMicrotasks();
      estimator.startCalibration();
      async.elapse(const Duration(seconds: 15));
      expect(estimator.isCalibrationFinished, isTrue);

      double averageAt(double focus) {
        sim.focus = focus;
        index.clear();
        async.elapse(const Duration(seconds: 10));
        final tail = index.skip(index.length ~/ 2).toList();
        return tail.reduce((a, b) => a + b) / tail.length;
      }

      final low = averageAt(0.1);
      final high = averageAt(0.9);
      // Calibrated at the simulator's default (middle) focus level: lower
      // focus reads below the baseline score, higher focus above it.
      const scale = ScoreScale();
      expect(high, greaterThan(0));
      expect(low, lessThan(0));
      expect(scale.toScore(high), greaterThan(70));
      expect(scale.toScore(low), lessThan(30));
      estimator.dispose();
      sim.dispose();
    });
  });

  test('EmotionalMath reports rhythm shares that follow simulated focus', () {
    fakeAsync((async) {
      final sim = SimulatedHeadbandSource();
      final estimator = EmotionalMathEstimator();
      final shares = <RhythmShares>[];
      sim.signal.listen((b) {
        final r = estimator.process(b).rhythms;
        if (r != null) shares.add(r);
      });
      sim.connect(SimulatedHeadbandSource.device);
      async.elapse(const Duration(seconds: 1));
      sim.setMode(StreamMode.signal);
      async.flushMicrotasks();
      estimator.startCalibration();
      async.elapse(const Duration(seconds: 15));
      expect(estimator.isCalibrationFinished, isTrue);

      RhythmShares averageAt(double focus) {
        sim.focus = focus;
        shares.clear();
        async.elapse(const Duration(seconds: 10));
        final tail = shares.skip(shares.length ~/ 2).toList();
        expect(tail, isNotEmpty);
        double avg(double Function(RhythmShares) f) =>
            tail.map(f).reduce((a, b) => a + b) / tail.length;
        return RhythmShares.normalized(
          avg((s) => s.theta),
          avg((s) => s.alpha),
          avg((s) => s.beta),
        )!;
      }

      final low = averageAt(0.1);
      final high = averageAt(0.9);
      for (final s in [low, high]) {
        expect(s.theta + s.alpha + s.beta, closeTo(100, 1e-6));
      }
      expect(high.beta, greaterThan(low.beta));
      expect(high.alpha + high.theta, lessThan(low.alpha + low.theta));
      estimator.dispose();
      sim.dispose();
    });
  });

  test('movement artifacts are flagged by EmotionalMath', () {
    fakeAsync((async) {
      final sim = SimulatedHeadbandSource();
      final estimator = EmotionalMathEstimator();
      var artifacted = 0;
      sim.signal.listen((b) {
        if (estimator.process(b).artifacted) artifacted++;
      });
      sim.connect(SimulatedHeadbandSource.device);
      async.elapse(const Duration(seconds: 1));
      sim.setMode(StreamMode.signal);
      async.elapse(const Duration(seconds: 10));
      expect(artifacted, 0);
      sim.artifacts = true;
      async.elapse(const Duration(seconds: 6));
      expect(artifacted, greaterThan(10));
      estimator.dispose();
      sim.dispose();
    });
  });

  test('dropLink reports the outage and blocks reconnect until restored', () {
    fakeAsync((async) {
      final sim = SimulatedHeadbandSource();
      final links = <bool>[];
      sim.linkChanges.listen(links.add);
      sim.connect(SimulatedHeadbandSource.device);
      async.elapse(const Duration(seconds: 1));
      sim.dropLink(restoreAfter: const Duration(seconds: 10));
      async.flushMicrotasks();
      expect(links, [false]);

      Object? error;
      sim.connect(SimulatedHeadbandSource.device).catchError((Object e) {
        error = e;
      });
      async.elapse(const Duration(seconds: 1));
      expect(error, isNotNull);

      async.elapse(const Duration(seconds: 10));
      var connected = false;
      sim.connect(SimulatedHeadbandSource.device).then((_) => connected = true);
      async.elapse(const Duration(seconds: 1));
      expect(connected, isTrue);
      sim.dispose();
    });
  });
}
