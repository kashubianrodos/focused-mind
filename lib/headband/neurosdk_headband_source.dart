import 'dart:async';

import 'package:flutter/foundation.dart';

import 'headband_source.dart';
import 'models.dart';
import 'neurosdk_api.dart';

/// [HeadbandSource] for real BrainBit-family headbands (Mindo first) on the
/// neurosdk2 C API, through [NeuroSdkApi] (design D3). Timeouts and
/// reconnection policy live in `HeadbandConnection`.
class NeuroSdkHeadbandSource implements HeadbandSource {
  /// [createApi] runs on first use, so the SDK library is only loaded once
  /// the user scans or connects; a load failure surfaces as a scan error.
  NeuroSdkHeadbandSource(
    NeuroSdkApi Function() createApi, {
    this.pollInterval = const Duration(milliseconds: 500),
  }) : _createApi = createApi;

  final NeuroSdkApi Function() _createApi;
  NeuroSdkApi? _apiInstance;
  NeuroSdkApi get _api => _apiInstance ??= _createApi();

  /// How often the scanner's device list is read while scanning.
  final Duration pollInterval;

  NeuroSensor? _sensor;
  DeviceInfo? _device;
  StreamMode _mode = StreamMode.idle;
  final _subs = <StreamSubscription<Object?>>[];
  StreamController<List<DeviceInfo>>? _scan;

  final _linkChanges = StreamController<bool>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _resistance = StreamController<ContactReport>.broadcast();
  final _signal = StreamController<List<EegSample>>.broadcast();

  @override
  Stream<List<DeviceInfo>> scan() {
    Timer? poll;
    late final StreamController<List<DeviceInfo>> controller;
    controller = StreamController<List<DeviceInfo>>(
      onListen: () {
        try {
          _api.startScan();
        } on Object catch (e, s) {
          controller
            ..addError(e, s)
            ..close();
          return;
        }
        var last = const <DeviceInfo>[];
        controller.add(last);
        poll = Timer.periodic(pollInterval, (_) {
          final found = _api.scannedDevices();
          if (!listEquals(found, last)) controller.add(last = found);
        });
      },
      onCancel: () {
        poll?.cancel();
        _apiInstance?.stopScan();
        if (identical(_scan, controller)) _scan = null;
      },
    );
    return (_scan = controller).stream;
  }

  @override
  Future<void> stopScan() async {
    final scan = _scan;
    _scan = null;
    await scan?.close();
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    final existing = _sensor;
    if (existing != null && _device == device) {
      await existing.reconnect();
      return;
    }
    _release();
    final sensor = await _api.connect(device);
    _sensor = sensor;
    _device = device;
    _mode = StreamMode.idle;
    _subs.addAll([
      sensor.inRange.listen(_linkChanges.add),
      sensor.battery.listen(_battery.add),
      sensor.resistance.listen(_onResistance),
      sensor.signal.listen(_onSignal),
    ]);
  }

  @override
  Future<void> disconnect() async {
    final sensor = _sensor;
    if (sensor == null) return;
    _stopMode(sensor);
    await sensor.disconnect();
    _release();
  }

  @override
  Future<void> setMode(StreamMode mode) async {
    final sensor = _sensor;
    if (sensor == null) return;
    _stopMode(sensor);
    _mode = mode;
    switch (mode) {
      case StreamMode.idle:
        break;
      case StreamMode.resistance:
        sensor.execute(SensorCommandKind.startResist);
      case StreamMode.signal:
        sensor.execute(SensorCommandKind.startSignal);
    }
  }

  void _stopMode(NeuroSensor sensor) {
    switch (_mode) {
      case StreamMode.idle:
        break;
      case StreamMode.resistance:
        sensor.execute(SensorCommandKind.stopResist);
      case StreamMode.signal:
        sensor.execute(SensorCommandKind.stopSignal);
    }
    _mode = StreamMode.idle;
  }

  void _onResistance(Float64List ohms) {
    if (ohms.length < 4) return;
    _resistance.add(
      ContactReport.fromOhms(
        o1: ohms[0],
        o2: ohms[1],
        t3: ohms[2],
        t4: ohms[3],
      ),
    );
  }

  void _onSignal(Float64List values) {
    final samples = <EegSample>[
      for (var i = 0; i + 3 < values.length; i += 4)
        EegSample(values[i], values[i + 1], values[i + 2], values[i + 3]),
    ];
    if (samples.isNotEmpty) _signal.add(samples);
  }

  void _release() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _sensor?.dispose();
    _sensor = null;
    _device = null;
    _mode = StreamMode.idle;
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
  int get samplingRate => _sensor?.samplingRate ?? 250;

  @override
  Future<void> dispose() async {
    await stopScan();
    _release();
    _apiInstance?.dispose();
    await Future.wait([
      _linkChanges.close(),
      _battery.close(),
      _resistance.close(),
      _signal.close(),
    ]);
  }
}
