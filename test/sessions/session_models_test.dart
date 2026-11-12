import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/focus/session_kind.dart';
import 'package:focused_mind/sessions/session_models.dart';

void main() {
  test('zone and rhythms round-trip in a timeline point', () {
    final p = TimelinePoint(
      second: 3,
      score: 72,
      state: FocusState.focused,
      zone: FocusZone.concentration,
      rhythms: RhythmShares.normalized(20, 30, 50),
    );
    final back = TimelinePoint.fromJson(p.toJson());
    expect(back.zone, FocusZone.concentration);
    expect(back.rhythms!.beta, closeTo(50, 0.1));
  });

  test('an unavailable point stores no zone or rhythms', () {
    const p = TimelinePoint(
      second: 3,
      score: null,
      state: FocusState.unavailable,
    );
    expect(p.toJson().keys, isNot(contains('z')));
    expect(p.toJson().keys, isNot(contains('r')));
  });

  test('a pre-change timeline point loads with empty new fields', () {
    final p = TimelinePoint.fromJson({
      's': 5,
      'v': 61.2,
      'st': 'neutral',
      'm': 'alert',
    });
    expect(p.score, 61.2);
    expect(p.zone, isNull);
    expect(p.rhythms, isNull);
  });

  test('summary zone times, average rhythms and raw flag round-trip', () {
    final s = SessionSummary(
      id: '1',
      startedAt: DateTime(2026, 11, 11, 9),
      duration: const Duration(minutes: 25),
      plannedDuration: const Duration(minutes: 25),
      averageScore: 55,
      timeInState: const {FocusState.focused: Duration(minutes: 10)},
      drops: 1,
      recoveries: 1,
      longestFocused: const Duration(minutes: 5),
      mode: FeedbackMode.alert,
      timeInZone: const {
        FocusZone.relaxation: Duration(minutes: 5),
        FocusZone.concentration: Duration(minutes: 20),
      },
      averageRhythms: RhythmShares.normalized(25, 35, 40),
      hasRawRecording: true,
      kind: SessionKind.meditation,
    );
    final back = SessionSummary.fromJson(s.toJson());
    expect(back.kind, SessionKind.meditation);
    expect(
      back.timeInZoneOf(FocusZone.concentration),
      const Duration(minutes: 20),
    );
    expect(back.timeInZoneOf(FocusZone.deepRelaxation), Duration.zero);
    expect(back.averageRhythms!.alpha, closeTo(35, 0.1));
    expect(back.hasRawRecording, isTrue);
    expect(back.hasRhythms, isTrue);
  });

  test('a pre-change summary loads with empty new fields', () {
    final s = SessionSummary.fromJson({
      'id': 'old',
      'startedAt': '2026-11-01T10:00:00.000',
      'durationSeconds': 600,
      'plannedSeconds': null,
      'averageScore': 48.0,
      'timeInState': {'focused': 300},
      'drops': 0,
      'recoveries': 0,
      'longestFocusedSeconds': 120,
      'mode': 'continuous',
    });
    expect(s.timeInZone, isEmpty);
    expect(s.averageRhythms, isNull);
    expect(s.hasRawRecording, isFalse);
    expect(s.hasRhythms, isFalse);
    expect(s.kind, SessionKind.focus);
  });
}
