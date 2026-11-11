import 'dart:ffi';

import 'neurosdk2_bindings.dart';

/// Bindings to `native/fm_shim.cpp`, built by `hook/build.dart` (design D3).
///
/// The `fm_*` callbacks are registered with neurosdk2 in place of Dart
/// callbacks. Each copies the SDK's batch into a malloc'd array of doubles
/// (O1, O2, T3, T4 per sample) and posts it to the [ShimListener] passed as
/// the SDK's `userData`. The listener owns the array and frees it with
/// [fmFree].
typedef ShimListener = Void Function(Pointer<Double> data, Int32 count);

typedef SamplesCallback<T extends NativeType> = Void Function(
  Pointer<Sensor>,
  Pointer<T>,
  Int32,
  Pointer<Void>,
);

@Native<SamplesCallback<HeadbandSignalData>>(symbol: 'fm_headband_signal')
external void _headbandSignal(
  Pointer<Sensor> sensor,
  Pointer<HeadbandSignalData> data,
  int size,
  Pointer<Void> user,
);

@Native<SamplesCallback<BrainBitSignalData>>(symbol: 'fm_brainbit_signal')
external void _brainBitSignal(
  Pointer<Sensor> sensor,
  Pointer<BrainBitSignalData> data,
  int size,
  Pointer<Void> user,
);

@Native<SamplesCallback<SignalChannelsData>>(symbol: 'fm_brainbit2_signal')
external void _brainBit2Signal(
  Pointer<Sensor> sensor,
  Pointer<SignalChannelsData> data,
  int size,
  Pointer<Void> user,
);

@Native<Void Function(Pointer<Sensor>, HeadbandResistData, Pointer<Void>)>(
  symbol: 'fm_headband_resist',
)
external void _headbandResist(
  Pointer<Sensor> sensor,
  HeadbandResistData data,
  Pointer<Void> user,
);

@Native<Void Function(Pointer<Sensor>, BrainBitResistData, Pointer<Void>)>(
  symbol: 'fm_brainbit_resist',
)
external void _brainBitResist(
  Pointer<Sensor> sensor,
  BrainBitResistData data,
  Pointer<Void> user,
);

@Native<SamplesCallback<ResistRefChannelsData>>(symbol: 'fm_brainbit2_resist')
external void _brainBit2Resist(
  Pointer<Sensor> sensor,
  Pointer<ResistRefChannelsData> data,
  int size,
  Pointer<Void> user,
);

/// Frees an array the shim posted to a [ShimListener].
@Native<Void Function(Pointer<Double>)>(symbol: 'fm_free')
external void fmFree(Pointer<Double> data);

Pointer<NativeFunction<SamplesCallback<HeadbandSignalData>>>
get fmHeadbandSignal => Native.addressOf(_headbandSignal);

Pointer<NativeFunction<SamplesCallback<BrainBitSignalData>>>
get fmBrainBitSignal => Native.addressOf(_brainBitSignal);

Pointer<NativeFunction<SamplesCallback<SignalChannelsData>>>
get fmBrainBit2Signal => Native.addressOf(_brainBit2Signal);

Pointer<
  NativeFunction<
    Void Function(Pointer<Sensor>, HeadbandResistData, Pointer<Void>)
  >
>
get fmHeadbandResist => Native.addressOf(_headbandResist);

Pointer<
  NativeFunction<
    Void Function(Pointer<Sensor>, BrainBitResistData, Pointer<Void>)
  >
>
get fmBrainBitResist => Native.addressOf(_brainBitResist);

Pointer<NativeFunction<SamplesCallback<ResistRefChannelsData>>>
get fmBrainBit2Resist => Native.addressOf(_brainBit2Resist);
