import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/sessions/export_service.dart';
import 'package:focused_mind/sessions/session_recorder.dart';
import 'package:focused_mind/sessions/session_repository.dart';

void main() {
  late Directory store;
  late Directory out;
  late SessionRepository repo;

  setUp(() async {
    store = await Directory.systemTemp.createTemp('fm_store');
    out = await Directory.systemTemp.createTemp('fm_out');
    repo = SessionRepository(store);
  });
  tearDown(() async {
    await store.delete(recursive: true);
    if (out.existsSync()) await out.delete(recursive: true);
  });

  Future<String> saveSession({bool raw = false, int seconds = 1500}) async {
    final r = SessionRecorder(
      id: 's1',
      startedAt: DateTime(2026, 11, 11, 9, 5),
    );
    for (var i = 0; i < seconds; i++) {
      r.record(
        score: 60,
        state: FocusState.neutral,
        rhythms: RhythmShares.normalized(30, 40, 30),
      );
    }
    if (raw) {
      repo.openRawRecording('s1')
        ..write(Float32List.fromList([0, 1e-6, 2e-6, 3e-6, 4e-6]))
        ..close();
    }
    await repo.save(r.finish(hasRawRecording: raw));
    return 's1';
  }

  ExportService service({String? folder}) =>
      ExportService(repo, pickFolder: () async => folder);

  test('a 25-minute session exports 1,500 rows, named by its start', () async {
    final id = await saveSession();
    final result = await service(folder: out.path).export(id);
    expect(result, isA<ExportSaved>());
    final saved = result as ExportSaved;
    expect(saved.files, ['focused-mind_2026-11-11_09-05.csv']);
    final lines = File('${out.path}/${saved.files.single}')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty);
    expect(lines.length, 1 + 1500);
  });

  test('never overwrites: a taken name gets _2', () async {
    final id = await saveSession(seconds: 5);
    File('${out.path}/focused-mind_2026-11-11_09-05.csv')
        .writeAsStringSync('x');
    final saved = await service(folder: out.path).export(id) as ExportSaved;
    expect(saved.files, ['focused-mind_2026-11-11_09-05_2.csv']);
    expect(
      File('${out.path}/focused-mind_2026-11-11_09-05.csv').readAsStringSync(),
      'x',
    );
  });

  test('a session with a raw recording exports both files', () async {
    final id = await saveSession(raw: true, seconds: 5);
    final saved = await service(folder: out.path).export(id) as ExportSaved;
    expect(saved.files, [
      'focused-mind_2026-11-11_09-05.csv',
      'focused-mind_2026-11-11_09-05_raw.csv',
    ]);
    final raw = File('${out.path}/${saved.files.last}').readAsLinesSync();
    expect(raw.first, 't_s,o1_uv,o2_uv,t3_uv,t4_uv');
    expect(raw[1], '0.0000,1.000,2.000,3.000,4.000');
  });

  test('cancelling the picker writes nothing', () async {
    final id = await saveSession(seconds: 5);
    final result = await service().export(id);
    expect(result, isA<ExportCancelled>());
    expect(out.listSync(), isEmpty);
  });

  test('an unwritable folder gives a failure', () async {
    final id = await saveSession(seconds: 5);
    final result = await service(folder: '${out.path}/missing/deeper')
        .export(id);
    expect(result, isA<ExportFailed>());
    expect((result as ExportFailed).message, isNotEmpty);
  });
}
