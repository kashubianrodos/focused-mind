import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/feedback/gain_policy.dart';

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
}
