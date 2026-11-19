import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/headband/headband_connection.dart';
import 'package:focused_mind/headband/models.dart';
import 'package:focused_mind/headband/multi_headband_source.dart';
import 'package:focused_mind/headband/simulated_headband_source.dart';

import '../support/fake_headband_source.dart';

void main() {
  test('real headbands are listed before the simulator', () {
    fakeAsync((async) {
      final real = FakeHeadbandSource();
      final simulator = SimulatedHeadbandSource();
      final multi = MultiHeadbandSource({
        real: {HeadbandFamily.headband},
        simulator: {HeadbandFamily.simulated},
      });
      final seen = <List<DeviceInfo>>[];
      multi.scan().listen(seen.add);
      // The simulator answers first.
      async.elapse(const Duration(seconds: 1));
      expect(seen.last.map((d) => d.family), [HeadbandFamily.simulated]);
      real.scanController.add([testDevice]);
      async.flushMicrotasks();
      expect(seen.last.map((d) => d.family), [
        HeadbandFamily.headband,
        HeadbandFamily.simulated,
      ]);
    });
  });

  test('the simulator is listed when Bluetooth is unavailable', () {
    fakeAsync((async) {
      final real = FakeHeadbandSource();
      final connection = HeadbandConnection(
        MultiHeadbandSource({
          real: {HeadbandFamily.headband},
          SimulatedHeadbandSource(): {HeadbandFamily.simulated},
        }),
      );
      final seen = <List<DeviceInfo>>[];
      Object? error;
      var done = false;
      connection.scan().listen(
        seen.add,
        onError: (Object e) => error = e,
        onDone: () => done = true,
      );
      async.flushMicrotasks();
      real.scanController.addError(
        const BluetoothUnavailableException(BluetoothProblem.poweredOff),
      );
      async.elapse(const Duration(seconds: 1));
      expect(error, isA<BluetoothUnavailableException>());
      expect(done, isFalse);
      expect(seen.last.single.family, HeadbandFamily.simulated);
      async.elapse(const Duration(seconds: 15));
      expect(done, isTrue);
    });
  });
}
