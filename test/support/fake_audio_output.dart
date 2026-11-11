import 'package:focused_mind/feedback/audio_output.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';

class FakeAudioOutput implements AudioOutput {
  Soundscape? loaded;
  bool playing = false;
  double volume = 0;
  final volumes = <double>[];
  final previews = <Soundscape>[];
  int chimes = 0;
  int plays = 0;
  int pauses = 0;

  @override
  Future<void> load(Soundscape soundscape) async => loaded = soundscape;

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
  Future<void> preview(Soundscape soundscape, double volume) async =>
      previews.add(soundscape);

  @override
  Future<void> playChime(double volume) async => chimes++;

  @override
  Future<void> dispose() async {}
}
