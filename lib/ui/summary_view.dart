import 'package:flutter/material.dart';

import '../feedback/feedback_settings.dart';
import '../focus/focus_score.dart';
import '../focus/focus_state.dart';
import '../focus/session_kind.dart';
import '../sessions/session_models.dart';
import 'focus_chart.dart';
import 'format.dart';
import 'palette.dart';
import 'rhythm_charts.dart';

/// End-of-session summary (focus-sessions spec), also used for history.
///
/// Meditation sessions (meditation-sessions spec, design D6) show the calm
/// score and calm wording; the stat card keys stay the focus ones.
class SummaryView extends StatelessWidget {
  const SummaryView({
    super.key,
    required this.record,
    required this.threshold,
    this.baseline = ScoreScale.defaultBaseline,
  });

  final SessionRecord record;

  /// Focus threshold, drawn on focus-session charts.
  final double threshold;

  /// Baseline whose calm boundary (100 − baseline) meditation charts draw.
  final double baseline;

  @override
  Widget build(BuildContext context) {
    final s = record.summary;
    final text = Theme.of(context).textTheme;
    final meditation = s.kind == SessionKind.meditation;
    final avg = s.averageScore;
    // (key, label, value)
    final stats = <(String, String, String)>[
      ('Duration', 'Duration', formatMinutes(s.duration)),
      if (meditation)
        (
          'Average focus',
          'Average calm',
          avg == null ? '–' : (100 - avg).round().toString(),
        )
      else
        (
          'Average focus',
          'Average focus',
          avg == null ? '–' : avg.round().toString(),
        ),
      (
        'Focused',
        meditation ? 'Time calm' : 'Focused',
        formatMinutes(s.timeIn(FocusState.focused)),
      ),
      if (!meditation)
        ('Neutral', 'Neutral', formatMinutes(s.timeIn(FocusState.neutral))),
      (
        'Distracted',
        meditation ? 'Restless' : 'Distracted',
        formatMinutes(s.timeIn(FocusState.distracted)),
      ),
      (
        'Signal unavailable',
        'Signal unavailable',
        formatMinutes(s.timeIn(FocusState.unavailable)),
      ),
      (
        'Focus drops',
        meditation ? 'Restless episodes' : 'Focus drops',
        '${s.drops}',
      ),
      (
        'Recoveries',
        meditation ? 'Calm again' : 'Recoveries',
        '${s.recoveries}',
      ),
      (
        'Longest focused stretch',
        meditation ? 'Longest calm stretch' : 'Longest focused stretch',
        formatMinutes(s.longestFocused),
      ),
      if (meditation)
        ('Feedback mode', 'Sound', 'Plays while calm')
      else
        ('Feedback mode', 'Feedback mode', s.mode.label),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (key, label, value) in stats)
              _StatCard(label: label, value: value, valueKey: 'stat-$key'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: FocusChart(
            points: record.timeline,
            marks: record.marks,
            invert: meditation,
            threshold: meditation ? 100 - baseline : threshold,
          ),
        ),
        // Sessions recorded before zones and rhythms existed omit these.
        if (s.hasRhythms) ...[
          const SizedBox(height: 24),
          Text('Focus scale', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final z in FocusZone.values)
                _StatCard(
                  label: z.label,
                  value: formatMinutes(s.timeInZoneOf(z)),
                  valueKey: 'stat-zone-${z.name}',
                  color: zoneColor(z),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Brain rhythms', style: text.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RhythmPie(
                key: const ValueKey('summary-rhythm-pie'),
                shares: s.averageRhythms,
                size: 100,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 120,
                  child: RhythmStackedChart(
                    key: const ValueKey('summary-rhythm-chart'),
                    points: record.timeline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueKey,
    this.color,
  });

  final String label;
  final String value;
  final String valueKey;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 170,
      child: Card(
        shape: color == null
            ? null
            : RoundedRectangleBorder(
                side: BorderSide(color: color!, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelMedium),
              const SizedBox(height: 4),
              Text(value, key: ValueKey(valueKey), style: text.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
