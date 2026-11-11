import 'package:em_st_artifacts/em_st_artifacts.dart';

import '../headband/models.dart';
import 'rhythms.dart';

/// What one processing step of a [FocusEstimator] produced.
class EstimatorOutput {
  const EstimatorOutput({
    required this.attention,
    this.relaxation,
    required this.bothSidesArtifacted,
    required this.artifactedSequence,
    required this.leftArtifacted,
    required this.rightArtifacted,
    this.rhythms,
  });

  /// Latest attention relative to calibration, in percent (EmotionalMath
  /// `relAttention`), or null if none was produced.
  final double? attention;

  /// Latest relaxation relative to calibration, in percent, if produced.
  final double? relaxation;

  /// Signed focus index: attention minus relaxation, 0 at the calibration
  /// level (see `ScoreScale`).
  double? get index {
    final a = attention;
    return a == null ? null : a - (relaxation ?? 0);
  }

  final bool bothSidesArtifacted;
  final bool artifactedSequence;
  final bool leftArtifacted;
  final bool rightArtifacted;

  bool get artifacted => bothSidesArtifacted || artifactedSequence;

  /// Latest theta/alpha/beta shares, once calibrated and if produced.
  final RhythmShares? rhythms;
}

/// Turns raw EEG into an attention estimate. Hidden behind an interface so
/// the vendor library can be replaced (design D5) and faked in tests.
abstract interface class FocusEstimator {
  void startCalibration();
  bool get isCalibrationFinished;

  /// Calibration progress, 0–100.
  int get calibrationPercent;

  /// Feeds samples and runs one processing step.
  EstimatorOutput process(List<EegSample> samples);

  void dispose();
}

/// [FocusEstimator] on BrainBit's `EmotionalMath` in bipolar mode
/// (left = T3−O1, right = T4−O2), settings from design D5.
class EmotionalMathEstimator implements FocusEstimator {
  EmotionalMathEstimator({int samplingRate = 250, int calibrationSeconds = 6})
    : _math = EmotionalMath(
        MathLibSettings(
          samplingRate: samplingRate,
          processWinFreq: 25,
          fftWindow: samplingRate * 4,
          nFirstSecSkipped: 4,
          bipolarMode: true,
          squaredSpectrum: true,
          channelsNumber: 4,
          channelForAnalysis: 0,
        ),
        ArtifactsDetectSetting(
          artBord: 110,
          allowedPercentArtpoints: 70,
          rawBetapLimit: 800000,
          totalPowBorder: 100,
          globalArtwinSec: 4,
          spectArtByTotal: true,
          hanningWinSpectrum: false,
          hammingWinSpectrum: true,
          numWinsForQualityAvg: 125,
        ),
        ShortArtifactsDetectSetting(
          amplArtDetectWinSize: 200,
          amplArtZerodArea: 200,
          amplArtExtremumBorder: 25,
        ),
        MentalAndSpectralSetting(
          nSecForInstantEstimation: 4,
          nSecForAveraging: 2,
        ),
      ) {
    _math
      ..setCalibrationLength(calibrationSeconds)
      ..setMentalEstimationMode(false)
      ..setSkipWinsAfterArtifact(10)
      ..setZeroSpectWaves(true, 0, 1, 1, 1, 0)
      ..setSpectNormalizationByBandsWidth(true);
  }

  final EmotionalMath _math;

  @override
  void startCalibration() => _math.startCalibration();

  @override
  bool get isCalibrationFinished => _math.isCalibrationFinished();

  @override
  int get calibrationPercent => _math.getCalibrationPercents();

  @override
  EstimatorOutput process(List<EegSample> samples) {
    if (samples.isNotEmpty) {
      _math.pushBipolars([
        for (final s in samples)
          RawChanel(leftBipolar: s.t3 - s.o1, rightBipolar: s.t4 - s.o2),
      ]);
    }
    _math.processData();
    double? attention;
    double? relaxation;
    RhythmShares? rhythms;
    if (_math.isCalibrationFinished()) {
      final mind = _math.readMentalData();
      if (mind.isNotEmpty) {
        attention = mind.last.relAttention;
        relaxation = mind.last.relRelaxation;
      }
      // Delta and gamma are zeroed (setZeroSpectWaves), so these are the
      // theta/alpha/beta shares; renormalised in case of rounding.
      final spectral = _math.readSpectralDataPercents();
      if (spectral.isNotEmpty) {
        final p = spectral.last;
        rhythms = RhythmShares.normalized(p.theta, p.alpha, p.beta);
      }
    }
    return EstimatorOutput(
      attention: attention,
      relaxation: relaxation,
      bothSidesArtifacted: _math.isBothSidesArtefacted(),
      artifactedSequence: _math.isArtifactedSequence(),
      leftArtifacted: _math.isArtifactedLeft(),
      rightArtifacted: _math.isArtifactedRight(),
      rhythms: rhythms,
    );
  }

  @override
  void dispose() => _math.dispose();
}
