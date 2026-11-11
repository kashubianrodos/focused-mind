import 'dart:async';

import 'package:focused_mind/headband/headband_source.dart';
import 'package:focused_mind/headband/models.dart';

/// A [HeadbandSource] whose every outcome is set by the test.
class FakeHeadbandSource implements HeadbandSource {
  final linkController = StreamController<bool>.broadcast();
  final batteryController = StreamController<int>.broadcast();
  final resistanceController = StreamController<ContactReport>.broadcast();
  final signalController = StreamController<List<EegSample>>.broadcast();
  final scanController = StreamController<List<DeviceInfo>>();

  /// Completes each connect attempt; null means the attempt hangs.
  Future<void> Function()? onConnect = () async {};
  int connectAttempts = 0;
  int disconnects = 0;
  final modes = <StreamMode>[];
  bool scanStopped = false;

  @override
  Stream<List<DeviceInfo>> scan() => scanController.stream;

  @override
  Future<void> stopScan() async => scanStopped = true;

  @override
  Future<void> connect(DeviceInfo device) {
    connectAttempts++;
    final behaviour = onConnect;
    if (behaviour == null) return Completer<void>().future;
    return behaviour();
  }

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<void> setMode(StreamMode mode) async => modes.add(mode);

  @override
  Stream<bool> get linkChanges => linkController.stream;

  @override
  Stream<int> get battery => batteryController.stream;

  @override
  Stream<ContactReport> get resistance => resistanceController.stream;

  @override
  Stream<List<EegSample>> get signal => signalController.stream;

  @override
  int get samplingRate => 250;

  @override
  Future<void> dispose() async {}
}

const testDevice = DeviceInfo(
  name: 'Mindo',
  serialNumber: 'SN-1',
  address: 'AA:BB',
  family: HeadbandFamily.headband,
);
