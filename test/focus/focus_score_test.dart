import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_score.dart';

void main() {
  group("zones", zoneTests);
  const scale = ScoreScale();

  test('the calibration level scores the baseline', () {
    expect(scale.toScore(0), 50);
    expect(const ScoreScale(baseline: 65).toScore(0), 65);
  });

  test('more focus than at calibration scores higher, less scores lower', () {
    expect(scale.toScore(20), greaterThan(50));
    expect(scale.toScore(-20), lessThan(50));
    expect(scale.toScore(40), greaterThan(scale.toScore(20)));
    expect(scale.toScore(-40), lessThan(scale.toScore(-20)));
  });

  test('huge relative changes saturate within 0–100', () {
    expect(scale.toScore(1e6), inInclusiveRange(99, 100));
    expect(scale.toScore(-1e6), inInclusiveRange(0, 1));
  });

  test('one span covers about three quarters of the way', () {
    expect(scale.toScore(50), closeTo(50 + 50 * 0.7616, 0.01));
    expect(scale.toScore(-50), closeTo(50 - 50 * 0.7616, 0.01));
  });

  test('toIndex inverts toScore', () {
    for (final b in [20.0, 50.0, 80.0]) {
      final s = ScoreScale(baseline: b);
      for (final score in [5.0, 30.0, 50.0, 72.0, 95.0]) {
        expect(s.toScore(s.toIndex(score)), closeTo(score, 1e-6));
      }
    }
  });
}

void zoneTests() {
  test('zone boundaries are 12/50/88 at baseline 50', () {
    final b = const ScoreScale().zoneBoundaries;
    expect(b[0], closeTo(11.92, 0.01));
    expect(b[1], 50);
    expect(b[2], closeTo(88.08, 0.01));
  });

  test('boundaries move with the baseline', () {
    for (final baseline in [30.0, 70.0]) {
      final s = ScoreScale(baseline: baseline);
      final b = s.zoneBoundaries;
      expect(b[1], baseline);
      expect(b[0], closeTo(baseline * (1 - 0.7616), 0.01));
      expect(b[2], closeTo(baseline + (100 - baseline) * 0.7616, 0.01));
    }
  });

  test('the calibration level sits on the Relaxation/Concentration edge', () {
    for (final baseline in [30.0, 50.0, 70.0]) {
      final s = ScoreScale(baseline: baseline);
      expect(s.zoneOf(s.toScore(0)), FocusZone.concentration);
      expect(s.zoneOf(s.toScore(-0.01)), FocusZone.relaxation);
    }
  });

  test('much more or less focus reaches the deep zones', () {
    const s = ScoreScale();
    expect(s.zoneOf(s.toScore(80)), FocusZone.deepConcentration);
    expect(s.zoneOf(s.toScore(-80)), FocusZone.deepRelaxation);
  });

  test('zones never decrease as the score rises', () {
    for (final baseline in [20.0, 50.0, 80.0]) {
      final s = ScoreScale(baseline: baseline);
      var last = FocusZone.deepRelaxation;
      for (var score = 0.0; score <= 100; score += 0.5) {
        final z = s.zoneOf(score);
        expect(z.index, greaterThanOrEqualTo(last.index));
        last = z;
      }
    }
  });
}
