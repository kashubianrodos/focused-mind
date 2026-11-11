import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/headband/ffi/fm_shim.dart';
import 'package:focused_mind/headband/ffi/neurosdk2_bindings.dart';

/// Calls the shim's callbacks the way neurosdk2 does and frees the SDK-side
/// buffer straight after each call, before the Dart listener runs: the
/// listener must still see the right values (design D3).
void main() {
  late List<List<double>> received;
  late NativeCallable<ShimListener> listener;
  late Completer<void> arrived;

  setUp(() {
    received = [];
    arrived = Completer();
    listener = NativeCallable<ShimListener>.listener((
      Pointer<Double> data,
      int count,
    ) {
      received.add(List.of(data.asTypedList(count)));
      fmFree(data);
      if (!arrived.isCompleted) arrived.complete();
    });
  });

  tearDown(() => listener.close());

  Pointer<Void> user() => listener.nativeFunction.cast();

  test(
    'Headband signal batches are copied before the SDK frees them',
    () async {
      final batch = calloc<HeadbandSignalData>(3);
      for (var i = 0; i < 3; i++) {
        batch[i]
          ..PackNum = i
          ..O1 = i + 0.1
          ..O2 = i + 0.2
          ..T3 = i + 0.3
          ..T4 = i + 0.4;
      }
      final call = fmHeadbandSignal
          .asFunction<
            void Function(
              Pointer<Sensor>,
              Pointer<HeadbandSignalData>,
              int,
              Pointer<Void>,
            )
          >();
      call(nullptr, batch, 3, user());
      // Overwrite, then free, as the SDK does once the callback returns.
      for (var i = 0; i < 3; i++) {
        batch[i].O1 = -1;
      }
      calloc.free(batch);

      await arrived.future;
      expect(received.single, [
        0.1, 0.2, 0.3, 0.4, //
        1.1, 1.2, 1.3, 1.4, //
        2.1, 2.2, 2.3, 2.4,
      ]);
    },
  );

  test('BrainBit signal uses the same layout', () async {
    final batch = calloc<BrainBitSignalData>(1);
    batch.ref
      ..O1 = 1
      ..O2 = 2
      ..T3 = 3
      ..T4 = 4;
    fmBrainBitSignal
        .asFunction<
          void Function(
            Pointer<Sensor>,
            Pointer<BrainBitSignalData>,
            int,
            Pointer<Void>,
          )
        >()(nullptr, batch, 1, user());
    calloc.free(batch);
    await arrived.future;
    expect(received.single, [1, 2, 3, 4]);
  });

  test(
    'Headband resistance passed by value arrives as four ohm values',
    () async {
      final data = calloc<HeadbandResistData>();
      data.ref
        ..O1 = 1e5
        ..O2 = 2e5
        ..T3 = 3e6
        ..T4 = double.infinity;
      fmHeadbandResist
          .asFunction<
            void Function(Pointer<Sensor>, HeadbandResistData, Pointer<Void>)
          >()(nullptr, data.ref, user());
      calloc.free(data);
      await arrived.future;
      expect(received.single, [1e5, 2e5, 3e6, double.infinity]);
    },
  );

  test('BrainBit 2 packs keep the first four channels, NaN if fewer', () async {
    final packs = calloc<SignalChannelsData>(2);
    final values = calloc<Double>(6);
    for (var i = 0; i < 6; i++) {
      values[i] = i.toDouble();
    }
    packs[0]
      ..SzSamples = 4
      ..Samples = values;
    packs[1]
      ..SzSamples = 2
      ..Samples = values + 4;
    fmBrainBit2Signal
        .asFunction<
          void Function(
            Pointer<Sensor>,
            Pointer<SignalChannelsData>,
            int,
            Pointer<Void>,
          )
        >()(nullptr, packs, 2, user());
    calloc
      ..free(values)
      ..free(packs);
    await arrived.future;
    final out = received.single;
    expect(out.sublist(0, 6), [0, 1, 2, 3, 4, 5]);
    expect(out[6].isNaN && out[7].isNaN, isTrue);
  });
}
