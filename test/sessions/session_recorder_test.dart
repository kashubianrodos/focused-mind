import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/drop_tracker.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/sessions/session_models.dart';
import 'package:focused_mind/sessions/session_recorder.dart';

void main() {
  SessionRecorder recorder() => SessionRecorder(
    id: 's1',
    startedAt: DateTime(2026, 11, 11, 9),
    plannedDuration: const Duration(minutes: 25),
  );

  /// Plays a scripted session through a real [DropTracker]:
  /// focused 10 s, distracted 8 s, focused 6 s, distracted 7 s, focused 5 s.
  SessionRecorder scriptedTwoDrops() {
    final r = recorder();
    final tracker = DropTracker();
    final script = [
      ...List.filled(10, (80.0, FocusState.focused)),
      ...List.filled(8, (20.0, FocusState.distracted)),
      ...List.filled(6, (75.0, FocusState.focused)),
      ...List.filled(7, (15.0, FocusState.distracted)),
      ...List.filled(5, (70.0, FocusState.focused)),
    ];
    for (var i = 0; i < script.length; i++) {
      final (score, state) = script[i];
      final event = tracker.update(state, Duration(seconds: i));
      r.record(score: score, state: state, event: event);
    }
    return r;
  }

  test('scripted session with 2 drops and 2 recoveries', () {
    final s = scriptedTwoDrops().finish().summary;
    expect(s.drops, 2);
    expect(s.recoveries, 2);
    expect(s.duration, const Duration(seconds: 36));
    expect(s.timeIn(FocusState.focused), const Duration(seconds: 21));
    expect(s.timeIn(FocusState.distracted), const Duration(seconds: 15));
    expect(s.longestFocused, const Duration(seconds: 10));
    final expectedAvg = (10 * 80 + 8 * 20 + 6 * 75 + 7 * 15 + 5 * 70) / 36;
    expect(s.averageScore, closeTo(expectedAvg, 1e-9));
  });

  test('marks record drops and recoveries at their seconds', () {
    final marks = scriptedTwoDrops().finish().marks;
    expect(marks.map((m) => (m.second, m.kind)), [
      (15, MarkKind.drop),
      (21, MarkKind.recovery),
      (29, MarkKind.drop),
      (34, MarkKind.recovery),
    ]);
  });

  test('gaps are marked on the timeline and excluded from statistics', () {
    final r = recorder();
    for (var i = 0; i < 5; i++) {
      r.record(score: 80, state: FocusState.focused);
    }
    for (var i = 0; i < 20; i++) {
      r.recordGap();
    }
    for (var i = 0; i < 5; i++) {
      r.record(score: 80, state: FocusState.focused);
    }
    final record = r.finish();
    expect(record.timeline, hasLength(30));
    expect(record.timeline.where((p) => p.gap), hasLength(20));
    expect(record.summary.duration, const Duration(seconds: 10));
    expect(record.summary.averageScore, 80);
    expect(record.summary.timeIn(FocusState.unavailable), Duration.zero);
    expect(record.marks.map((m) => (m.second, m.kind)), [
      (5, MarkKind.gapStart),
      (25, MarkKind.gapEnd),
    ]);
  });

  test('unavailable seconds count in time-per-state but not the average', () {
    final r = recorder()
      ..record(score: 60, state: FocusState.neutral)
      ..record(score: null, state: FocusState.unavailable)
      ..record(score: 40, state: FocusState.neutral);
    final s = r.finish().summary;
    expect(s.averageScore, 50);
    expect(s.timeIn(FocusState.unavailable), const Duration(seconds: 1));
  });

  test('a session with no scores has no average', () {
    final s = (recorder()..record(score: null, state: FocusState.unavailable))
        .finish()
        .summary;
    expect(s.averageScore, isNull);
  });

  test('zones and rhythm shares are recorded and summarised', () {
    final r = recorder();
    final relaxed = RhythmShares.normalized(40, 40, 20);
    final focused = RhythmShares.normalized(20, 30, 50);
    // At baseline 50: 30 is Relaxation, 70 is Concentration, 95 is Deep.
    for (var i = 0; i < 4; i++) {
      r.record(score: 30, state: FocusState.distracted, rhythms: relaxed);
    }
    r.recordGap();
    r.recordGap();
    for (var i = 0; i < 4; i++) {
      r.record(score: 70, state: FocusState.focused, rhythms: focused);
    }
    r.record(score: 95, state: FocusState.focused, rhythms: focused);
    r.record(score: null, state: FocusState.unavailable, rhythms: focused);

    final record = r.finish();
    expect(record.timeline[0].zone, FocusZone.relaxation);
    expect(record.timeline[4].zone, isNull, reason: 'gap');
    expect(record.timeline[6].zone, FocusZone.concentration);
    expect(record.timeline.last.zone, isNull, reason: 'unavailable');
    expect(record.timeline.last.rhythms, isNull);

    final s = record.summary;
    expect(s.timeInZoneOf(FocusZone.relaxation), const Duration(seconds: 4));
    expect(s.timeInZoneOf(FocusZone.concentration), const Duration(seconds: 4));
    expect(
      s.timeInZoneOf(FocusZone.deepConcentration),
      const Duration(seconds: 1),
    );
    expect(s.timeInZoneOf(FocusZone.deepRelaxation), Duration.zero);
    // 4 relaxed + 5 focused seconds: beta = (4·20 + 5·50) / 9.
    expect(s.averageRhythms!.beta, closeTo((4 * 20 + 5 * 50) / 9, 1e-9));
    expect(s.hasRawRecording, isFalse);
  });

  test('the zone uses the scale in force at each second', () {
    final r = recorder()
      ..record(score: 45, state: FocusState.neutral)
      ..record(
        score: 45,
        state: FocusState.neutral,
        scale: const ScoreScale(baseline: 40),
      );
    final t = r.finish().timeline;
    expect(t[0].zone, FocusZone.relaxation);
    expect(t[1].zone, FocusZone.concentration);
  });
}
