import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_controller.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/focus/focus_engine.dart';
import 'package:focused_mind/headband/headband_connection.dart';
import 'package:focused_mind/headband/simulated_headband_source.dart';
import 'package:focused_mind/sessions/raw_signal.dart';
import 'package:focused_mind/sessions/session_controller.dart';
import 'package:focused_mind/sessions/session_repository.dart';

import '../support/fake_audio_output.dart';
import '../support/fake_estimator.dart';
import '../support/memory_session_repository.dart';

class _Harness {
  _Harness({required bool recordRaw})
    : recordRawSetting = ValueNotifier(recordRaw) {
    connection = HeadbandConnection(sim);
    controller = SessionController(
      connection: connection,
      feedback: FeedbackController(FakeAudioOutput(), settings: settings.value),
      repository: repository,
      settings: settings,
      recordRaw: recordRawSetting,
      createEngine: () => FocusEngine(
        samples: connection.samples,
        createEstimator: FakeEstimator.new,
      ),
    );
  }

  final sim = SimulatedHeadbandSource();
  final repository = MemorySessionRepository();
  final settings = ValueNotifier(const FeedbackSettings());
  final ValueNotifier<bool> recordRawSetting;
  late final HeadbandConnection connection;
  late final SessionController controller;

  void startTracking(FakeAsync async) {
    connection.connect(SimulatedHeadbandSource.device);
    async.elapse(const Duration(seconds: 1));
    controller.start();
    async.elapse(const Duration(seconds: 5));
    expect(controller.phase.value, SessionPhase.running);
  }

  MemoryRawSink get sink => repository.raw.values.single;
}

void main() {
  test('setting off: no raw recording is made', () {
    fakeAsync((async) {
      final h = _Harness(recordRaw: false)..startTracking(async);
      async.elapse(const Duration(seconds: 5));
      h.controller.end();
      async.elapse(const Duration(seconds: 1));
      expect(h.repository.raw, isEmpty);
      expect(h.controller.lastRecord!.summary.hasRawRecording, isFalse);
    });
  });

  test('setting on: 250 records per second, closed and flagged at the end', () {
    fakeAsync((async) {
      final h = _Harness(recordRaw: true)..startTracking(async);
      final before = h.sink.records.length;
      async.elapse(const Duration(seconds: 4));
      final perSecond = (h.sink.records.length - before) / 4 / 5;
      expect(perSecond, 250);
      h.controller.end();
      async.elapse(const Duration(seconds: 1));
      expect(h.sink.closed, isTrue);
      expect(h.controller.lastRecord!.summary.hasRawRecording, isTrue);
      // Timestamps rise by 1/250 s.
      final r = h.sink.records;
      expect(r[5] - r[0], closeTo(1 / 250, 1e-6));
    });
  });

  test('timestamps jump across a 20 s gap', () {
    fakeAsync((async) {
      final h = _Harness(recordRaw: true)..startTracking(async);
      async.elapse(const Duration(seconds: 3));
      final beforeGap = h.sink.records.length;
      h.sim.dropLink(restoreAfter: const Duration(seconds: 20));
      async.elapse(const Duration(seconds: 30));
      expect(h.controller.phase.value, SessionPhase.running);
      async.elapse(const Duration(seconds: 2));
      final r = h.sink.records;
      final lastBefore = r[beforeGap - 5];
      final firstAfter = r[beforeGap];
      expect(firstAfter - lastBefore, greaterThan(15));
      h.controller.end();
      async.elapse(const Duration(seconds: 1));
    });
  });

  test('a write failure stops raw recording, not the session', () {
    fakeAsync((async) {
      final h = _Harness(recordRaw: true)..startTracking(async);
      h.sink.failWrites = true;
      async.elapse(const Duration(seconds: 3));
      expect(h.controller.rawRecordingError.value, contains('stopped'));
      expect(h.controller.phase.value, SessionPhase.running);
      h.controller.end();
      async.elapse(const Duration(seconds: 1));
      expect(h.controller.lastRecord, isNotNull);
    });
  });

  test('deleting a session removes its raw file', () async {
    final dir = await Directory.systemTemp.createTemp('fm_raw');
    addTearDown(() => dir.delete(recursive: true));
    final repo = SessionRepository(dir);
    final sink = repo.openRawRecording('s1')
      ..write(Float32List.fromList([0, 1e-6, 2e-6, 3e-6, 4e-6]))
      ..close();
    expect(sink.length, 20);
    expect(repo.rawFile('s1').existsSync(), isTrue);
    await repo.delete('s1');
    expect(repo.rawFile('s1').existsSync(), isFalse);
  });

  test('a raw file reads back as written', () async {
    final dir = await Directory.systemTemp.createTemp('fm_raw');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/x.raw.bin');
    final sink = FileRawSampleSink(file);
    final values = [for (var i = 0; i < 5 * 7; i++) i / 1000];
    sink
      ..write(Float32List.fromList(values.sublist(0, 20)))
      ..write(Float32List.fromList(values.sublist(20)))
      ..close();
    final back = [
      await for (final batch in readRawRecords(file, recordsPerBatch: 3))
        ...batch,
    ];
    expect(back, hasLength(values.length));
    for (var i = 0; i < values.length; i++) {
      expect(back[i], closeTo(values[i], 1e-6));
    }
  });
}
