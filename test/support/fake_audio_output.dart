import 'package:focused_mind/feedback/audio_output.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';

class FakeAudioOutput implements AudioOutput {
  Soundscape? loaded;
  bool? loadedMono;
  final previewMono = <bool>[];
  bool playing = false;
  double volume = 0;
  final volumes = <double>[];
  final previews = <Soundscape>[];
  int chimes = 0;
  int plays = 0;
  int pauses = 0;

  @override
  Future<void> load(Soundscape soundscape, {required bool mono}) async {
    loaded = soundscape;
    loadedMono = mono;
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
  }

  @override
  Future<void> setVolume(double v) async {
    volume = v;
    volumes.add(v);
  }

  @override
  Future<void> preview(
    Soundscape soundscape,
    double volume, {
    required bool mono,
  }) async {
    previews.add(soundscape);
    previewMono.add(mono);
  }

  @override
  Future<void> playChime(double volume) async => chimes++;

  @override
  Future<void> dispose() async {}
}
