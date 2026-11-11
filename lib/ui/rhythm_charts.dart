import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../focus/rhythms.dart';
import '../sessions/session_models.dart';
import 'palette.dart';

/// Current theta/alpha/beta shares as a donut with a legend (brain-rhythms
/// spec); shows that the reading is unavailable instead of stale segments.
class RhythmPie extends StatelessWidget {
  const RhythmPie({super.key, required this.shares, this.size = 120});

  final RhythmShares? shares;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = shares;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: s == null
              ? Center(
                  child: Text(
                    'Rhythms\nunavailable',
                    key: const ValueKey('rhythms-unavailable'),
                    textAlign: TextAlign.center,
                    style: text.labelSmall,
                  ),
                )
              : PieChart(
                  duration: Duration.zero,
                  PieChartData(
                    centerSpaceRadius: size * 0.22,
                    sectionsSpace: 1,
                    startDegreeOffset: -90,
                    sections: [
                      for (final r in Rhythm.values)
                        PieChartSectionData(
                          value: s[r],
                          color: rhythmColor(r),
                          radius: size * 0.26,
                          title: s[r] >= 8 ? '${s[r].round()}%' : '',
                          titleStyle: text.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in Rhythm.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: rhythmColor(r)),
                    const SizedBox(width: 6),
                    Text(
                      '${r.label} ${s == null ? '–' : '${s[r].round()}%'}',
                      key: ValueKey('rhythm-${r.name}'),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Theta/alpha/beta shares over a session as stacked layers (brain-rhythms
/// spec). fl_chart has no stacked area, so three cumulative lines are drawn
/// (θ, θ+α, 100) and filled below and between them (design D3). Gaps and
/// unavailable seconds break all three together.
class RhythmStackedChart extends StatelessWidget {
  const RhythmStackedChart({super.key, required this.points});

  final List<TimelinePoint> points;

  @override
  Widget build(BuildContext context) {
    List<FlSpot> layer(double Function(RhythmShares) top) => [
      for (final p in points)
        p.rhythms == null
            ? FlSpot.nullSpot
            : FlSpot(p.second.toDouble(), top(p.rhythms!)),
    ];
    final maxX = points.isEmpty ? 60.0 : points.last.second.toDouble();
    LineChartBarData bar(List<FlSpot> spots, {Color? fillBelow}) =>
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 0,
          color: Colors.transparent,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: fillBelow != null, color: fillBelow),
        );
    final bars = [
      bar(layer((s) => s.theta), fillBelow: rhythmColor(Rhythm.theta)),
      bar(layer((s) => s.theta + s.alpha)),
      bar(layer((_) => 100)),
    ];
    return LineChart(
      duration: Duration.zero,
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: maxX < 60 ? 60 : maxX,
        clipData: const FlClipData.all(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: bars,
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: 0,
            toIndex: 1,
            color: rhythmColor(Rhythm.alpha),
          ),
          BetweenBarsData(
            fromIndex: 1,
            toIndex: 2,
            color: rhythmColor(Rhythm.beta),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 50,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: maxX / 60 <= 10 ? 60 : (maxX / 60 <= 30 ? 300 : 600),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  '${value ~/ 60}m',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
