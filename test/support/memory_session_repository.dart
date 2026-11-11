import 'dart:io';
import 'dart:typed_data';

import 'package:focused_mind/sessions/raw_signal.dart';

import 'package:focused_mind/sessions/session_models.dart';
import 'package:focused_mind/sessions/session_repository.dart';

/// Keeps sessions in memory; file I/O does not complete under fakeAsync.
class MemorySessionRepository extends SessionRepository {
  MemorySessionRepository() : super(Directory('/nonexistent'));

  final saved = <String, SessionRecord>{};
  final raw = <String, MemoryRawSink>{};

  @override
  Future<void> save(SessionRecord record) async =>
      saved[record.summary.id] = record;

  @override
  Future<List<SessionSummary>> list() async {
    final all = saved.values.map((r) => r.summary).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all;
  }

  @override
  Future<SessionRecord?> load(String id) async => saved[id];

  @override
  RawSampleSink openRawRecording(String id) => raw[id] = MemoryRawSink();

  @override
  Future<void> delete(String id) async {
    saved.remove(id);
    raw.remove(id);
  }
}

/// Collects raw records in memory; [failWrites] simulates a full disk.
class MemoryRawSink implements RawSampleSink {
  final records = <double>[];
  bool failWrites = false;
  bool closed = false;

  @override
  void write(Float32List data) {
    if (failWrites) throw const FileSystemException('No space left');
    records.addAll(data);
  }

  @override
  int get length => records.length * 4;

  @override
  void close() => closed = true;
}
