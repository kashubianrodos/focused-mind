import 'package:flutter/material.dart';

import '../focus/focus_score.dart';
import 'palette.dart';

/// Horizontal position (0–1) of focus score [value] on the gauge; mirrored
/// gauges run from Deep concentration on the left to Deep relaxation on the
/// right (meditation-sessions spec, design D4).
double gaugeFraction(double value, {bool mirrored = false}) {
  final f = value.clamp(0, 100) / 100;
  return mirrored ? 1 - f : f;
}

/// The four-zone relaxation–concentration scale as a horizontal gauge
/// (focus-scale spec, design D1/D3). The needle is the focus score; with no
/// score the gauge shows that the reading is unavailable. [mirrored]
/// reverses the zone order for meditation sessions, keeping zones, colours
/// and the semantics value unchanged.
class FocusScaleGauge extends StatelessWidget {
  const FocusScaleGauge({
    super.key,
    required this.score,
    required this.scale,
    this.mirrored = false,
  });

  final double? score;
  final ScoreScale scale;
  final bool mirrored;

  Widget _paint(BuildContext context, double? needle) => CustomPaint(
    size: Size.infinite,
    painter: _GaugePainter(
      boundaries: scale.zoneBoundaries,
      needle: needle,
      needleColor: Theme.of(context).colorScheme.onSurface,
      mirrored: mirrored,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = score;
    final zone = s == null ? null : scale.zoneOf(s);
    return Semantics(
      key: const ValueKey('scale-gauge'),
      label: 'Focus scale',
      value: s == null ? 'unavailable' : '${s.round()} ${zone!.label}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              zone?.label ?? 'Signal unavailable',
              key: const ValueKey('scale-zone'),
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: zone == null ? Theme.of(context).disabledColor : null,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: s == null
                  ? _paint(context, null)
                  : TweenAnimationBuilder<double>(
                      tween: Tween(end: s),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, value, _) => _paint(context, value),
                    ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final z
                    in mirrored ? FocusZone.values.reversed : FocusZone.values)
                  Expanded(
                    key: ValueKey('zone-label-${z.name}'),
                    // One word per line, shrunk rather than split when a
                    // word is wider than its quarter (phones, large text).
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        z.label.replaceAll(' ', '\n'),
                        textAlign: TextAlign.center,
                        style: text.labelSmall?.copyWith(
                          color: z == zone ? zoneColor(z) : null,
                          fontWeight: z == zone ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.boundaries,
    required this.needle,
    required this.needleColor,
    required this.mirrored,
  });

  final List<double> boundaries;
  final double? needle;
  final Color needleColor;
  final bool mirrored;

  double _x(Size size, double value) =>
      size.width * gaugeFraction(value, mirrored: mirrored);

  @override
  void paint(Canvas canvas, Size size) {
    final barTop = size.height * 0.25;
    final barHeight = size.height * 0.5;
    final edges = [0.0, ...boundaries, 100.0];
    for (var i = 0; i < FocusZone.values.length; i++) {
      final a = _x(size, edges[i]);
      final b = _x(size, edges[i + 1]);
      final rect = Rect.fromLTRB(
        a < b ? a : b,
        barTop,
        a < b ? b : a,
        barTop + barHeight,
      );
      canvas.drawRect(rect, Paint()..color = zoneColor(FocusZone.values[i]));
    }
    final n = needle;
    if (n == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, barTop, size.width, barHeight),
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
      return;
    }
    final x = _x(size, n);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = needleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.needle != needle ||
      old.needleColor != needleColor ||
      old.mirrored != mirrored ||
      old.boundaries.join() != boundaries.join();
}
