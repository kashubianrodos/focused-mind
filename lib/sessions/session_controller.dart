import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../feedback/drop_tracker.dart';
import '../feedback/feedback_controller.dart';
import '../feedback/feedback_settings.dart';
import '../focus/focus_engine.dart';
import '../focus/focus_state.dart';
import '../headband/headband_connection.dart';
import '../headband/headband_source.dart';
import '../headband/models.dart';
import 'session_models.dart';
import 'raw_signal.dart';
import 'session_recorder.dart';
import 'session_repository.dart';

enum SessionPhase {
  idle,

  /// Waiting until every electrode has at least fair contact.
  signalCheck,
  calibrating,
  calibrationFailed,
  running,

  /// Headband disconnected or reconnecting; timing is paused.
  paused,
  ended,
}

/// Live values shown while a session runs.
class LiveSession {
  const LiveSession({
    required this.elapsed,
    required this.planned,
    required this.reading,
    required this.state,
    required this.points,
    required this.marks,
  });

  final Duration elapsed;
  final Duration? planned;
  final FocusReading? reading;
  final FocusState state;
  final List<TimelinePoint> points;
  final List<SessionMark> marks;

  Duration? get remaining => planned == null
      ? null
      : (planned! - elapsed).isNegative
      ? Duration.zero
      : planned! - elapsed;
}

/// Runs one focus session at a time (focus-sessions spec): signal check,
/// calibration, live tracking with feedback, pausing during disconnection,
/// and saving the result.
class SessionController {
  SessionController({
    required this.connection,
    required this.feedback,
    required this.repository,
    required this._createEngine,
    required this._settings,
    this._recordRaw,
  }) {
    _settings.addListener(_onSettingsChanged);
    connection.state.addListener(_onConnectionChanged);
  }

  final HeadbandConnection connection;
  final FeedbackController feedback;
  final SessionRepository repository;
  final FocusEngine Function() _createEngine;
  final ValueListenable<FeedbackSettings> _settings;
  final ValueListenable<bool>? _recordRaw;

  final ValueNotifier<SessionPhase> phase = ValueNotifier(SessionPhase.idle);
  final ValueNotifier<LiveSession?> live = ValueNotifier(null);

  /// Calibration progress 0–100 while calibrating.
  final ValueNotifier<int> calibrationPercent = ValueNotifier(0);

  /// Why calibration failed, while in [SessionPhase.calibrationFailed].
  String? calibrationError;

  /// The summary of the session that just ended.
  SessionRecord? lastRecord;

  /// Set when raw recording stopped because of a write error; the session
  /// itself carries on.
  final ValueNotifier<String?> rawRecordingError = ValueNotifier(null);

  FocusEngine? _engine;
  DropTracker? _drops;
  SessionRecorder? _recorder;
  RawSignalRecorder? _raw;
  StreamSubscription<FocusReading>? _readingSub;
  Timer? _gapTimer;
  Duration? _planned;
  Duration _elapsed = Duration.zero;
  FocusReading? _lastReading;
  FocusState _lastState = FocusState.unavailable;

  bool get canStart =>
      connection.isConnected &&
      (phase.value == SessionPhase.idle || phase.value == SessionPhase.ended);

  bool get isActive => switch (phase.value) {
    SessionPhase.idle || SessionPhase.ended => false,
    _ => true,
  };

  /// Starts a session with an optional planned duration. Returns false
  /// (and does nothing) when no headband is connected.
  Future<bool> start({Duration? planned}) async {
    if (!canStart) return false;
    _planned = planned;
    _elapsed = Duration.zero;
    lastRecord = null;
    calibrationError = null;
    live.value = null;
    phase.value = SessionPhase.signalCheck;
    await connection.setMode(StreamMode.resistance);
    connection.contact.addListener(_checkContact);
    _checkContact();
    return true;
  }

  void _checkContact() {
    if (phase.value != SessionPhase.signalCheck) return;
    final report = connection.contact.value;
    if (report == null || !report.allAtLeastFair) return;
    connection.contact.removeListener(_checkContact);
    _calibrate();
  }

  /// Contact report during the signal check, for guiding the user.
  ContactReport? get contact => connection.contact.value;

  Future<void> _calibrate() async {
    phase.value = SessionPhase.calibrating;
    calibrationPercent.value = 0;
    await connection.setMode(StreamMode.signal);
    final engine = _engine ??= _createEngine();
    engine.scale = _settings.value.scoreScale;
    void onProgress() =>
        calibrationPercent.value = engine.calibrationPercent.value;
    engine.calibrationPercent.addListener(onProgress);
    final result = await engine.calibrate();
    engine.calibrationPercent.removeListener(onProgress);
    if (phase.value != SessionPhase.calibrating) return; // ended meanwhile
    if (!result.succeeded) {
      calibrationError = result.message;
      phase.value = SessionPhase.calibrationFailed;
      return;
    }
    _beginTracking(engine);
  }

  /// Restarts calibration after a failure, from the signal check.
  Future<void> retryCalibration() async {
    if (phase.value != SessionPhase.calibrationFailed) return;
    calibrationError = null;
    phase.value = SessionPhase.signalCheck;
    await connection.setMode(StreamMode.resistance);
    connection.contact.addListener(_checkContact);
    _checkContact();
  }

  void _beginTracking(FocusEngine engine) {
    final settings = _settings.value;
    _drops = DropTracker(triggerDelay: settings.triggerDelay);
    _recorder = SessionRecorder(
      id: clock.now().microsecondsSinceEpoch.toString(),
      startedAt: clock.now(),
      plannedDuration: _planned,
      mode: settings.mode,
    );
    rawRecordingError.value = null;
    if (_recordRaw?.value ?? false) {
      _raw = RawSignalRecorder(
        sink: repository.openRawRecording(_recorder!.id),
        samplingRate: connection.samplingRate,
        onError: (e) =>
            rawRecordingError.value = 'Raw signal recording stopped: $e',
      )..start(connection.samples);
    }
    feedback.applySettings(settings);
    feedback.start();
    _readingSub = engine.readings.listen(_onReading);
    phase.value = SessionPhase.running;
    _publishLive();
  }

  void _onReading(FocusReading reading) {
    if (phase.value != SessionPhase.running) return;
    final settings = _settings.value;
    final state = classifyFocus(reading.score, settings.threshold);
    final event = _drops!.update(state, _elapsed);
    feedback.update(score: reading.score, dropActive: _drops!.dropActive);
    _recorder!.record(
      score: reading.score,
      state: state,
      event: event,
      mode: settings.mode,
      scale: settings.scoreScale,
      rhythms: reading.rhythms,
    );
    _lastReading = reading;
    _lastState = state;
    _elapsed += const Duration(seconds: 1);
    _publishLive();
    if (_planned != null && _elapsed >= _planned!) {
      end(completed: true);
    }
  }

  void _onConnectionChanged() {
    final s = connection.state.value;
    if (phase.value == SessionPhase.running &&
        s != HeadbandConnectionState.connected) {
      phase.value = SessionPhase.paused;
      _drops?.interrupt();
      _raw?.gap();
      _gapTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recorder?.recordGap();
        feedback.update(score: null, dropActive: _drops?.dropActive ?? false);
        _publishLive();
      });
    } else if (phase.value == SessionPhase.paused) {
      if (s == HeadbandConnectionState.connected) {
        // Gap under 60 s: resume without recalibrating (design D10).
        _gapTimer?.cancel();
        phase.value = SessionPhase.running;
      } else if (s == HeadbandConnectionState.disconnected) {
        // The headband did not come back; keep what was recorded.
        end();
      }
    } else if (s != HeadbandConnectionState.connected &&
        (phase.value == SessionPhase.signalCheck ||
            phase.value == SessionPhase.calibrating ||
            phase.value == SessionPhase.calibrationFailed) &&
        s == HeadbandConnectionState.disconnected) {
      _abort();
    }
  }

  void _onSettingsChanged() {
    if (!isActive) return;
    final settings = _settings.value;
    _drops?.triggerDelay = settings.triggerDelay;
    _engine?.scale = settings.scoreScale;
    feedback.applySettings(settings);
  }

  void mute() => feedback.mute();

  void _publishLive() {
    final r = _recorder;
    live.value = LiveSession(
      elapsed: _elapsed,
      planned: _planned,
      reading: _lastReading,
      state: _lastState,
      points: r?.timeline ?? const [],
      marks: r?.marks ?? const [],
    );
  }

  /// Ends the session, saves it and returns its record (null if it ended
  /// before tracking began).
  Future<SessionRecord?> end({bool completed = false}) async {
    if (!isActive) return lastRecord;
    final wasTracking = _recorder != null;
    _gapTimer?.cancel();
    unawaited(_readingSub?.cancel());
    _readingSub = null;
    connection.contact.removeListener(_checkContact);
    feedback.stop();
    if (completed) {
      await feedback.audio.playChime(_settings.value.volume);
    }
    _engine?.stop();
    if (connection.isConnected) await connection.setMode(StreamMode.idle);

    final raw = _raw;
    _raw = null;
    raw?.close();

    SessionRecord? record;
    if (wasTracking) {
      record = _recorder!.finish(hasRawRecording: raw?.hasData ?? false);
      await repository.save(record);
    }
    lastRecord = record;
    _recorder = null;
    await _disposeEngine();
    phase.value = wasTracking ? SessionPhase.ended : SessionPhase.idle;
    return record;
  }

  void _abort() {
    connection.contact.removeListener(_checkContact);
    _engine?.stop();
    _disposeEngine();
    phase.value = SessionPhase.idle;
  }

  Future<void> _disposeEngine() async {
    final e = _engine;
    _engine = null;
    _drops = null;
    _lastReading = null;
    _lastState = FocusState.unavailable;
    await e?.dispose();
  }

  Future<void> dispose() async {
    _settings.removeListener(_onSettingsChanged);
    connection.state.removeListener(_onConnectionChanged);
    _gapTimer?.cancel();
    unawaited(_readingSub?.cancel());
    _raw?.close();
    _raw = null;
    await _disposeEngine();
    rawRecordingError.dispose();
    phase.dispose();
    live.dispose();
    calibrationPercent.dispose();
  }
}
