import 'dart:async';
import 'dart:math' as math;

import 'headband_source.dart';
import 'models.dart';

/// A headband that produces EEG-like data with a controllable focus level,
/// contact quality, battery and disconnections. Used in development builds
/// and in tests (headband-connection spec: "Simulated headband").
class SimulatedHeadbandSource implements HeadbandSource {
  SimulatedHeadbandSource({int seed = 7, this.samplingRate = 250})
    : _random = math.Random(seed) {
    _oscillators = [
      for (var i = 0; i < 4; i++)
        _ElectrodeOscillators(
          thetaPhase: _random.nextDouble() * 2 * math.pi,
          alphaPhase: _random.nextDouble() * 2 * math.pi,
          betaPhase: _random.nextDouble() * 2 * math.pi,
          gain: 0.85 + _random.nextDouble() * 0.3,
        ),
    ];
  }

  static const device = DeviceInfo(
    name: 'Simulated headband',
    serialNumber: 'SIM-0001',
    address: 'simulated',
    family: HeadbandFamily.simulated,
  );

  /// How often a batch of samples is emitted.
  static const batchInterval = Duration(milliseconds: 100);

  @override
  final int samplingRate;

  final math.Random _random;
  late final List<_ElectrodeOscillators> _oscillators;

  final _linkChanges = StreamController<bool>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _resistance = StreamController<ContactReport>.broadcast();
  final _signal = StreamController<List<EegSample>>.broadcast();

  Timer? _ticker;
  Timer? _outageTimer;
  bool _connected = false;
  bool _inRange = true;
  StreamMode _mode = StreamMode.idle;
  int _sampleIndex = 0;
  int _ticks = 0;

  /// Focus level in [0, 1]; higher means more beta and less alpha/theta.
  double focus = 0.5;

  /// Simulated resistance per electrode, in ohms.
  Map<Electrode, double> ohms = {for (final e in Electrode.values) e: 150e3};

  /// When true, large movement artifacts are mixed into the signal.
  bool artifacts = false;

  int batteryPercent = 80;

  /// When false, [connect] fails (to exercise connection errors).
  bool connectable = true;

  bool get isStreaming => _ticker != null;

  @override
  Stream<List<DeviceInfo>> scan() async* {
    yield const [];
    await Future<void>.delayed(const Duration(milliseconds: 300));
    yield const [device];
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(DeviceInfo device) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!connectable || !_inRange) {
      throw StateError('Simulated headband is not reachable');
    }
    _connected = true;
    _battery.add(batteryPercent);
    _restartTicker();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _stopTicker();
  }

  @override
  Future<void> setMode(StreamMode mode) async {
    _mode = mode;
    _restartTicker();
  }

  /// Drops the link. With [restoreAfter], the device comes back in range
  /// after that delay; otherwise it stays gone until [restoreLink].
  void dropLink({Duration? restoreAfter}) {
    if (!_connected) return;
    _inRange = false;
    _connected = false;
    _stopTicker();
    _linkChanges.add(false);
    _outageTimer?.cancel();
    if (restoreAfter != null) {
      _outageTimer = Timer(restoreAfter, restoreLink);
    }
  }

  /// Brings the device back in range so that a reconnect can succeed.
  void restoreLink() {
    _outageTimer?.cancel();
    _inRange = true;
  }

  void setBattery(int percent) {
    batteryPercent = percent;
    if (_connected) _battery.add(percent);
  }

  void _restartTicker() {
    _stopTicker();
    if (!_connected || _mode == StreamMode.idle) return;
    _ticker = Timer.periodic(batchInterval, (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    _ticks++;
    switch (_mode) {
      case StreamMode.resistance:
        // Report contact once per second, like the real band.
        if (_ticks % 10 == 0) {
          _resistance.add(
            ContactReport.fromOhms(
              o1: ohms[Electrode.o1]!,
              o2: ohms[Electrode.o2]!,
              t3: ohms[Electrode.t3]!,
              t4: ohms[Electrode.t4]!,
            ),
          );
        }
      case StreamMode.signal:
        final n = samplingRate * batchInterval.inMilliseconds ~/ 1000;
        _signal.add([for (var i = 0; i < n; i++) _nextSample()]);
      case StreamMode.idle:
        break;
    }
  }

  EegSample _nextSample() {
    final t = _sampleIndex++ / samplingRate;
    double channel(int i) {
      final o = _oscillators[i];
      // Amplitudes in volts. Focus shifts power from alpha/theta to beta.
      final theta = 14e-6 * (1.1 - 0.7 * focus);
      final alpha = 22e-6 * (1.15 - 0.9 * focus);
      final beta = 7e-6 * (0.3 + 1.4 * focus);
      final v =
          theta * math.sin(2 * math.pi * 6 * t + o.thetaPhase) +
          alpha * math.sin(2 * math.pi * 10 * t + o.alphaPhase) +
          beta * math.sin(2 * math.pi * 21 * t + o.betaPhase) +
          4e-6 * _gaussian();
      // Movement artifacts hit the temporal electrodes (indices 2, 3) far
      // more than the occipital ones; a common-mode artifact would cancel
      // out in the T3−O1 / T4−O2 bipolar channels.
      final artifact = artifacts && i >= 2
          ? (((t * 4) % 1) < 0.08 ? 300e-6 : 0) +
                150e-6 * math.sin(2 * math.pi * 17 * t)
          : 0;
      return o.gain * v + artifact;
    }

    return EegSample(channel(0), channel(1), channel(2), channel(3));
  }

  double _gaussian() {
    final u1 = math.max(_random.nextDouble(), 1e-12);
    final u2 = _random.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  @override
  Stream<bool> get linkChanges => _linkChanges.stream;

  @override
  Stream<int> get battery => _battery.stream;

  @override
  Stream<ContactReport> get resistance => _resistance.stream;

  @override
  Stream<List<EegSample>> get signal => _signal.stream;

  @override
  Future<void> dispose() async {
    _stopTicker();
    _outageTimer?.cancel();
    await _linkChanges.close();
    await _battery.close();
    await _resistance.close();
    await _signal.close();
  }
}

class _ElectrodeOscillators {
  const _ElectrodeOscillators({
    required this.thetaPhase,
    required this.alphaPhase,
    required this.betaPhase,
    required this.gain,
  });

  final double thetaPhase;
  final double alphaPhase;
  final double betaPhase;
  final double gain;
}
