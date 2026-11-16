import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../sessions/session_models.dart';

/// Focus score over a session; gaps and unavailable seconds break the line,
/// disconnection gaps are shaded and the threshold is drawn as a line.
///
/// With [invert] (meditation sessions, design D3) it plots the calm score,
/// 100 − focus score; [threshold] is then on the calm scale too.
class FocusChart extends StatelessWidget {
  const FocusChart({
    super.key,
    required this.points,
    required this.marks,
    required this.threshold,
    this.invert = false,
  });

  final List<TimelinePoint> points;
  final List<SessionMark> marks;
  final double threshold;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = [
      for (final p in points)
        p.score == null
            ? FlSpot.nullSpot
            : FlSpot(p.second.toDouble(), invert ? 100 - p.score! : p.score!),
    ];
    final maxX = points.isEmpty ? 60.0 : points.last.second.toDouble();
    final gaps = <VerticalRangeAnnotation>[];
    int? gapStart;
    for (final m in marks) {
      if (m.kind == MarkKind.gapStart) gapStart = m.second;
      if (m.kind == MarkKind.gapEnd && gapStart != null) {
        gaps.add(_gap(gapStart, m.second, scheme));
        gapStart = null;
      }
    }
    if (gapStart != null) gaps.add(_gap(gapStart, maxX.toInt() + 1, scheme));

    return LayoutBuilder(
      builder: (context, box) => LineChart(
        duration: Duration.zero,
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: maxX < 60 ? 60 : maxX,
          clipData: const FlClipData.all(),
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: gaps),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: threshold,
                color: scheme.tertiary,
                strokeWidth: 1,
                dashArray: const [6, 4],
              ),
            ],
            verticalLines: [
              for (final m in marks)
                if (m.kind == MarkKind.drop || m.kind == MarkKind.recovery)
                  VerticalLine(
                    x: m.second.toDouble(),
                    color: m.kind == MarkKind.drop
                        ? scheme.error.withValues(alpha: 0.5)
                        : Colors.green.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 25,
                getTitlesWidget: valueAxisLabel,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: timeAxisInterval(maxX, box.maxWidth),
                // fl_chart always labels the last point too; skip it unless
                // it lands on the interval, or it overprints its neighbour.
                getTitlesWidget: (value, meta) =>
                    value % meta.appliedInterval != 0
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(
                          timeAxisLabel(value),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: scheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VerticalRangeAnnotation _gap(int from, int to, ColorScheme scheme) =>
      VerticalRangeAnnotation(
        x1: from.toDouble(),
        x2: to.toDouble(),
        color: scheme.outline.withValues(alpha: 0.15),
      );
}

/// Seconds between time-axis labels: the smallest round step that keeps
/// labels at least [minLabelGap] px apart over [seconds] of session drawn
/// [width] px wide (minus the 40 px left axis).
double timeAxisInterval(
  double seconds,
  double width, {
  double minLabelGap = 56,
}) {
  const stepsMinutes = [1, 2, 5, 10, 15, 20, 30, 60, 120, 180, 240, 360];
  // ponytail: unbounded width (never seen in practice) falls back to 800 px.
  final w = width.isFinite ? width : 800;
  final maxLabels = ((w - 40) / minLabelGap).floor().clamp(2, 1000);
  for (final m in stepsMinutes) {
    if (seconds / (m * 60) <= maxLabels) return m * 60.0;
  }
  return stepsMinutes.last * 60.0;
}

/// "45m", "1h", "1h30m".
String timeAxisLabel(double seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final m = minutes % 60;
  return '${minutes ~/ 60}h${m == 0 ? '' : '${m}m'}';
}

/// A value-axis label that never wraps: "100" with a large system text size
/// (common on phones) would otherwise break into "10" / "0" in the reserved
/// width. It shrinks to fit instead.
Widget valueAxisLabel(double value, TitleMeta meta) => SideTitleWidget(
  meta: meta,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      meta.formattedValue,
      key: ValueKey('axis-${meta.formattedValue}'),
      maxLines: 1,
      softWrap: false,
      style: const TextStyle(fontSize: 12),
    ),
  ),
);
