import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../headband/models.dart';
import 'focus_estimator.dart';
import 'focus_score.dart';
import 'rhythms.dart';

/// Signal quality of one side of the head during a session.
enum SideQuality { good, poor }

/// One published focus update (1 Hz).
class FocusReading {
  const FocusReading({
    required this.score,
    required this.rawScore,
    required this.left,
    required this.right,
    this.rhythms,
  });

  /// Smoothed focus score 0–100, or null when unavailable.
  final double? score;

  /// Unsmoothed estimate for the last second (debug overlay), if any.
  final double? rawScore;

  /// Smoothed theta/alpha/beta shares; null whenever [score] is null.
  final RhythmShares? rhythms;

  final SideQuality left;
  final SideQuality right;

  bool get isAvailable => score != null;
}

enum CalibrationFailure { poorSignal, noData, cancelled }

class CalibrationResult {
  const CalibrationResult.success() : failure = null;
  const CalibrationResult.failed(CalibrationFailure this.failure);

  final CalibrationFailure? failure;
  bool get succeeded => failure == null;

  String get message => switch (failure) {
    null => 'Calibration complete',
    CalibrationFailure.poorSignal =>
      'Calibration could not finish: too much movement or the band lost '
          'contact. Sit still, check the band and try again.',
    CalibrationFailure.noData =>
      'Calibration could not finish: no signal arrived from the headband. '
          'Check the connection and try again.',
    CalibrationFailure.cancelled => 'Calibration was cancelled.',
  };
}

/// Feeds EEG into a [FocusEstimator] every 100 ms and publishes a smoothed
/// focus score once per second after calibration (focus-tracking spec,
/// design D5).
class FocusEngine {
  FocusEngine({
    required Stream<List<EegSample>> samples,
    required FocusEstimator Function() createEstimator,
    this.processInterval = const Duration(milliseconds: 100),
    this.publishInterval = const Duration(seconds: 1),
    this.smoothingTimeConstant = const Duration(seconds: 3),
    this.calibrationTimeout = const Duration(seconds: 60),
    this.scale = const ScoreScale(),
  }) : _createEstimator = createEstimator,
       _estimator = createEstimator() {
    _sub = samples.listen(_buffer.addAll);
  }

  final FocusEstimator Function() _createEstimator;
  final Duration processInterval;
  final Duration publishInterval;
  final Duration smoothingTimeConstant;
  final Duration calibrationTimeout;

  /// Maps the smoothed focus index to the published score. Can change
  /// mid-session (baseline setting); applies from the next published score.
  ScoreScale scale;

  FocusEstimator _estimator;
  late final StreamSubscription<List<EegSample>> _sub;
  final _buffer = <EegSample>[];
  final _readings = StreamController<FocusReading>.broadcast();

  /// Calibration progress 0–100.
  final ValueNotifier<int> calibrationPercent = ValueNotifier(0);

  Timer? _processTimer;
  Timer? _publishTimer;
  Timer? _calibrationTimeout;
  Completer<CalibrationResult>? _calibration;
  bool _tracking = false;

  // Per-second accumulators.
  final _index = <double>[];
  final _rhythms = <RhythmShares>[];
  int _steps = 0;
  int _stepsWithData = 0;
  int _artifactedSteps = 0;
  int _leftArtifacted = 0;
  int _rightArtifacted = 0;
  bool _sequenceArtifact = false;

  // Calibration accumulators.
  int _calSteps = 0;
  int _calStepsWithData = 0;

  double? _ema;
  double? _lastRaw;

  /// Smoothed theta, alpha and beta shares (design D2).
  List<double>? _rhythmEma;

  Stream<FocusReading> get readings => _readings.stream;
  bool get isTracking => _tracking;

  /// Runs calibration: completes on success, or with a failure after
  /// [calibrationTimeout]. A failed run resets the estimator so calibration
  /// can be restarted.
  Future<CalibrationResult> calibrate() {
    _stopTimers();
    _tracking = false;
    _ema = null;
    _rhythmEma = null;
    _calSteps = _calStepsWithData = 0;
    calibrationPercent.value = 0;
    _buffer.clear();
    _estimator.startCalibration();

    final done = _calibration = Completer<CalibrationResult>();
    _processTimer = Timer.periodic(processInterval, (_) {
      final hadData = _buffer.isNotEmpty;
      _step();
      _calSteps++;
      if (hadData) _calStepsWithData++;
      calibrationPercent.value = _estimator.calibrationPercent.clamp(0, 100);
      if (_estimator.isCalibrationFinished && !done.isCompleted) {
        _calibrationTimeout?.cancel();
        calibrationPercent.value = 100;
        _startTracking();
        done.complete(const CalibrationResult.success());
      }
    });
    _calibrationTimeout = Timer(calibrationTimeout, () {
      if (done.isCompleted) return;
      _stopTimers();
      final failure = _calStepsWithData < _calSteps ~/ 4
          ? CalibrationFailure.noData
          : CalibrationFailure.poorSignal;
      _estimator.dispose();
      _estimator = _createEstimator();
      done.complete(CalibrationResult.failed(failure));
    });
    return done.future;
  }

  void _startTracking() {
    _stopTimers();
    _tracking = true;
    _resetSecond();
    _processTimer = Timer.periodic(processInterval, (_) => _trackingStep());
    _publishTimer = Timer.periodic(publishInterval, (_) => _publish());
  }

  EstimatorOutput _step() {
    final batch = List<EegSample>.of(_buffer);
    _buffer.clear();
    return _estimator.process(batch);
  }

  void _trackingStep() {
    final hadData = _buffer.isNotEmpty;
    final out = _step();
    _steps++;
    if (hadData) _stepsWithData++;
    if (out.artifacted) _artifactedSteps++;
    if (out.artifactedSequence) _sequenceArtifact = true;
    if (out.leftArtifacted) _leftArtifacted++;
    if (out.rightArtifacted) _rightArtifacted++;
    final i = out.index;
    if (i != null && hadData && !out.artifacted) {
      _index.add(i.clamp(-scale.indexLimit, scale.indexLimit).toDouble());
      final r = out.rhythms;
      if (r != null) _rhythms.add(r);
    }
  }

  void _publish() {
    final half = _steps ~/ 2;
    final unavailable =
        _stepsWithData == 0 ||
        _sequenceArtifact ||
        _artifactedSteps > half ||
        _index.isEmpty;
    double? raw;
    if (_index.isNotEmpty) {
      raw = _index.reduce((a, b) => a + b) / _index.length;
    }
    if (!unavailable && raw != null) {
      final alpha =
          1 -
          math.exp(
            -publishInterval.inMilliseconds /
                smoothingTimeConstant.inMilliseconds,
          );
      _ema = _ema == null ? raw : _ema! + alpha * (raw - _ema!);
      _lastRaw = raw;
      _smoothRhythms(alpha);
    }
    final steps = math.max(_steps, 1);
    _readings.add(
      FocusReading(
        score: unavailable ? null : scale.toScore(_ema!),
        rawScore: unavailable ? null : scale.toScore(_lastRaw!),
        rhythms: unavailable ? null : _currentRhythms(),
        left: _stepsWithData == 0 || _leftArtifacted * 2 > steps
            ? SideQuality.poor
            : SideQuality.good,
        right: _stepsWithData == 0 || _rightArtifacted * 2 > steps
            ? SideQuality.poor
            : SideQuality.good,
      ),
    );
    _resetSecond();
  }

  /// Folds this second's average shares into the EMA. A second without
  /// shares keeps the previous value.
  void _smoothRhythms(double alpha) {
    if (_rhythms.isEmpty) return;
    final avg = [
      for (final r in Rhythm.values)
        _rhythms.map((s) => s[r]).reduce((a, b) => a + b) / _rhythms.length,
    ];
    final ema = _rhythmEma;
    _rhythmEma = ema == null
        ? avg
        : [for (var k = 0; k < 3; k++) ema[k] + alpha * (avg[k] - ema[k])];
  }

  RhythmShares? _currentRhythms() {
    final e = _rhythmEma;
    return e == null ? null : RhythmShares.normalized(e[0], e[1], e[2]);
  }

  void _resetSecond() {
    _index.clear();
    _rhythms.clear();
    _steps = _stepsWithData = _artifactedSteps = 0;
    _leftArtifacted = _rightArtifacted = 0;
    _sequenceArtifact = false;
  }

  void _stopTimers() {
    _processTimer?.cancel();
    _publishTimer?.cancel();
    _calibrationTimeout?.cancel();
    _calibrationTimeout = null;
    _processTimer = null;
    _publishTimer = null;
  }

  /// Stops processing and publishing; calibration is lost.
  void stop() {
    _stopTimers();
    _tracking = false;
    final pending = _calibration;
    if (pending != null && !pending.isCompleted) {
      pending.complete(
        const CalibrationResult.failed(CalibrationFailure.cancelled),
      );
    }
  }

  Future<void> dispose() async {
    _stopTimers();
    unawaited(_sub.cancel());
    await _readings.close();
    calibrationPercent.dispose();
    _estimator.dispose();
  }
}
