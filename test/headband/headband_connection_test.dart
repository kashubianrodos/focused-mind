import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/headband/headband_connection.dart';
import 'package:focused_mind/headband/headband_source.dart';
import 'package:focused_mind/headband/models.dart';

import '../support/fake_headband_source.dart';

void main() {
  late FakeHeadbandSource source;
  late HeadbandConnection connection;

  // Created inside each fakeAsync zone so stream deliveries and timers run
  // on the fake clock.
  void create() {
    source = FakeHeadbandSource();
    connection = HeadbandConnection(source);
  }

  void connectNow(FakeAsync async) {
    connection.connect(testDevice);
    async.flushMicrotasks();
    expect(connection.state.value, HeadbandConnectionState.connected);
  }

  group('scan', () {
    test('emits devices and stops after 15 s', () {
      fakeAsync((async) {
        create();
        final seen = <List<DeviceInfo>>[];
        var done = false;
        connection.scan().listen(seen.add, onDone: () => done = true);
        async.flushMicrotasks();
        source.scanController.add([testDevice]);
        async.elapse(const Duration(seconds: 14));
        expect(done, isFalse);
        expect(seen.last, [testDevice]);
        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
        expect(source.scanStopped, isTrue);
      });
    });

    test('Bluetooth problems surface as stream errors', () {
      fakeAsync((async) {
        create();
        Object? error;
        connection.scan().listen((_) {}, onError: (Object e) => error = e);
        async.flushMicrotasks();
        source.scanController.addError(
          const BluetoothUnavailableException(
            BluetoothProblem.permissionDenied,
          ),
        );
        async.flushMicrotasks();
        expect(error, isA<BluetoothUnavailableException>());
        expect(
          (error! as BluetoothUnavailableException).guidance,
          contains('Privacy & Security'),
        );
      });
    });
  });

  group('connect', () {
    test('successful connection reports connected', () {
      fakeAsync((async) {
        create();
        final states = <HeadbandConnectionState>[];
        connection.state.addListener(() => states.add(connection.state.value));
        connectNow(async);
        expect(states, [
          HeadbandConnectionState.connecting,
          HeadbandConnectionState.connected,
        ]);
        expect(connection.device, testDevice);
      });
    });

    test('times out after 60 s and reports disconnected', () {
      fakeAsync((async) {
        create();
        source.onConnect = null; // hangs
        Object? error;
        connection.connect(testDevice).catchError((Object e) {
          error = e;
        });
        async.elapse(const Duration(seconds: 59));
        expect(connection.state.value, HeadbandConnectionState.connecting);
        async.elapse(const Duration(seconds: 1));
        expect(error, isA<ConnectTimeoutException>());
        expect(connection.state.value, HeadbandConnectionState.disconnected);
      });
    });
  });

  group('automatic reconnection', () {
    test(
      'brief signal loss: reconnecting, then connected without user action',
      () {
        fakeAsync((async) {
          create();
          connectNow(async);
          connection.setMode(StreamMode.signal);
          async.flushMicrotasks();

          source.onConnect = () => Future.error(StateError('out of range'));
          source.linkController.add(false);
          async.flushMicrotasks();
          expect(connection.state.value, HeadbandConnectionState.reconnecting);

          async.elapse(const Duration(seconds: 20));
          expect(connection.state.value, HeadbandConnectionState.reconnecting);
          expect(source.connectAttempts, greaterThanOrEqualTo(4));

          source.onConnect = () async {};
          async.elapse(const Duration(seconds: 5));
          expect(connection.state.value, HeadbandConnectionState.connected);
          // The streaming mode is restored after reconnecting.
          expect(source.modes.last, StreamMode.signal);
        });
      },
    );

    test('retries every 5 s', () {
      fakeAsync((async) {
        create();
        connectNow(async);
        final before = source.connectAttempts;
        source.onConnect = () => Future.error(StateError('out of range'));
        source.linkController.add(false);
        async.elapse(const Duration(seconds: 30));
        // Immediate attempt plus one every 5 s.
        expect(source.connectAttempts - before, 7);
      });
    });

    test('headband gone: disconnected and notified after 60 s', () {
      fakeAsync((async) {
        create();
        connectNow(async);
        final events = <HeadbandEvent>[];
        connection.events.listen(events.add);
        source.onConnect = () => Future.error(StateError('out of range'));
        source.linkController.add(false);

        async.elapse(const Duration(seconds: 59));
        expect(connection.state.value, HeadbandConnectionState.reconnecting);
        async.elapse(const Duration(seconds: 1));
        expect(connection.state.value, HeadbandConnectionState.disconnected);
        expect(events, [HeadbandEvent.connectionLost]);

        // No further attempts after giving up.
        final attempts = source.connectAttempts;
        async.elapse(const Duration(seconds: 30));
        expect(source.connectAttempts, attempts);
      });
    });

    test('link loss while not connected is ignored', () {
      fakeAsync((async) {
        create();
        source.linkController.add(false);
        async.flushMicrotasks();
        expect(connection.state.value, HeadbandConnectionState.disconnected);
      });
    });
  });

  group('battery', () {
    test('warns once when the level reaches 15%', () {
      fakeAsync((async) {
        create();
        connectNow(async);
        final events = <HeadbandEvent>[];
        connection.events.listen(events.add);
        source.batteryController
          ..add(40)
          ..add(15)
          ..add(14);
        async.flushMicrotasks();
        expect(connection.battery.value, 14);
        expect(connection.isLowBattery, isTrue);
        expect(events, [HeadbandEvent.lowBattery]);
      });
    });
  });

  test(
    'contact reports are exposed and cleared when leaving resistance mode',
    () {
      fakeAsync((async) {
        create();
        connectNow(async);
        connection.setMode(StreamMode.resistance);
        source.resistanceController.add(
          ContactReport.fromOhms(
            o1: 1e5,
            o2: 1e5,
            t3: 1e5,
            t4: double.infinity,
          ),
        );
        async.flushMicrotasks();
        expect(connection.contact.value![Electrode.t4], ContactQuality.poor);
        connection.setMode(StreamMode.signal);
        async.flushMicrotasks();
        expect(connection.contact.value, isNull);
      });
    },
  );
}
