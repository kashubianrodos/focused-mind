import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';

import '../headband/models.dart';

/// On-disk raw EEG format (design D6): little-endian float32 records of
/// seconds since tracking start, then O1, O2, T3 and T4 in volts.
abstract final class RawSignalFormat {
  static const valuesPerRecord = 5;
  static const bytesPerRecord = valuesPerRecord * 4;
}

/// Where a [RawSignalRecorder] writes its records.
abstract interface class RawSampleSink {
  /// Appends whole records; throws on a write error.
  void write(Float32List records);

  /// Bytes written so far.
  int get length;

  void close();
}

/// Appends records to a file with synchronous writes, about 5 KB once per
/// second, which also keeps it usable under fake time in tests.
class FileRawSampleSink implements RawSampleSink {
  FileRawSampleSink(this.file);

  final File file;
  RandomAccessFile? _raf;
  int _length = 0;

  @override
  void write(Float32List records) {
    final raf = _raf ??= file.openSync(mode: FileMode.writeOnly);
    final bytes = records.buffer.asUint8List(
      records.offsetInBytes,
      records.lengthInBytes,
    );
    raf.writeFromSync(_littleEndian(bytes));
    _length += bytes.length;
  }

  @override
  int get length => _length;

  @override
  void close() {
    _raf?.closeSync();
    _raf = null;
  }
}

Uint8List _littleEndian(Uint8List bytes) {
  if (Endian.host == Endian.little) return bytes;
  final out = Uint8List.fromList(bytes);
  for (var i = 0; i < out.length; i += 4) {
    final b = out.sublist(i, i + 4);
    out.setRange(i, i + 4, b.reversed);
  }
  return out;
}

/// Reads a raw recording back as batches of records, for export.
Stream<Float32List> readRawRecords(
  File file, {
  int recordsPerBatch = 2500,
}) async* {
  final raf = await file.open();
  try {
    final batchBytes = recordsPerBatch * RawSignalFormat.bytesPerRecord;
    while (true) {
      final bytes = await raf.read(batchBytes);
      final whole =
          bytes.length - bytes.length % RawSignalFormat.bytesPerRecord;
      if (whole == 0) break;
      final data = ByteData.sublistView(bytes, 0, whole);
      yield Float32List.fromList([
        for (var i = 0; i < whole; i += 4) data.getFloat32(i, Endian.little),
      ]);
      if (bytes.length < batchBytes) break;
    }
  } finally {
    await raf.close();
  }
}

/// Records a session's raw EEG while tracking (session-export spec, design
/// D6). Samples are timestamped from a counter at [samplingRate], anchored
/// to wall time at the start and again after each gap, so gaps show as
/// jumps. A write error stops recording but never the session.
class RawSignalRecorder {
  RawSignalRecorder({
    required this.sink,
    required this.samplingRate,
    this.flushInterval = const Duration(seconds: 1),
    this.onError,
  });

  final RawSampleSink sink;
  final int samplingRate;
  final Duration flushInterval;
  final void Function(Object error)? onError;

  StreamSubscription<List<EegSample>>? _sub;
  Timer? _flush;
  late DateTime _start;
  double _anchor = 0;
  int _count = 0;
  bool _reanchor = false;
  bool _failed = false;
  final _pending = <double>[];

  bool get failed => _failed;

  /// Whether any samples reached the sink.
  bool get hasData => sink.length > 0;

  void start(Stream<List<EegSample>> samples) {
    _start = clock.now();
    _sub = samples.listen(_onSamples);
    _flush = Timer.periodic(flushInterval, (_) => _writePending());
  }

  /// The headband dropped: the next sample is re-anchored to wall time.
  void gap() => _reanchor = true;

  void _onSamples(List<EegSample> batch) {
    if (_failed) return;
    if (_reanchor) {
      _reanchor = false;
      _anchor = clock.now().difference(_start).inMicroseconds / 1e6;
      _count = 0;
    }
    for (final s in batch) {
      _pending
        ..add(_anchor + _count++ / samplingRate)
        ..add(s.o1)
        ..add(s.o2)
        ..add(s.t3)
        ..add(s.t4);
    }
  }

  void _writePending() {
    if (_failed || _pending.isEmpty) return;
    try {
      sink.write(Float32List.fromList(_pending));
      _pending.clear();
    } on Object catch (e) {
      _failed = true;
      _pending.clear();
      _stop();
      onError?.call(e);
    }
  }

  void _stop() {
    unawaited(_sub?.cancel());
    _sub = null;
    _flush?.cancel();
    _flush = null;
  }

  /// Writes what is left and closes the sink.
  void close() {
    _writePending();
    _stop();
    try {
      sink.close();
    } on Object catch (e) {
      onError?.call(e);
    }
  }
}
