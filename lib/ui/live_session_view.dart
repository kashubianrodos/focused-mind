import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../feedback/feedback_settings.dart';
import '../focus/focus_state.dart';
import '../sessions/session_controller.dart';
import 'contact_view.dart';
import 'focus_chart.dart';
import 'focus_scale_gauge.dart';
import 'format.dart';
import 'rhythm_charts.dart';

Color focusStateColor(FocusState s, ColorScheme scheme) => switch (s) {
  FocusState.focused => Colors.green.shade600,
  FocusState.neutral => scheme.primary,
  FocusState.distracted => Colors.orange.shade700,
  FocusState.unavailable => scheme.outline,
};

/// The running session: score, state, rhythm pie, focus and rhythm graphs,
/// time, signal and feedback in a scrollable body, with the focus scale
/// gauge pinned at the bottom (design D3). [header] scrolls with the body.
class LiveSessionView extends ConsumerWidget {
  const LiveSessionView({super.key, this.header, this.padding});

  final Widget? header;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final session = services.session;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: Listenable.merge([
        session.live,
        session.phase,
        session.rawRecordingError,
        services.settings,
        services.feedback.gain,
      ]),
      builder: (context, _) {
        final live = session.live.value;
        final settings = services.settings.value;
        final paused = session.phase.value == SessionPhase.paused;
        final reading = live?.reading;
        final state = live?.state ?? FocusState.unavailable;
        final muted = services.feedback.muted;
        final playing = services.feedback.gain.value > 0;

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?header,
            if (paused)
              MaterialBanner(
                content: const Text(
                  'Headband disconnected — session paused while reconnecting.',
                ),
                leading: const Icon(Icons.bluetooth_searching),
                actions: [const SizedBox.shrink()],
              ),
            // Wraps the pie under the score on a phone.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 16,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      reading?.score?.round().toString() ?? '–',
                      key: const ValueKey('live-score'),
                      style: text.displayLarge?.copyWith(
                        color: focusStateColor(state, scheme),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.label,
                              key: const ValueKey('live-state'),
                              style: text.titleLarge,
                            ),
                            Text(
                              live?.remaining == null
                                  ? 'Elapsed ${formatDuration(live?.elapsed ?? Duration.zero)}'
                                  : 'Elapsed ${formatDuration(live!.elapsed)} · '
                                        '${formatDuration(live.remaining!)} left',
                              key: const ValueKey('live-time'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                RhythmPie(
                  key: const ValueKey('live-rhythm-pie'),
                  shares: reading?.rhythms,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: FocusChart(
                points: live?.points ?? const [],
                marks: live?.marks ?? const [],
                threshold: settings.threshold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Brain rhythms', style: text.titleSmall),
            const SizedBox(height: 4),
            SizedBox(
              height: 120,
              child: RhythmStackedChart(
                key: const ValueKey('live-rhythm-chart'),
                points: live?.points ?? const [],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SideQualityView(left: reading?.left, right: reading?.right),
                if (session.rawRecordingError.value case final error?)
                  Chip(
                    key: const ValueKey('raw-recording-error'),
                    avatar: const Icon(Icons.warning_amber, size: 18),
                    label: Text(error),
                  ),
                Chip(
                  key: const ValueKey('feedback-indicator'),
                  avatar: Icon(
                    muted
                        ? Icons.volume_off
                        : (playing ? Icons.volume_up : Icons.volume_mute),
                    size: 18,
                  ),
                  label: Text(
                    '${settings.mode.label} · ${settings.soundscape.label} · '
                    '${muted ? 'muted' : (playing ? 'playing' : 'quiet')}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('mute'),
                  onPressed: muted ? null : session.mute,
                  icon: const Icon(Icons.volume_off),
                  label: const Text('Mute for this session'),
                ),
                FilledButton.icon(
                  key: const ValueKey('end-session'),
                  onPressed: session.end,
                  icon: const Icon(Icons.stop),
                  label: const Text('End session'),
                ),
              ],
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('live-scroll'),
                padding: padding,
                child: body,
              ),
            ),
            Material(
              elevation: 3,
              child: FocusScaleGauge(
                score: reading?.score,
                scale: settings.scoreScale,
              ),
            ),
          ],
        );
      },
    );
  }
}
