import '../feedback/drop_tracker.dart';
import '../feedback/feedback_settings.dart';
import '../focus/focus_score.dart';
import '../focus/focus_state.dart';
import '../focus/rhythms.dart';
import '../focus/session_kind.dart';
import 'session_models.dart';

/// Records a session's 1 Hz timeline and marks, and computes its summary
/// with disconnection gaps excluded (focus-sessions spec).
class SessionRecorder {
  SessionRecorder({
    required this.id,
    required this.startedAt,
    this.plannedDuration,
    this.mode = FeedbackMode.alert,
    this.kind = SessionKind.focus,
  });

  final String id;
  final DateTime startedAt;
  final Duration? plannedDuration;
  final FeedbackMode mode;
  final SessionKind kind;

  final _timeline = <TimelinePoint>[];
  final _marks = <SessionMark>[];
  int _drops = 0;
  int _recoveries = 0;
  bool _inGap = false;

  List<TimelinePoint> get timeline => List.unmodifiable(_timeline);
  List<SessionMark> get marks => List.unmodifiable(_marks);
  int get _second => _timeline.length;

  /// Seconds of tracking so far, gaps excluded.
  Duration get activeDuration =>
      Duration(seconds: _timeline.where((p) => !p.gap).length);

  /// Records one tracked second, with the drop event it produced, if any.
  /// The zone is taken from [scale], the one in force at this second, so
  /// later baseline changes don't rewrite history.
  void record({
    required double? score,
    required FocusState state,
    DropEvent? event,
    FeedbackMode? mode,
    ScoreScale scale = const ScoreScale(),
    RhythmShares? rhythms,
  }) {
    if (_inGap) {
      _inGap = false;
      _marks.add(SessionMark(_second, MarkKind.gapEnd));
    }
    switch (event) {
      case DropEvent.drop:
        _drops++;
        _marks.add(SessionMark(_second, MarkKind.drop));
      case DropEvent.recovery:
        _recoveries++;
        _marks.add(SessionMark(_second, MarkKind.recovery));
      case null:
        break;
    }
    _timeline.add(
      TimelinePoint(
        second: _second,
        score: score,
        state: state,
        mode: mode ?? this.mode,
        zone: score == null ? null : scale.zoneOf(score),
        rhythms: score == null ? null : rhythms,
      ),
    );
  }

  /// Records one second while the headband was disconnected.
  void recordGap() {
    if (!_inGap) {
      _inGap = true;
      _marks.add(SessionMark(_second, MarkKind.gapStart));
    }
    _timeline.add(
      TimelinePoint(
        second: _second,
        score: null,
        state: FocusState.unavailable,
        gap: true,
        mode: mode,
      ),
    );
  }

  SessionRecord finish({bool hasRawRecording = false}) {
    final tracked = _timeline.where((p) => !p.gap).toList();
    final scores = [
      for (final p in tracked)
        if (p.score != null) p.score!,
    ];
    final timeInState = <FocusState, Duration>{
      for (final s in FocusState.values)
        s: Duration(seconds: tracked.where((p) => p.state == s).length),
    };
    final timeInZone = <FocusZone, Duration>{
      for (final z in FocusZone.values)
        z: Duration(seconds: tracked.where((p) => p.zone == z).length),
    };
    final shares = [
      for (final p in tracked)
        if (p.rhythms != null) p.rhythms!,
    ];
    double mean(Rhythm r) =>
        shares.map((s) => s[r]).reduce((a, b) => a + b) / shares.length;
    var longest = 0;
    var run = 0;
    for (final p in _timeline) {
      if (p.gap) continue; // a gap pauses a focused stretch without ending it
      run = p.state == FocusState.focused ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    return SessionRecord(
      summary: SessionSummary(
        id: id,
        startedAt: startedAt,
        duration: Duration(seconds: tracked.length),
        plannedDuration: plannedDuration,
        averageScore: scores.isEmpty
            ? null
            : scores.reduce((a, b) => a + b) / scores.length,
        timeInState: timeInState,
        drops: _drops,
        recoveries: _recoveries,
        longestFocused: Duration(seconds: longest),
        mode: mode,
        kind: kind,
        timeInZone: timeInZone,
        averageRhythms: shares.isEmpty
            ? null
            : RhythmShares.normalized(
                mean(Rhythm.theta),
                mean(Rhythm.alpha),
                mean(Rhythm.beta),
              ),
        hasRawRecording: hasRawRecording,
      ),
      timeline: timeline,
      marks: marks,
    );
  }
}
