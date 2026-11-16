import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform, sleep;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../neurosdk_api.dart';
import 'fm_shim.dart';
import 'neurosdk2_bindings.dart';
import 'neurosdk_library.dart';

/// [NeuroSdkApi] on the neurosdk2 C API (design D3).
///
/// - Battery and connection state arrive by value, so they use
///   `NativeCallable.listener` directly.
/// - Signal and resistance go through the `fm_*` shim, which copies the
///   SDK's buffers before they are freed (see `native/fm_shim.cpp`).
/// - Connecting blocks for seconds, so it runs on a helper isolate.
///
/// Hardware-only: covered by manual checks with the band (tasks 2.3–2.4).
class FfiNeuroSdkApi implements NeuroSdkApi {
  FfiNeuroSdkApi([NeuroSdk2Bindings? sdk])
    : _sdk = sdk ?? NeuroSdkLibrary.open();

  final NeuroSdk2Bindings _sdk;
  Pointer<SensorScanner> _scanner = nullptr;
  bool _scanning = false;

  @override
  Future<void> startScan() async {
    final existing = _scanner == nullptr ? null : _scanner.address;
    final address = await Isolate.run(() => _startScanner(existing));
    _scanner = Pointer.fromAddress(address);
    _scanning = true;
  }

  @override
  List<DeviceInfo> scannedDevices() {
    if (_scanner == nullptr) return const [];
    return _readSensors(_sdk, _scanner).map((e) => e.$1).toList();
  }

  @override
  void stopScan() {
    if (_scanner == nullptr || !_scanning) return;
    _scanning = false;
    using((arena) => _sdk.stopScanner(_scanner, arena<OpStatus>()));
  }

  @override
  Future<NeuroSensor> connect(DeviceInfo device) async {
    if (_scanner == nullptr) await startScan();
    // Mindo ("BrainBit Black") must be bonded before the SDK can connect;
    // EEGWaves bonds first too. `MainActivity` does it on Android. macOS has
    // no public bonding API, which is why the band won't connect there.
    if (Platform.isAndroid && device.name.toLowerCase().contains('black')) {
      await const MethodChannel('focused_mind/android')
          .invokeMethod<void>('bond', device.address);
    }
    final scanner = _scanner.address;
    final address = device.address;
    final sensor = await Isolate.run(() => _createSensor(scanner, address));
    return _FfiSensor(_sdk, Pointer.fromAddress(sensor), device.family);
  }

  @override
  void dispose() {
    stopScan();
    if (_scanner != nullptr) _sdk.freeScanner(_scanner);
    _scanner = nullptr;
  }
}

/// Creates the scanner if [existing] is null, starts it, and returns its
/// address. Runs on a helper isolate (see [NeuroSdkApi.startScan]).
int _startScanner(int? existing) {
  final sdk = NeuroSdkLibrary.open(required: const []);
  return using((arena) {
    final status = arena<OpStatus>();
    var scanner = existing == null
        ? nullptr
        : Pointer<SensorScanner>.fromAddress(existing);
    if (scanner == nullptr) {
      const codes = SensorFamilyCode.scanFilters;
      final filters = arena<Uint8>(codes.length);
      for (var i = 0; i < codes.length; i++) {
        filters[i] = codes[i];
      }
      scanner = sdk.createScanner(filters, codes.length, status);
      if (scanner == nullptr || status.ref.Success == 0) {
        throw _bluetoothError(status);
      }
    }
    if (sdk.startScanner(scanner, status, 1) == 0 || status.ref.Success == 0) {
      throw _bluetoothError(status);
    }
    return scanner.address;
  });
}

BluetoothUnavailableException _bluetoothError(Pointer<OpStatus> status) {
  final message = _string(status.ref.ErrorMsg, 512);
  return BluetoothUnavailableException(bluetoothProblemFrom(message), message);
}

String _string(Array<Char> chars, int length) {
  final bytes = <int>[];
  for (var i = 0; i < length; i++) {
    final c = chars[i];
    if (c == 0) break;
    bytes.add(c & 0xff);
  }
  return String.fromCharCodes(bytes);
}

/// Reads the scanner's device list; each entry keeps its raw `SensorInfo`
/// index so the caller can create the sensor from it.
List<(DeviceInfo, int)> _readSensors(
  NeuroSdk2Bindings sdk,
  Pointer<SensorScanner> scanner,
) {
  const capacity = 32;
  return using((arena) {
    final infos = arena<SensorInfo>(capacity);
    final size = arena<Int32>()..value = capacity;
    final status = arena<OpStatus>();
    if (sdk.sensorsScanner(scanner, infos, size, status) == 0) return [];
    return [
      for (var i = 0; i < size.value && i < capacity; i++)
        if (SensorFamilyCode.toFamily(infos[i].SensFamily) case final family?)
          (
            DeviceInfo(
              name: _string(infos[i].Name, 256),
              serialNumber: _string(infos[i].SerialNumber, 128),
              address: _string(infos[i].Address, 128),
              family: family,
              model: infos[i].SensModel,
            ),
            i,
          ),
    ];
  });
}

/// Runs on a helper isolate: waits up to 10 s for [address] to show up in
/// the scan, then creates (and thereby connects) the sensor.
int _createSensor(int scannerAddress, String address) {
  final sdk = NeuroSdkLibrary.open(required: const []);
  final scanner = Pointer<SensorScanner>.fromAddress(scannerAddress);
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (true) {
    final index = _sensorIndex(sdk, scanner, address);
    if (index != null) {
      return using((arena) {
        const capacity = 32;
        final infos = arena<SensorInfo>(capacity);
        final size = arena<Int32>()..value = capacity;
        final status = arena<OpStatus>();
        sdk.sensorsScanner(scanner, infos, size, status);
        final sensor = sdk.createSensor(scanner, infos[index], status);
        if (sensor == nullptr || status.ref.Success == 0) {
          throw StateError(
            'Could not connect: ${_string(status.ref.ErrorMsg, 512)}',
          );
        }
        return sensor.address;
      });
    }
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Headband $address not found');
    }
    sleep(const Duration(milliseconds: 250));
  }
}

int? _sensorIndex(
  NeuroSdk2Bindings sdk,
  Pointer<SensorScanner> scanner,
  String address,
) {
  for (final (device, index) in _readSensors(sdk, scanner)) {
    if (device.address == address) return index;
  }
  return null;
}

void _connect(int sensor) => using((arena) {
  final status = arena<OpStatus>();
  final sdk = NeuroSdkLibrary.open(required: const []);
  if (sdk.connectSensor(Pointer.fromAddress(sensor), status) == 0) {
    throw StateError('Reconnect failed: ${_string(status.ref.ErrorMsg, 512)}');
  }
});

void _disconnect(int sensor) => using((arena) {
  NeuroSdkLibrary.open(required: const [])
      .disconnectSensor(Pointer.fromAddress(sensor), arena<OpStatus>());
});

typedef _BatteryCallback = Void Function(Pointer<Sensor>, Int32, Pointer<Void>);
typedef _StateCallback = Void Function(Pointer<Sensor>, Int8, Pointer<Void>);

class _FfiSensor implements NeuroSensor {
  _FfiSensor(this._sdk, this._ptr, this.family) {
    _batteryCallable = NativeCallable<_BatteryCallback>.listener(
      (Pointer<Sensor> _, int percent, Pointer<Void> _) =>
          _battery.add(percent),
    );
    // SensorState: 0 = in range, 1 = out of range.
    _stateCallable = NativeCallable<_StateCallback>.listener(
      (Pointer<Sensor> _, int state, Pointer<Void> _) =>
          _inRange.add(state == 0),
    );
    _signalCallable = NativeCallable<ShimListener>.listener(
      (Pointer<Double> data, int count) => _signal.add(_take(data, count)),
    );
    _resistCallable = NativeCallable<ShimListener>.listener(
      (Pointer<Double> data, int count) => _resistance.add(_take(data, count)),
    );
    _register();
    _samplingRate = _readSamplingRate();
  }

  final NeuroSdk2Bindings _sdk;
  final Pointer<Sensor> _ptr;
  @override
  final HeadbandFamily family;

  late final NativeCallable<_BatteryCallback> _batteryCallable;
  late final NativeCallable<_StateCallback> _stateCallable;
  late final NativeCallable<ShimListener> _signalCallable;
  late final NativeCallable<ShimListener> _resistCallable;

  final _batteryHandle = calloc<Pointer<Void>>();
  final _stateHandle = calloc<Pointer<Void>>();
  final _signalHandle = calloc<Pointer<Void>>();
  final _resistHandle = calloc<Pointer<Void>>();

  final _battery = StreamController<int>.broadcast();
  final _inRange = StreamController<bool>.broadcast();
  final _signal = StreamController<Float64List>.broadcast();
  final _resistance = StreamController<Float64List>.broadcast();
  late final int _samplingRate;
  bool _disposed = false;

  static Float64List _take(Pointer<Double> data, int count) {
    final copy = Float64List.fromList(data.asTypedList(count));
    fmFree(data);
    return copy;
  }

  void _register() => using((arena) {
    final status = arena<OpStatus>();
    _sdk
      ..addBatteryCallback(
        _ptr,
        _batteryCallable.nativeFunction,
        _batteryHandle,
        nullptr,
        status,
      )
      ..addConnectionStateCallback(
        _ptr,
        _stateCallable.nativeFunction,
        _stateHandle,
        nullptr,
        status,
      );
    final signalUser = _signalCallable.nativeFunction.cast<Void>();
    final resistUser = _resistCallable.nativeFunction.cast<Void>();
    switch (family) {
      case HeadbandFamily.headband:
        _sdk
          ..addSignalDataCallbackHeadband(
            _ptr,
            fmHeadbandSignal,
            _signalHandle,
            signalUser,
            status,
          )
          ..addResistCallbackHeadband(
            _ptr,
            fmHeadbandResist,
            _resistHandle,
            resistUser,
            status,
          );
      case HeadbandFamily.brainBit:
        _sdk
          ..addSignalDataCallbackBrainBit(
            _ptr,
            fmBrainBitSignal,
            _signalHandle,
            signalUser,
            status,
          )
          ..addResistCallbackBrainBit(
            _ptr,
            fmBrainBitResist,
            _resistHandle,
            resistUser,
            status,
          );
      case HeadbandFamily.brainBit2:
        _sdk
          ..addSignalCallbackBrainBit2(
            _ptr,
            fmBrainBit2Signal,
            _signalHandle,
            signalUser,
            status,
          )
          ..addResistCallbackBrainBit2(
            _ptr,
            fmBrainBit2Resist,
            _resistHandle,
            resistUser,
            status,
          );
      case HeadbandFamily.simulated:
        throw ArgumentError('Simulated devices have no native sensor');
    }
  });

  void _unregister() {
    _sdk
      ..removeBatteryCallback(_batteryHandle.value)
      ..removeConnectionStateCallback(_stateHandle.value);
    switch (family) {
      case HeadbandFamily.headband:
        _sdk
          ..removeSignalDataCallbackHeadband(_signalHandle.value)
          ..removeResistCallbackHeadband(_resistHandle.value);
      case HeadbandFamily.brainBit:
        _sdk
          ..removeSignalDataCallbackBrainBit(_signalHandle.value)
          ..removeResistCallbackBrainBit(_resistHandle.value);
      case HeadbandFamily.brainBit2:
        _sdk
          ..removeSignalCallbackBrainBit2(_signalHandle.value)
          ..removeResistCallbackBrainBit2(_resistHandle.value);
      case HeadbandFamily.simulated:
        break;
    }
  }

  int _readSamplingRate() => using((arena) {
    final code = arena<Uint8>();
    if (_sdk.readSamplingFrequencySensor(_ptr, code, arena<OpStatus>()) == 0) {
      return 250;
    }
    return switch (code.value) {
      SensorSamplingFrequency.FrequencyHz100 => 100,
      SensorSamplingFrequency.FrequencyHz125 => 125,
      SensorSamplingFrequency.FrequencyHz250 => 250,
      SensorSamplingFrequency.FrequencyHz500 => 500,
      SensorSamplingFrequency.FrequencyHz1000 => 1000,
      _ => 250,
    };
  });

  @override
  int get samplingRate => _samplingRate;

  @override
  Stream<bool> get inRange => _inRange.stream;

  @override
  Stream<int> get battery => _battery.stream;

  @override
  Stream<Float64List> get signal => _signal.stream;

  @override
  Stream<Float64List> get resistance => _resistance.stream;

  @override
  void execute(SensorCommandKind command) => using(
    (arena) => _sdk.execCommandSensor(_ptr, command.code, arena<OpStatus>()),
  );

  @override
  Future<void> reconnect() {
    final sensor = _ptr.address;
    return Isolate.run(() => _connect(sensor));
  }

  @override
  Future<void> disconnect() {
    final sensor = _ptr.address;
    return Isolate.run(() => _disconnect(sensor));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister();
    _sdk.freeSensor(_ptr);
    for (final c in [
      _batteryCallable,
      _stateCallable,
      _signalCallable,
      _resistCallable,
    ]) {
      c.close();
    }
    for (final h in [
      _batteryHandle,
      _stateHandle,
      _signalHandle,
      _resistHandle,
    ]) {
      calloc.free(h);
    }
    unawaited(_battery.close());
    unawaited(_inRange.close());
    unawaited(_signal.close());
    unawaited(_resistance.close());
  }
}
