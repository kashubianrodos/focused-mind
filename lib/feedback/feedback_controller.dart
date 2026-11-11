import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_output.dart';
import 'feedback_settings.dart';
import 'gain_policy.dart';

/// Drives the soundscape from the focus score and drop state (design D6a/D7):
/// computes the target gain each update and ramps the player toward it over
/// [fadeDuration] in [rampStep] steps.
class FeedbackController {
  FeedbackController(
    this.audio, {
    required this._settings,
    this.fadeDuration = const Duration(seconds: 2),
    this.rampStep = const Duration(milliseconds: 50),
    this.pauseAfterSilence = const Duration(seconds: 5),
  });

  final AudioOutput audio;
  final Duration fadeDuration;
  final Duration rampStep;
  final Duration pauseAfterSilence;

  FeedbackSettings _settings;
  bool _active = false;
  bool _muted = false;
  bool _dropActive = false;
  double? _lastScore;
  Duration _unavailableFor = Duration.zero;

  double _gain = 0;
  double _target = 0;
  double _stepSize = 0;
  int _direction = 0;
  bool _playing = false;
  Timer? _ramp;
  Duration _silentFor = Duration.zero;

  /// Current applied loop volume, for the UI indicator.
  final ValueNotifier<double> gain = ValueNotifier(0);

  bool get muted => _muted;
  bool get isAudible => _playing && _gain > 0;
  FeedbackSettings get settings => _settings;

  /// Starts feedback for a session (after calibration).
  Future<void> start() async {
    _active = true;
    _muted = false;
    _dropActive = false;
    _lastScore = null;
    _unavailableFor = Duration.zero;
    await audio.load(_settings.soundscape);
    _retarget();
  }

  /// Ends feedback, fading out.
  void stop() {
    _active = false;
    _retarget();
  }

  /// Feeds one 1 Hz update: the smoothed [score] (null when unavailable),
  /// whether a drop is active, and how long that update spans.
  void update({
    required double? score,
    required bool dropActive,
    Duration interval = const Duration(seconds: 1),
  }) {
    _dropActive = dropActive;
    if (score == null) {
      _unavailableFor += interval;
    } else {
      _unavailableFor = Duration.zero;
      _lastScore = score;
    }
    _retarget();
  }

  /// Applies new settings immediately (mode, volume, threshold, sound).
  Future<void> applySettings(FeedbackSettings settings) async {
    final soundChanged = settings.soundscape != _settings.soundscape;
    _settings = settings;
    if (soundChanged && _active) {
      final wasPlaying = _playing;
      await audio.load(settings.soundscape);
      if (wasPlaying) await audio.play();
    }
    _retarget();
  }

  void mute() {
    _muted = true;
    _retarget();
  }

  void unmute() {
    _muted = false;
    _retarget();
  }

  void _retarget() {
    _target = _active
        ? targetGain(
            mode: _settings.mode,
            dropActive: _dropActive,
            score: _lastScore,
            threshold: _settings.threshold,
            volume: _settings.volume,
            muted: _muted,
            unavailableFor: _unavailableFor,
          )
        : 0;
    // A fade covers its distance in [fadeDuration]. The score updates every
    // second and nudges the target; while the fade keeps its direction it
    // keeps at least its starting rate, so it still finishes in ~2 s.
    final steps = fadeDuration.inMicroseconds / rampStep.inMicroseconds;
    final distance = _target - _gain;
    final direction = distance.sign.toInt();
    final needed = distance.abs() / steps;
    _stepSize = direction == _direction && direction != 0
        ? (needed > _stepSize ? needed : _stepSize)
        : needed;
    _direction = direction;
    if (_target > 0 && !_playing) {
      _playing = true;
      audio.play();
    }
    _ramp ??= Timer.periodic(rampStep, (_) => _tick());
  }

  void _tick() {
    if (_gain != _target) {
      _gain = _gain < _target
          ? (_gain + _stepSize).clamp(0.0, _target)
          : (_gain - _stepSize).clamp(_target, 1.0);
      if ((_gain - _target).abs() < 1e-9) _gain = _target;
      if (_gain == _target) _direction = 0;
      audio.setVolume(_gain);
      gain.value = _gain;
    }
    if (_gain == 0 && _target == 0) {
      _silentFor += rampStep;
      if (_playing && _silentFor >= pauseAfterSilence) {
        _playing = false;
        audio.pause();
      }
      if (!_playing) {
        _ramp?.cancel();
        _ramp = null;
      }
    } else {
      _silentFor = Duration.zero;
    }
  }

  Future<void> dispose() async {
    _ramp?.cancel();
    gain.dispose();
  }
}
