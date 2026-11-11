import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../feedback/feedback_settings.dart';
import '../focus/focus_score.dart';
import 'wellness_notice.dart';

/// Feedback mode, soundscape, volume, threshold, baseline and trigger delay
/// (focus-audio-feedback spec: "Feedback settings").
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final controller = services.settings;
    final text = Theme.of(context).textTheme;

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, s, _) {
        void update(FeedbackSettings next) => controller.update(next);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Feedback', style: text.headlineSmall),
            const SizedBox(height: 16),
            Text('Mode', style: text.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<FeedbackMode>(
              key: const ValueKey('mode'),
              segments: [
                for (final m in FeedbackMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {s.mode},
              onSelectionChanged: (v) => update(s.copyWith(mode: v.first)),
            ),
            const SizedBox(height: 6),
            Text(s.mode.description, key: const ValueKey('mode-description')),
            const SizedBox(height: 24),
            Text('Soundscape', style: text.titleMedium),
            RadioGroup<Soundscape>(
              groupValue: s.soundscape,
              onChanged: (v) => update(s.copyWith(soundscape: v)),
              child: Column(
                children: [
                  for (final sound in Soundscape.values)
                    RadioListTile<Soundscape>(
                      key: ValueKey('sound-${sound.name}'),
                      value: sound,
                      title: Text(sound.label),
                      secondary: IconButton(
                        key: ValueKey('preview-${sound.name}'),
                        tooltip: 'Preview',
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () =>
                            services.audio.preview(sound, s.volume),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SliderRow(
              label: 'Volume',
              value: s.volume * 100,
              min: 0,
              max: 100,
              divisions: 20,
              display: '${(s.volume * 100).round()}%',
              onChanged: (v) => update(s.copyWith(volume: v / 100)),
            ),
            _SliderRow(
              label: 'Focus threshold',
              help: 'Below this score you count as distracted.',
              value: s.threshold,
              min: 0,
              max: 100,
              divisions: 100,
              display: s.threshold.round().toString(),
              onChanged: (v) => update(s.copyWith(threshold: v)),
            ),
            _SliderRow(
              label: 'Baseline',
              help:
                  'The score your calibrated resting level gets. Raise it if '
                  'feedback marks you as distracted too often; lower it for '
                  'stricter feedback.',
              value: s.baseline,
              min: ScoreScale.minBaseline,
              max: ScoreScale.maxBaseline,
              divisions: (ScoreScale.maxBaseline - ScoreScale.minBaseline)
                  .round(),
              display: s.baseline.round().toString(),
              onChanged: (v) => update(s.copyWith(baseline: v)),
            ),
            _SliderRow(
              label: 'Trigger delay',
              help: 'How long focus must stay low before it counts as a drop.',
              value: s.triggerDelay.inSeconds.toDouble(),
              min: FeedbackSettings.minTriggerDelay.inSeconds.toDouble(),
              max: FeedbackSettings.maxTriggerDelay.inSeconds.toDouble(),
              divisions:
                  FeedbackSettings.maxTriggerDelay.inSeconds -
                  FeedbackSettings.minTriggerDelay.inSeconds,
              display: '${s.triggerDelay.inSeconds} s',
              onChanged: (v) => update(
                s.copyWith(triggerDelay: Duration(seconds: v.round())),
              ),
            ),
            const SizedBox(height: 32),
            Text('Data', style: text.headlineSmall),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: services.recordRaw,
              builder: (context, on, _) => SwitchListTile(
                key: const ValueKey('record-raw'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Record raw signal'),
                subtitle: const Text(
                  'Stores the full EEG of each session (about 20 MB per '
                  'hour) so it can be exported from History. Takes effect '
                  'from the next session.',
                ),
                value: on,
                onChanged: services.recordRaw.update,
              ),
            ),
            const SizedBox(height: 32),
            Text('About', style: text.headlineSmall),
            const SizedBox(height: 8),
            const Text(wellnessNoticeText),
            const SizedBox(height: 8),
            const Text(
              'Your sessions and settings are stored only on this Mac and are '
              'never sent anywhere.',
            ),
          ],
        );
      },
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
    this.help,
  });

  final String label;
  final String? help;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(display, key: ValueKey('value-$label')),
            ],
          ),
          if (help != null) Text(help!),
          Slider(
            key: ValueKey('slider-$label'),
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
