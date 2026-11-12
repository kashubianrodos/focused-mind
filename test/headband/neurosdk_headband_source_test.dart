import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/headband/headband_connection.dart';
import 'package:focused_mind/headband/headband_source.dart';
import 'package:focused_mind/headband/models.dart';
import 'package:focused_mind/headband/neurosdk_api.dart';
import 'package:focused_mind/headband/neurosdk_headband_source.dart';

class FakeSensor implements NeuroSensor {
  FakeSensor(this.family);

  @override
  final HeadbandFamily family;
  final commands = <SensorCommandKind>[];
  final inRangeCtl = StreamController<bool>.broadcast(sync: true);
  final batteryCtl = StreamController<int>.broadcast(sync: true);
  final signalCtl = StreamController<Float64List>.broadcast(sync: true);
  final resistCtl = StreamController<Float64List>.broadcast(sync: true);
  int reconnects = 0;
  bool reconnectFails = false;
  bool disconnected = false;
  bool disposed = false;

  @override
  int get samplingRate => 250;
  @override
  Stream<bool> get inRange => inRangeCtl.stream;
  @override
  Stream<int> get battery => batteryCtl.stream;
  @override
  Stream<Float64List> get signal => signalCtl.stream;
  @override
  Stream<Float64List> get resistance => resistCtl.stream;
  @override
  void execute(SensorCommandKind command) => commands.add(command);
  @override
  Future<void> reconnect() async {
    reconnects++;
    if (reconnectFails) throw StateError('out of range');
  }

  @override
  Future<void> disconnect() async => disconnected = true;
  @override
  void dispose() => disposed = true;
}

class FakeApi implements NeuroSdkApi {
  var devices = <DeviceInfo>[];
  BluetoothUnavailableException? scanError;
  bool scanning = false;
  bool disposed = false;
  Duration connectDelay = Duration.zero;
  final sensors = <FakeSensor>[];

  @override
  Future<void> startScan() async {
    if (scanError case final e?) throw e;
    scanning = true;
  }

  @override
  List<DeviceInfo> scannedDevices() => devices;
  @override
  void stopScan() => scanning = false;

  @override
  Future<NeuroSensor> connect(DeviceInfo device) async {
    await Future<void>.delayed(connectDelay);
    final s = FakeSensor(device.family);
    sensors.add(s);
    return s;
  }

  @override
  void dispose() => disposed = true;
}

const mindo = DeviceInfo(
  name: 'Mindo',
  serialNumber: '123',
  address: 'AA:BB',
  family: HeadbandFamily.headband,
);

void main() {
  late FakeApi api;
  var created = 0;
  NeuroSdkHeadbandSource source() => NeuroSdkHeadbandSource(() {
    created++;
    return api;
  });

  setUp(() {
    api = FakeApi();
    created = 0;
  });

  test('the SDK is only loaded on first use', () {
    final s = source();
    expect(created, 0);
    s.scan().listen((_) {});
    expect(created, 1);
  });

  test('scan polls the device list and stops the scanner on cancel', () {
    fakeAsync((async) {
      final s = source();
      final lists = <List<DeviceInfo>>[];
      final sub = s.scan().listen(lists.add);
      async.elapse(const Duration(seconds: 1));
      api.devices = [mindo];
      async.elapse(const Duration(seconds: 2));
      expect(lists, [
        <DeviceInfo>[],
        [mindo],
      ]);
      expect(api.scanning, isTrue);
      unawaited(sub.cancel());
      async.flushMicrotasks();
      expect(api.scanning, isFalse);
    });
  });

  test('Bluetooth errors surface as a scan error', () async {
    api.scanError = const BluetoothUnavailableException(
      BluetoothProblem.poweredOff,
    );
    await expectLater(
      source().scan(),
      emitsError(isA<BluetoothUnavailableException>()),
    );
  });

  test('scan errors from HeadbandConnection reach the UI unchanged', () {
    fakeAsync((async) {
      api.scanError = const BluetoothUnavailableException(
        BluetoothProblem.permissionDenied,
      );
      final connection = HeadbandConnection(source());
      Object? error;
      connection.scan().listen((_) {}, onError: (Object e) => error = e);
      async.elapse(const Duration(seconds: 1));
      expect(
        error,
        isA<BluetoothUnavailableException>().having(
          (e) => e.problem,
          'problem',
          BluetoothProblem.permissionDenied,
        ),
      );
      connection.dispose();
    });
  });

  test('modes map to start/stop commands; data is converted', () async {
    final s = source();
    await s.connect(mindo);
    final sensor = api.sensors.single;
    final contact = <ContactReport>[];
    final samples = <List<EegSample>>[];
    s.resistance.listen(contact.add);
    s.signal.listen(samples.add);

    await s.setMode(StreamMode.resistance);
    sensor.resistCtl.add(Float64List.fromList([1e5, 1e6, 5e6, 1e5]));
    await s.setMode(StreamMode.signal);
    sensor.signalCtl.add(Float64List.fromList([1, 2, 3, 4, 5, 6, 7, 8]));
    await s.setMode(StreamMode.idle);
    await Future<void>.delayed(Duration.zero);

    expect(sensor.commands, [
      SensorCommandKind.startResist,
      SensorCommandKind.stopResist,
      SensorCommandKind.startSignal,
      SensorCommandKind.stopSignal,
    ]);
    expect(contact.single[Electrode.o1], ContactQuality.good);
    expect(contact.single[Electrode.o2], ContactQuality.fair);
    expect(contact.single[Electrode.t3], ContactQuality.poor);
    expect(samples.single.map((e) => e.t4), [4, 8]);
  });

  test('battery and link changes are forwarded', () async {
    final s = source();
    await s.connect(mindo);
    final battery = <int>[];
    final link = <bool>[];
    s.battery.listen(battery.add);
    s.linkChanges.listen(link.add);
    api.sensors.single
      ..batteryCtl.add(42)
      ..inRangeCtl.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(battery, [42]);
    expect(link, [false]);
  });

  test('connecting again to the same device reconnects the sensor', () async {
    final s = source();
    await s.connect(mindo);
    await s.connect(mindo);
    expect(api.sensors, hasLength(1));
    expect(api.sensors.single.reconnects, 1);
  });

  test('brief link loss reconnects through HeadbandConnection', () {
    fakeAsync((async) {
      final s = source();
      final connection = HeadbandConnection(s);
      unawaited(connection.connect(mindo));
      async.elapse(const Duration(seconds: 1));
      expect(connection.state.value, HeadbandConnectionState.connected);
      final sensor = api.sensors.single;
      unawaited(connection.setMode(StreamMode.signal));
      async.flushMicrotasks();

      sensor.reconnectFails = true;
      sensor.inRangeCtl.add(false);
      async.elapse(const Duration(seconds: 1));
      expect(connection.state.value, HeadbandConnectionState.reconnecting);
      sensor.reconnectFails = false;
      async.elapse(const Duration(seconds: 6));
      expect(connection.state.value, HeadbandConnectionState.connected);
      expect(sensor.commands.last, SensorCommandKind.startSignal);
      connection.dispose();
    });
  });

  test('disconnect and dispose release the sensor and the SDK', () async {
    final s = source();
    await s.connect(mindo);
    await s.setMode(StreamMode.signal);
    await s.disconnect();
    final sensor = api.sensors.single;
    expect(sensor.commands.last, SensorCommandKind.stopSignal);
    expect(sensor.disconnected && sensor.disposed, isTrue);
    await s.dispose();
    expect(api.disposed, isTrue);
  });

  test('scanner messages map to Bluetooth guidance', () {
    expect(
      bluetoothProblemFrom('Bluetooth is unauthorized'),
      BluetoothProblem.permissionDenied,
    );
    expect(
      bluetoothProblemFrom('Bluetooth powered off'),
      BluetoothProblem.poweredOff,
    );
    expect(bluetoothProblemFrom('whatever'), BluetoothProblem.unavailable);
  });
}
