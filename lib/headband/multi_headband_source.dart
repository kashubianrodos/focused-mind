import 'dart:async';

import 'headband_source.dart';
import 'models.dart';

/// Presents several [HeadbandSource]s (the real SDK, the simulator) as one:
/// scans all of them and routes everything else to the one that owns the
/// connected device.
class MultiHeadbandSource implements HeadbandSource {
  MultiHeadbandSource(this.sources) {
    for (final s in sources.keys) {
      _subs.addAll([
        s.linkChanges.listen((v) {
          if (identical(s, _active)) _linkChanges.add(v);
        }),
        s.battery.listen((v) {
          if (identical(s, _active)) _battery.add(v);
        }),
        s.resistance.listen((v) {
          if (identical(s, _active)) _resistance.add(v);
        }),
        s.signal.listen((v) {
          if (identical(s, _active)) _signal.add(v);
        }),
      ]);
    }
  }

  /// Each source and the device families it handles.
  final Map<HeadbandSource, Set<HeadbandFamily>> sources;

  final _subs = <StreamSubscription<Object?>>[];
  final _linkChanges = StreamController<bool>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _resistance = StreamController<ContactReport>.broadcast();
  final _signal = StreamController<List<EegSample>>.broadcast();
  HeadbandSource? _active;

  HeadbandSource _sourceFor(DeviceInfo device) => sources.entries
      .firstWhere(
        (e) => e.value.contains(device.family),
        orElse: () => throw StateError('No source for ${device.family}'),
      )
      .key;

  @override
  Stream<List<DeviceInfo>> scan() {
    final latest = <HeadbandSource, List<DeviceInfo>>{};
    late final StreamController<List<DeviceInfo>> out;
    final subs = <StreamSubscription<List<DeviceInfo>>>[];
    var open = sources.length;
    out = StreamController<List<DeviceInfo>>(
      onListen: () {
        if (sources.isEmpty) {
          out.close();
          return;
        }
        for (final s in sources.keys) {
          subs.add(
            s.scan().listen(
              (devices) {
                latest[s] = devices;
                out.add([for (final l in latest.values) ...l]);
              },
              onError: out.addError,
              onDone: () {
                if (--open == 0) out.close();
              },
            ),
          );
        }
      },
      onCancel: () {
        for (final sub in subs) {
          unawaited(sub.cancel());
        }
      },
    );
    return out.stream;
  }

  @override
  Future<void> stopScan() async {
    for (final s in sources.keys) {
      await s.stopScan();
    }
  }

  @override
  Future<void> connect(DeviceInfo device) {
    final s = _sourceFor(device);
    _active = s;
    return s.connect(device);
  }

  @override
  Future<void> disconnect() async => _active?.disconnect();

  @override
  Future<void> setMode(StreamMode mode) async => _active?.setMode(mode);

  @override
  Stream<bool> get linkChanges => _linkChanges.stream;

  @override
  Stream<int> get battery => _battery.stream;

  @override
  Stream<ContactReport> get resistance => _resistance.stream;

  @override
  Stream<List<EegSample>> get signal => _signal.stream;

  @override
  int get samplingRate => _active?.samplingRate ?? 250;

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    for (final s in sources.keys) {
      await s.dispose();
    }
  }
}
