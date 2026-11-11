import '../feedback/feedback_settings.dart';
import '../focus/focus_score.dart';
import '../focus/focus_state.dart';
import '../focus/rhythms.dart';

/// One second of a session's focus timeline.
class TimelinePoint {
  const TimelinePoint({
    required this.second,
    required this.score,
    required this.state,
    this.gap = false,
    this.mode = FeedbackMode.alert,
    this.zone,
    this.rhythms,
  });

  /// Seconds since the session started (wall time, gaps included).
  final int second;

  /// Smoothed focus score, or null when unavailable or during a gap.
  final double? score;
  final FocusState state;

  /// True while the headband was disconnected (excluded from statistics).
  final bool gap;
  final FeedbackMode mode;

  /// Scale zone at this second (with the baseline then in force), or null
  /// when unavailable or recorded before zones existed.
  final FocusZone? zone;

  /// Theta/alpha/beta shares, or null when unavailable or not recorded.
  final RhythmShares? rhythms;

  Map<String, Object?> toJson() => {
    's': second,
    'v': score == null ? null : double.parse(score!.toStringAsFixed(1)),
    'st': state.name,
    if (gap) 'g': true,
    'm': mode.name,
    if (zone != null) 'z': zone!.name,
    if (rhythms != null) 'r': rhythms!.toJson(),
  };

  factory TimelinePoint.fromJson(Map<String, Object?> json) => TimelinePoint(
    second: json['s']! as int,
    score: (json['v'] as num?)?.toDouble(),
    state: FocusState.values.byName(json['st']! as String),
    gap: json['g'] == true,
    mode:
        FeedbackMode.values.where((m) => m.name == json['m']).firstOrNull ??
        FeedbackMode.alert,
    zone: FocusZone.values.where((z) => z.name == json['z']).firstOrNull,
    rhythms: RhythmShares.fromJson(json['r']),
  );
}

enum MarkKind { drop, recovery, gapStart, gapEnd }

class SessionMark {
  const SessionMark(this.second, this.kind);

  final int second;
  final MarkKind kind;

  Map<String, Object> toJson() => {'s': second, 'k': kind.name};

  factory SessionMark.fromJson(Map<String, Object?> json) => SessionMark(
    json['s']! as int,
    MarkKind.values.byName(json['k']! as String),
  );
}

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.startedAt,
    required this.duration,
    required this.plannedDuration,
    required this.averageScore,
    required this.timeInState,
    required this.drops,
    required this.recoveries,
    required this.longestFocused,
    required this.mode,
    this.timeInZone = const {},
    this.averageRhythms,
    this.hasRawRecording = false,
  });

  final String id;
  final DateTime startedAt;

  /// Time spent tracking, excluding disconnection gaps.
  final Duration duration;
  final Duration? plannedDuration;

  /// Average of the available scores, or null if there were none.
  final double? averageScore;
  final Map<FocusState, Duration> timeInState;
  final int drops;
  final int recoveries;
  final Duration longestFocused;

  /// The feedback mode when the session started.
  final FeedbackMode mode;

  /// Time per scale zone, excluding gaps and unavailable seconds; empty for
  /// sessions recorded before zones existed.
  final Map<FocusZone, Duration> timeInZone;

  /// Average theta/alpha/beta shares, or null if none were recorded.
  final RhythmShares? averageRhythms;

  /// Whether the raw EEG signal was recorded for this session.
  final bool hasRawRecording;

  Duration timeIn(FocusState state) => timeInState[state] ?? Duration.zero;

  Duration timeInZoneOf(FocusZone zone) => timeInZone[zone] ?? Duration.zero;

  /// Whether this session carries zone and rhythm data.
  bool get hasRhythms => averageRhythms != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'plannedSeconds': plannedDuration?.inSeconds,
    'averageScore': averageScore,
    'timeInState': {
      for (final e in timeInState.entries) e.key.name: e.value.inSeconds,
    },
    'drops': drops,
    'recoveries': recoveries,
    'longestFocusedSeconds': longestFocused.inSeconds,
    'mode': mode.name,
    if (timeInZone.isNotEmpty)
      'timeInZone': {
        for (final e in timeInZone.entries) e.key.name: e.value.inSeconds,
      },
    if (averageRhythms != null) 'averageRhythms': averageRhythms!.toJson(),
    if (hasRawRecording) 'hasRawRecording': true,
  };

  factory SessionSummary.fromJson(Map<String, Object?> json) {
    final states =
        (json['timeInState'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final zones =
        (json['timeInZone'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    return SessionSummary(
      id: json['id']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String),
      duration: Duration(seconds: json['durationSeconds']! as int),
      plannedDuration: json['plannedSeconds'] == null
          ? null
          : Duration(seconds: json['plannedSeconds']! as int),
      averageScore: (json['averageScore'] as num?)?.toDouble(),
      timeInState: {
        for (final s in FocusState.values)
          if (states[s.name] is int)
            s: Duration(seconds: states[s.name]! as int),
      },
      drops: json['drops']! as int,
      recoveries: json['recoveries']! as int,
      longestFocused: Duration(seconds: json['longestFocusedSeconds']! as int),
      mode:
          FeedbackMode.values
              .where((m) => m.name == json['mode'])
              .firstOrNull ??
          FeedbackMode.alert,
      timeInZone: {
        for (final z in FocusZone.values)
          if (zones[z.name] is int) z: Duration(seconds: zones[z.name]! as int),
      },
      averageRhythms: RhythmShares.fromJson(json['averageRhythms']),
      hasRawRecording: json['hasRawRecording'] == true,
    );
  }
}

/// A completed session: summary plus its timeline and marks.
class SessionRecord {
  const SessionRecord({
    required this.summary,
    required this.timeline,
    required this.marks,
  });

  final SessionSummary summary;
  final List<TimelinePoint> timeline;
  final List<SessionMark> marks;

  Map<String, Object?> timelineJson() => {
    'timeline': [for (final p in timeline) p.toJson()],
    'marks': [for (final m in marks) m.toJson()],
  };
}
