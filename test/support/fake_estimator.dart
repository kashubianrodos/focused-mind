import 'package:focused_mind/focus/focus_estimator.dart';
import 'package:focused_mind/focus/focus_score.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/headband/models.dart';

/// A [FocusEstimator] whose outputs are set directly by the test.
class FakeEstimator implements FocusEstimator {
  FakeEstimator({this.stepsToCalibrate = 20});

  /// Processing steps (with data) needed to finish calibration.
  final int stepsToCalibrate;

  /// The focus score the engine should publish at the default
  /// [ScoreScale]; emitted as the matching attention or relaxation.
  double score = 50;

  /// Theta/alpha/beta shares emitted after calibration.
  RhythmShares? rhythms = RhythmShares.normalized(30, 40, 30);
  bool artifacted = false;
  bool leftArtifacted = false;
  bool rightArtifacted = false;

  /// When false, calibration never progresses (e.g. constant artifacts).
  bool calibrationCanProgress = true;

  bool _calibrating = false;
  int _calSteps = 0;
  bool disposed = false;
  int processCalls = 0;

  @override
  void startCalibration() {
    _calibrating = true;
    _calSteps = 0;
  }

  @override
  bool get isCalibrationFinished =>
      _calibrating && _calSteps >= stepsToCalibrate;

  @override
  int get calibrationPercent =>
      _calibrating ? (100 * _calSteps ~/ stepsToCalibrate).clamp(0, 100) : 0;

  @override
  EstimatorOutput process(List<EegSample> samples) {
    processCalls++;
    if (_calibrating &&
        samples.isNotEmpty &&
        calibrationCanProgress &&
        !artifacted) {
      _calSteps++;
    }
    final index = const ScoreScale().toIndex(score);
    return EstimatorOutput(
      attention: isCalibrationFinished ? (index > 0 ? index : 0) : null,
      relaxation: isCalibrationFinished ? (index < 0 ? -index : 0) : null,
      bothSidesArtifacted: artifacted,
      artifactedSequence: false,
      leftArtifacted: leftArtifacted || artifacted,
      rightArtifacted: rightArtifacted || artifacted,
      rhythms: isCalibrationFinished ? rhythms : null,
    );
  }

  @override
  void dispose() => disposed = true;
}
