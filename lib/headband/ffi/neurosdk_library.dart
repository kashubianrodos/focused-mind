import 'dart:ffi';
import 'dart:io' show Platform;

import 'neurosdk2_bindings.dart';

/// The neurosdk2 library could not be used: not found, or a symbol the app
/// binds is missing (a different SDK version than the vendored headers).
class NeuroSdkLoadException implements Exception {
  const NeuroSdkLoadException(this.message);

  final String message;

  @override
  String toString() => 'NeuroSdkLoadException: $message';
}

/// Loads the neurosdk2 C library (`.dylib` on macOS, `.so` on Android, a
/// framework on iOS), which the `neurosdk2` plugin bundles into the app
/// (design D3), and checks every function the app binds before use.
abstract final class NeuroSdkLibrary {
  static final fileName = Platform.isAndroid
      ? 'libneurosdk2.so'
      : 'libneurosdk2.dylib';

  /// On iOS the plugin links the same C API as the `flutter_neurosdk2_ios`
  /// framework.
  static const iosFileName =
      'flutter_neurosdk2_ios.framework/flutter_neurosdk2_ios';

  /// Every function `ffigen.yaml` binds.
  static const symbols = [
    'createScanner',
    'freeScanner',
    'startScanner',
    'stopScanner',
    'sensorsScanner',
    'createSensor',
    'freeSensor',
    'connectSensor',
    'disconnectSensor',
    'execCommandSensor',
    'readStateSensor',
    'readBattPowerSensor',
    'readSamplingFrequencySensor',
    'addBatteryCallback',
    'removeBatteryCallback',
    'addConnectionStateCallback',
    'removeConnectionStateCallback',
    'addSignalDataCallbackHeadband',
    'removeSignalDataCallbackHeadband',
    'addResistCallbackHeadband',
    'removeResistCallbackHeadband',
    'addSignalDataCallbackBrainBit',
    'removeSignalDataCallbackBrainBit',
    'addResistCallbackBrainBit',
    'removeResistCallbackBrainBit',
    'readSupportedChannelsBrainBit2',
    'addSignalCallbackBrainBit2',
    'removeSignalCallbackBrainBit2',
    'addResistCallbackBrainBit2',
    'removeResistCallbackBrainBit2',
  ];

  static NeuroSdk2Bindings open({
    String? path,
    List<String> required = symbols,
  }) {
    path ??= Platform.isIOS ? iosFileName : fileName;
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(path);
    } on ArgumentError catch (e) {
      throw NeuroSdkLoadException('Could not load $path: ${e.message}');
    }
    final missing = [
      for (final s in required)
        if (!lib.providesSymbol(s)) s,
    ];
    if (missing.isNotEmpty) {
      throw NeuroSdkLoadException(
        '$path is missing ${missing.join(', ')}. The bundled neurosdk2 does '
        'not match the headers in third_party/neurosdk2.',
      );
    }
    return NeuroSdk2Bindings(lib);
  }
}
