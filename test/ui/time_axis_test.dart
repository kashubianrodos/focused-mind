import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/ui/focus_chart.dart';

void main() {
  test('short sessions keep minute labels', () {
    expect(timeAxisInterval(8 * 60, 800), 60);
  });

  test('long sessions on a narrow chart thin out the labels', () {
    for (final (hours, width) in [
      (1, 360.0),
      (3, 360.0),
      (3, 1200.0),
      (8, 360.0),
    ]) {
      final seconds = hours * 3600.0;
      final step = timeAxisInterval(seconds, width);
      final labels = seconds / step;
      expect(
        labels,
        lessThanOrEqualTo((width - 40) / 56),
        reason: '${hours}h @ $width',
      );
    }
    // Wider chart, same session: denser (smaller) step.
    expect(
      timeAxisInterval(3 * 3600, 1200),
      lessThan(timeAxisInterval(3 * 3600, 360)),
    );
  });

  test('labels switch to hours past 60 minutes', () {
    expect(timeAxisLabel(45 * 60), '45m');
    expect(timeAxisLabel(60 * 60), '1h');
    expect(timeAxisLabel(90 * 60), '1h30m');
  });
}
