import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'feedback_settings.dart';

/// Audio playback behind an interface so feedback logic can be tested with a
/// fake (design D2/D7).
abstract interface class AudioOutput {
  /// Loads [soundscape] as a seamless loop, ready to [play].
  Future<void> load(Soundscape soundscape);

  Future<void> play();
  Future<void> pause();

  /// Loop volume, 0–1.
  Future<void> setVolume(double volume);

  /// Plays a few seconds of [soundscape] at [volume] (settings preview).
  Future<void> preview(Soundscape soundscape, double volume);

  /// Plays the end-of-session chime once at [volume].
  Future<void> playChime(double volume);

  Future<void> dispose();
}

class JustAudioOutput implements AudioOutput {
  static const previewLength = Duration(seconds: 4);

  final _loop = AudioPlayer();
  final _oneShot = AudioPlayer();
  Soundscape? _loaded;

  bool _sessionConfigured = false;

  /// On iOS, sounds must keep playing with the screen locked or the app in
  /// the background and with the silent switch on, and mix with the user's
  /// own music instead of stopping it.
  Future<void> _configureSession() async {
    if (_sessionConfigured || !Platform.isIOS) return;
    _sessionConfigured = true;
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
      ),
    );
  }

  @override
  Future<void> load(Soundscape soundscape) async {
    await _configureSession();
    if (_loaded == soundscape) return;
    await _loop.setAudioSource(AudioSource.asset(soundscape.asset));
    await _loop.setLoopMode(LoopMode.one);
    _loaded = soundscape;
  }

  @override
  Future<void> play() async {
    if (!_loop.playing) {
      // just_audio's play() completes only when playback stops.
      _loop.play();
    }
  }

  @override
  Future<void> pause() => _loop.pause();

  @override
  Future<void> setVolume(double volume) =>
      _loop.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> preview(Soundscape soundscape, double volume) async {
    await _configureSession();
    await _oneShot.setAudioSource(
      ClippingAudioSource(
        child: AudioSource.asset(soundscape.asset),
        end: previewLength,
      ),
    );
    await _oneShot.setVolume(volume);
    await _oneShot.seek(Duration.zero);
    _oneShot.play();
  }

  @override
  Future<void> playChime(double volume) async {
    await _configureSession();
    await _oneShot.setAudioSource(AudioSource.asset(endChimeAsset));
    await _oneShot.setVolume(volume);
    _oneShot.play();
  }

  @override
  Future<void> dispose() async {
    await _loop.dispose();
    await _oneShot.dispose();
  }
}
