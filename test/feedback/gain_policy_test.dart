import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/feedback/gain_policy.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/session_kind.dart';

double gain({
  FeedbackMode mode = FeedbackMode.alert,
  bool drop = false,
  double? score = 50,
  double threshold = 40,
  double volume = 1,
  bool muted = false,
  int unavailableSeconds = 0,
}) => targetGain(
  mode: mode,
  dropActive: drop,
  score: score,
  threshold: threshold,
  volume: volume,
  muted: muted,
  unavailableFor: Duration(seconds: unavailableSeconds),
);

void main() {
  group('alert mode', () {
    test('silent while no drop is active', () {
      expect(gain(score: 10), 0);
      expect(gain(score: 90), 0);
    });

    test('plays when a drop is active, louder the deeper the deficit', () {
      final shallow = gain(drop: true, score: 38);
      final deep = gain(drop: true, score: 5);
      expect(shallow, greaterThan(0));
      expect(deep, greaterThan(shallow));
      expect(gain(drop: true, score: 0), 1.0);
    });

    test('never exceeds the configured volume', () {
      expect(gain(drop: true, score: 0, volume: 0.5), 0.5);
      expect(gain(drop: true, score: 39, volume: 0.5), lessThanOrEqualTo(0.5));
    });

    test('neutral (score above threshold) during a drop keeps playing', () {
      expect(gain(drop: true, score: 45), greaterThan(0));
    });
  });

  group('continuous mode', () {
    const c = FeedbackMode.continuous;

    test('plays while no drop is active, louder with higher focus', () {
      final low = gain(mode: c, score: 45);
      final high = gain(mode: c, score: 95);
      expect(low, greaterThan(0));
      expect(high, greaterThan(low));
      expect(gain(mode: c, score: 100), 1.0);
    });

    test('silent while a drop is active', () {
      expect(gain(mode: c, drop: true, score: 90), 0);
      expect(gain(mode: c, drop: true, score: 10), 0);
    });

    test('never exceeds the configured volume', () {
      expect(gain(mode: c, score: 100, volume: 0.3), closeTo(0.3, 1e-9));
    });
  });

  group('overrides in both modes', () {
    for (final mode in FeedbackMode.values) {
      test('$mode: muted is silent', () {
        expect(gain(mode: mode, drop: true, score: 10, muted: true), 0);
        expect(gain(mode: mode, score: 90, muted: true), 0);
      });

      test('$mode: unavailable for more than 10 s is silent', () {
        expect(
          gain(mode: mode, drop: true, score: 10, unavailableSeconds: 11),
          0,
        );
        expect(gain(mode: mode, score: 90, unavailableSeconds: 11), 0);
      });

      test('$mode: unavailable up to 10 s keeps the last level', () {
        final before = mode == FeedbackMode.alert
            ? gain(mode: mode, drop: true, score: 10)
            : gain(mode: mode, score: 90);
        final during = mode == FeedbackMode.alert
            ? gain(mode: mode, drop: true, score: 10, unavailableSeconds: 10)
            : gain(mode: mode, score: 90, unavailableSeconds: 10);
        expect(during, before);
      });
    }
  });

  group('meditation', () {
    const scale = ScoreScale(); // boundary 50, Deep relaxation below ~12
    double med({
      bool drop = false,
      double? score = 30,
      FeedbackMode mode = FeedbackMode.alert,
      double volume = 1,
      bool muted = false,
      int unavailableSeconds = 0,
      ScoreScale scale = scale,
    }) => targetGain(
      kind: SessionKind.meditation,
      scale: scale,
      mode: mode,
      dropActive: drop,
      score: score,
      threshold: 40,
      volume: volume,
      muted: muted,
      unavailableFor: Duration(seconds: unavailableSeconds),
    );

    test('silent during a restless episode or without a score', () {
      expect(med(drop: true, score: 5), 0);
      expect(med(score: null), 0);
    });

    test('floor at the boundary, full volume in Deep relaxation', () {
      expect(med(score: 50), closeTo(0.4, 1e-9));
      expect(med(score: 70), closeTo(0.4, 1e-9)); // restless, no episode yet
      expect(med(score: scale.zoneBoundaries.first), closeTo(1, 1e-9));
      expect(med(score: 2), 1);
      expect(med(score: 20), greaterThan(med(score: 40)));
    });

    test('ignores the feedback mode', () {
      for (final mode in FeedbackMode.values) {
        expect(med(mode: mode, score: 20), med(score: 20));
        expect(med(mode: mode, drop: true), 0);
      }
    });

    test('follows the baseline', () {
      const low = ScoreScale(baseline: 30);
      expect(med(scale: low, score: 30), closeTo(0.4, 1e-9));
      expect(med(scale: low, score: 40), closeTo(0.4, 1e-9));
      expect(
        med(scale: low, score: low.zoneBoundaries.first),
        closeTo(1, 1e-9),
      );
    });

    test('mute, volume and signal loss apply', () {
      expect(med(score: 2, volume: 0.5), 0.5);
      expect(med(score: 2, muted: true), 0);
      expect(med(score: 2, unavailableSeconds: 11), 0);
      expect(med(score: 2, unavailableSeconds: 5), 1);
    });
  });
}
