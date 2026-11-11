import 'dart:async';
import 'dart:typed_data';

import 'models.dart';

/// Sensor commands the app sends (neurosdk2 `SensorCommand`).
enum SensorCommandKind {
  startSignal(0),
  stopSignal(1),
  startResist(2),
  stopResist(3);

  const SensorCommandKind(this.code);
  final int code;
}

/// neurosdk2 `SensorFamily` codes the app scans for (design D3).
abstract final class SensorFamilyCode {
  static const brainBit = 3;
  static const headband = 11;
  static const brainBit2 = 18;

  static const scanFilters = [headband, brainBit, brainBit2];

  static HeadbandFamily? toFamily(int code) => switch (code) {
    headband => HeadbandFamily.headband,
    brainBit => HeadbandFamily.brainBit,
    brainBit2 => HeadbandFamily.brainBit2,
    _ => null,
  };
}

/// A thin, fakeable layer over the neurosdk2 C API (design D3). The real
/// implementation is `FfiNeuroSdkApi`; tests use a fake.
abstract interface class NeuroSdkApi {
  /// Starts a Bluetooth scan for supported headbands. Throws
  /// [BluetoothUnavailableException] when Bluetooth cannot be used.
  void startScan();

  /// Devices found since [startScan].
  List<DeviceInfo> scannedDevices();

  void stopScan();

  /// Creates and connects the sensor for [device]; throws on failure.
  Future<NeuroSensor> connect(DeviceInfo device);

  void dispose();
}

/// One connected sensor, with its callbacks already registered.
abstract interface class NeuroSensor {
  HeadbandFamily get family;

  /// Sampling rate reported by the device, in Hz.
  int get samplingRate;

  /// SDK connection state: `true` in range, `false` out of range.
  Stream<bool> get inRange;

  Stream<int> get battery;

  /// EEG in volts, flattened as O1, O2, T3, T4 per sample.
  Stream<Float64List> get signal;

  /// Electrode resistance in ohms: O1, O2, T3, T4.
  Stream<Float64List> get resistance;

  void execute(SensorCommandKind command);

  /// Reconnects after the link was lost.
  Future<void> reconnect();

  Future<void> disconnect();

  /// Removes the callbacks and frees the native sensor.
  void dispose();
}

/// Maps a scanner error message to the guidance shown to the user.
BluetoothProblem bluetoothProblemFrom(String message) {
  final m = message.toLowerCase();
  if (m.contains('unauthorized') ||
      m.contains('permission') ||
      m.contains('denied')) {
    return BluetoothProblem.permissionDenied;
  }
  if (m.contains('powered off') ||
      m.contains('poweredoff') ||
      m.contains('turned off') ||
      m.contains('is off')) {
    return BluetoothProblem.poweredOff;
  }
  return BluetoothProblem.unavailable;
}
