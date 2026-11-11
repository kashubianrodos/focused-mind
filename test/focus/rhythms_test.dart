import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/rhythms.dart';

void main() {
  test('normalizes to 100 percent', () {
    final r = RhythmShares.normalized(1, 2, 1)!;
    expect(r.theta, 25);
    expect(r.alpha, 50);
    expect(r.beta, 25);
    expect(r[Rhythm.alpha], 50);
  });

  test('no power or invalid values give null', () {
    expect(RhythmShares.normalized(0, 0, 0), isNull);
    expect(RhythmShares.normalized(double.nan, 1, 1), isNull);
    expect(RhythmShares.normalized(-1, 1, 1), isNull);
  });

  test('JSON round trip rounds to 0.1', () {
    final r = RhythmShares.normalized(1, 1, 1)!;
    expect(r.toJson(), [33.3, 33.3, 33.3]);
    final back = RhythmShares.fromJson(r.toJson())!;
    expect(back.theta, closeTo(33.33, 0.01));
    expect(RhythmShares.fromJson(null), isNull);
    expect(RhythmShares.fromJson([1, 2]), isNull);
  });
}
