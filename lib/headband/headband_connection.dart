import 'dart:async';

import 'package:flutter/foundation.dart';

import 'headband_source.dart';
import 'models.dart';

/// Events the UI surfaces as notifications.
enum HeadbandEvent { lowBattery, connectionLost }

/// Thrown when a connection attempt does not succeed in time.
class ConnectTimeoutException implements Exception {
  const ConnectTimeoutException();
  @override
  String toString() => 'Could not connect to the headband in time';
}

/// Owns the connection to one headband on top of a [HeadbandSource]:
/// scan and connect timeouts, automatic reconnection (design D10), the
/// current streaming mode, battery and contact state.
class HeadbandConnection {
  HeadbandConnection(
    this.source, {
    this.scanTimeout = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 20),
    this.reconnectInterval = const Duration(seconds: 5),
    this.reconnectWindow = const Duration(seconds: 60),
  }) {
    _subs.addAll([
      source.linkChanges.listen(_onLinkChange),
      source.battery.listen(_onBattery),
      source.resistance.listen((r) => contact.value = r),
      source.signal.listen(_samples.add),
    ]);
  }

  final HeadbandSource source;
  final Duration scanTimeout;
  final Duration connectTimeout;
  final Duration reconnectInterval;
  final Duration reconnectWindow;

  final ValueNotifier<HeadbandConnectionState> state = ValueNotifier(
    HeadbandConnectionState.disconnected,
  );
  final ValueNotifier<int?> battery = ValueNotifier(null);
  final ValueNotifier<ContactReport?> contact = ValueNotifier(null);

  final _samples = StreamController<List<EegSample>>.broadcast();
  final _events = StreamController<HeadbandEvent>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];

  DeviceInfo? _device;
  StreamMode _mode = StreamMode.idle;
  Timer? _retryTimer;
  Timer? _giveUpTimer;
  bool _lowBatteryWarned = false;
  bool _disposed = false;

  DeviceInfo? get device => _device;
  StreamMode get mode => _mode;
  int get samplingRate => source.samplingRate;

  /// EEG batches while in [StreamMode.signal].
  Stream<List<EegSample>> get samples => _samples.stream;

  Stream<HeadbandEvent> get events => _events.stream;

  bool get isConnected => state.value == HeadbandConnectionState.connected;

  bool get isLowBattery {
    final b = battery.value;
    return b != null && b <= lowBatteryPercent;
  }

  /// Scans for up to [scanTimeout], emitting the devices found so far.
  /// The stream completes when the scan ends; an empty final list means
  /// nothing was found.
  Stream<List<DeviceInfo>> scan() {
    late final StreamController<List<DeviceInfo>> out;
    StreamSubscription<List<DeviceInfo>>? sub;
    Timer? timer;
    Future<void> finish() async {
      timer?.cancel();
      unawaited(sub?.cancel());
      sub = null;
      await source.stopScan();
      if (!out.isClosed) await out.close();
    }

    out = StreamController<List<DeviceInfo>>(
      onListen: () {
        sub = source.scan().listen(
          out.add,
          onError: (Object e, StackTrace st) {
            out.addError(e, st);
            finish();
          },
          onDone: finish,
        );
        timer = Timer(scanTimeout, finish);
      },
      onCancel: finish,
    );
    return out.stream;
  }

  /// Connects to [device], or throws [ConnectTimeoutException] / the
  /// source's error, leaving the state disconnected.
  Future<void> connect(DeviceInfo device) async {
    _cancelReconnect();
    _device = device;
    _lowBatteryWarned = false;
    state.value = HeadbandConnectionState.connecting;
    try {
      await source
          .connect(device)
          .timeout(
            connectTimeout,
            onTimeout: () => throw const ConnectTimeoutException(),
          );
    } catch (_) {
      state.value = HeadbandConnectionState.disconnected;
      rethrow;
    }
    state.value = HeadbandConnectionState.connected;
    await source.setMode(_mode);
  }

  Future<void> disconnect() async {
    _cancelReconnect();
    state.value = HeadbandConnectionState.disconnected;
    _mode = StreamMode.idle;
    contact.value = null;
    battery.value = null;
    await source.disconnect();
  }

  /// Switches what the headband streams; remembered across reconnects.
  Future<void> setMode(StreamMode mode) async {
    _mode = mode;
    // Entering (or re-requesting) resistance mode waits for a fresh report,
    // so a contact check never passes on a stale one.
    contact.value = null;
    if (isConnected) await source.setMode(mode);
  }

  void _onLinkChange(bool inRange) {
    if (inRange || _device == null) return;
    if (state.value != HeadbandConnectionState.connected) return;
    state.value = HeadbandConnectionState.reconnecting;
    _giveUpTimer = Timer(reconnectWindow, _giveUp);
    _scheduleRetry(Duration.zero);
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer = Timer(delay, () async {
      if (state.value != HeadbandConnectionState.reconnecting) return;
      try {
        await source.connect(_device!).timeout(reconnectInterval);
      } catch (_) {
        if (state.value == HeadbandConnectionState.reconnecting) {
          _scheduleRetry(reconnectInterval);
        }
        return;
      }
      if (state.value != HeadbandConnectionState.reconnecting) return;
      _cancelReconnect();
      state.value = HeadbandConnectionState.connected;
      await source.setMode(_mode);
    });
  }

  void _giveUp() {
    if (state.value != HeadbandConnectionState.reconnecting) return;
    _cancelReconnect();
    state.value = HeadbandConnectionState.disconnected;
    contact.value = null;
    _events.add(HeadbandEvent.connectionLost);
    source.disconnect();
  }

  void _cancelReconnect() {
    _retryTimer?.cancel();
    _giveUpTimer?.cancel();
    _retryTimer = null;
    _giveUpTimer = null;
  }

  void _onBattery(int percent) {
    battery.value = percent;
    if (percent <= lowBatteryPercent && !_lowBatteryWarned) {
      _lowBatteryWarned = true;
      _events.add(HeadbandEvent.lowBattery);
    } else if (percent > lowBatteryPercent) {
      _lowBatteryWarned = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelReconnect();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    await _samples.close();
    await _events.close();
    state.dispose();
    battery.dispose();
    contact.dispose();
    await source.dispose();
  }
}
