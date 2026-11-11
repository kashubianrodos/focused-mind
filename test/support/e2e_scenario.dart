import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/app/services.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/headband/simulated_headband_source.dart';
import 'package:focused_mind/sessions/session_controller.dart';
import 'package:focused_mind/sessions/session_csv.dart';
import 'package:focused_mind/sessions/session_models.dart';

import 'fake_audio_output.dart';

/// Advances time; the host test passes fakeAsync's elapse, the integration
/// test pumps the real app.
typedef Advance = Future<void> Function(Duration);

/// One full simulated session with the real EmotionalMath estimator:
/// connect, calibrate, a forced focus drop and a recovery, end, history.
/// Also checks the recorded scale zones and rhythm shares, and that the
/// session's CSV export has one row per second.
///
/// The simulator calibrates at a middle focus level, which the score scale
/// places at the baseline (50); the default threshold (40) and baseline are
/// used throughout (design D5).
Future<SessionRecord> runSimulatedSession({
  required AppServices services,
  required FakeAudioOutput audio,
  required FeedbackMode mode,
  required Advance advance,
}) async {
  final sim = services.simulator!;
  await services.settings.update(
    services.settings.value.copyWith(mode: mode, volume: 1),
  );

  sim.focus = 0.5;
  final connecting = services.connection.connect(
    SimulatedHeadbandSource.device,
  );
  await advance(const Duration(seconds: 1));
  await connecting;
  expect(services.connection.isConnected, isTrue);

  final started = services.session.start();
  await advance(const Duration(seconds: 2));
  expect(await started, isTrue);
  await advance(const Duration(seconds: 14)); // 4 s skipped + 6 s calibration
  expect(services.session.phase.value, SessionPhase.running);

  sim.focus = 0.95;
  await advance(const Duration(seconds: 25));
  final focusedPoint = services.session.live.value!.points.last;
  expect(
    focusedPoint.zone!.index,
    greaterThanOrEqualTo(FocusZone.concentration.index),
    reason: 'high focus reads as concentration',
  );
  final focusedRhythms = focusedPoint.rhythms!;
  if (mode == FeedbackMode.alert) {
    expect(audio.volume, 0, reason: 'alert mode is quiet while focused');
  } else {
    expect(
      audio.volume,
      greaterThan(0),
      reason: 'continuous plays while focused',
    );
  }

  sim.focus = 0.05;
  await advance(const Duration(seconds: 25));
  final lowPoint = services.session.live.value!.points.last;
  expect(
    lowPoint.zone!.index,
    lessThanOrEqualTo(FocusZone.relaxation.index),
    reason: 'low focus reads as relaxation or below',
  );
  expect(
    lowPoint.rhythms!.beta,
    lessThan(focusedRhythms.beta),
    reason: 'less beta when focus is low',
  );
  if (mode == FeedbackMode.alert) {
    expect(audio.volume, greaterThan(0), reason: 'alert plays on a drop');
  } else {
    expect(audio.volume, 0, reason: 'continuous goes quiet on a drop');
  }

  sim.focus = 0.95;
  await advance(const Duration(seconds: 25));
  if (mode == FeedbackMode.alert) {
    expect(audio.volume, 0, reason: 'alert fades out on recovery');
  } else {
    expect(audio.volume, greaterThan(0), reason: 'continuous returns');
  }

  final ending = services.session.end();
  await advance(const Duration(seconds: 3));
  final record = (await ending)!;
  expect(record.summary.drops, greaterThanOrEqualTo(1));
  expect(record.summary.recoveries, greaterThanOrEqualTo(1));
  expect(record.summary.mode, mode);
  final history = await services.sessions.list();
  expect(history.map((s) => s.id), contains(record.summary.id));

  expect(record.summary.hasRhythms, isTrue);
  expect(
    record.summary.timeInZoneOf(FocusZone.concentration) +
        record.summary.timeInZoneOf(FocusZone.deepConcentration),
    greaterThan(Duration.zero),
  );
  final csvRows = SessionCsv.timeline(record)
      .split('\r\n')
      .where((l) => l.isNotEmpty);
  expect(csvRows.length, record.timeline.length + 1);
  return record;
}
