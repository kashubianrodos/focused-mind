import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../focus/session_kind.dart';
import '../headband/headband_source.dart';
import '../sessions/session_controller.dart';
import 'connect_panel.dart';
import 'contact_view.dart';
import 'live_session_view.dart';
import 'session_kind_chip.dart';
import 'summary_view.dart';

/// Planned session lengths offered at start; null is open-ended.
const plannedDurations = <Duration?>[
  Duration(minutes: 25),
  Duration(minutes: 50),
  Duration(minutes: 90),
  null,
];

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  Duration? _planned = const Duration(minutes: 25);
  late SessionKind _kind;
  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    _services = ref.read(servicesProvider);
    _kind = _services.settingsRepository.lastSessionKind;
    _services.connection.state.addListener(_showContactWhenIdle);
    _services.session.phase.addListener(_showContactWhenIdle);
  }

  @override
  void dispose() {
    _services.connection.state.removeListener(_showContactWhenIdle);
    _services.session.phase.removeListener(_showContactWhenIdle);
    super.dispose();
  }

  /// Outside a session, contact quality is shown, so the band streams
  /// resistance (headband-connection spec, design D4).
  void _showContactWhenIdle() {
    final services = _services;
    if (services.connection.isConnected &&
        !services.session.isActive &&
        services.connection.mode == StreamMode.idle) {
      services.connection.setMode(StreamMode.resistance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final session = services.session;
    return ListenableBuilder(
      listenable: Listenable.merge([session.phase, services.connection.state]),
      builder: (context, _) {
        final phase = session.phase.value;
        if (phase == SessionPhase.running || phase == SessionPhase.paused) {
          // The live view scrolls its own body and pins the scale gauge.
          return const LiveSessionView(
            padding: EdgeInsets.all(24),
            header: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: ConnectPanel(),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ConnectPanel(),
              const SizedBox(height: 24),
              switch (phase) {
                SessionPhase.idle => _StartView(
                  planned: _planned,
                  onPlanned: (d) => setState(() => _planned = d),
                  kind: _kind,
                  onKind: (k) => setState(() => _kind = k),
                ),
                SessionPhase.signalCheck => const _SignalCheckView(),
                SessionPhase.calibrating => const _CalibratingView(),
                SessionPhase.calibrationFailed =>
                  const _CalibrationFailedView(),
                SessionPhase.running ||
                SessionPhase.paused => const SizedBox.shrink(),
                SessionPhase.ended => _EndedView(
                  planned: _planned,
                  onPlanned: (d) => setState(() => _planned = d),
                  kind: _kind,
                  onKind: (k) => setState(() => _kind = k),
                ),
              },
            ],
          ),
        );
      },
    );
  }
}

class _StartView extends ConsumerWidget {
  const _StartView({
    required this.planned,
    required this.onPlanned,
    required this.kind,
    required this.onKind,
  });

  final Duration? planned;
  final ValueChanged<Duration?> onPlanned;
  final SessionKind kind;
  final ValueChanged<SessionKind> onKind;

  Future<void> _start(AppServices services) async {
    await services.settingsRepository.saveLastSessionKind(kind);
    await services.session.start(planned: planned, kind: kind);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final connected = services.connection.isConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (kind) {
            SessionKind.focus => 'Start a focus session',
            SessionKind.meditation => 'Start a meditation session',
          },
          key: const ValueKey('start-heading'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        SegmentedButton<SessionKind>(
          segments: const [
            ButtonSegment(
              value: SessionKind.focus,
              icon: Icon(Icons.center_focus_strong),
              label: Text('Focus', key: ValueKey('kind-focus')),
            ),
            ButtonSegment(
              value: SessionKind.meditation,
              icon: Icon(Icons.self_improvement),
              label: Text('Meditation', key: ValueKey('kind-meditation')),
            ),
          ],
          selected: {kind},
          onSelectionChanged: (s) => onKind(s.first),
        ),
        const SizedBox(height: 12),
        SegmentedButton<Duration?>(
          segments: [
            for (final d in plannedDurations)
              ButtonSegment(
                value: d,
                label: Text(d == null ? 'Open-ended' : '${d.inMinutes} min'),
              ),
          ],
          selected: {planned},
          onSelectionChanged: (s) => onPlanned(s.first),
        ),
        const SizedBox(height: 16),
        if (connected)
          ValueListenableBuilder(
            valueListenable: services.connection.contact,
            builder: (context, report, _) => ContactView(report: report),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('start-session'),
          onPressed: connected ? () => _start(services) : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start session'),
        ),
        if (!connected)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Connect a headband to start a session.'),
          ),
      ],
    );
  }
}

class _SignalCheckView extends ConsumerWidget {
  const _SignalCheckView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionKindChip(services.session.kind),
        const SizedBox(height: 8),
        Text(
          'Checking the signal',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Calibration starts as soon as every electrode has good or fair '
          'contact.',
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder(
          valueListenable: services.connection.contact,
          builder: (context, report, _) => ContactView(report: report),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: services.session.end,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _CalibratingView extends ConsumerWidget {
  const _CalibratingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(servicesProvider).session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionKindChip(session.kind),
        const SizedBox(height: 8),
        Text('Calibrating', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Sit still with your eyes open and relax for a moment.'),
        const SizedBox(height: 16),
        ValueListenableBuilder(
          valueListenable: session.calibrationPercent,
          builder: (context, percent, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: percent / 100),
              const SizedBox(height: 4),
              Text('$percent%', key: const ValueKey('calibration-percent')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: session.end, child: const Text('Cancel')),
      ],
    );
  }
}

class _CalibrationFailedView extends ConsumerWidget {
  const _CalibrationFailedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(servicesProvider).session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionKindChip(session.kind),
        const SizedBox(height: 8),
        Text(
          'Calibration failed',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(session.calibrationError ?? ''),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            FilledButton(
              onPressed: session.retryCalibration,
              child: const Text('Try again'),
            ),
            TextButton(onPressed: session.end, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}

class _EndedView extends ConsumerWidget {
  const _EndedView({
    required this.planned,
    required this.onPlanned,
    required this.kind,
    required this.onKind,
  });

  final Duration? planned;
  final ValueChanged<Duration?> onPlanned;
  final SessionKind kind;
  final ValueChanged<SessionKind> onKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final record = services.session.lastRecord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (record != null) ...[
          SessionKindChip(record.summary.kind),
          const SizedBox(height: 8),
        ],
        Text(
          'Session summary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (record != null)
          SummaryView(
            record: record,
            threshold: services.settings.value.threshold,
            baseline: services.settings.value.baseline,
          ),
        const SizedBox(height: 24),
        _StartView(
          planned: planned,
          onPlanned: onPlanned,
          kind: kind,
          onKind: onKind,
        ),
      ],
    );
  }
}
