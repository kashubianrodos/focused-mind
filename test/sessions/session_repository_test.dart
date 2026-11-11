import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/sessions/session_models.dart';
import 'package:focused_mind/sessions/session_recorder.dart';
import 'package:focused_mind/sessions/session_repository.dart';

void main() {
  late Directory temp;
  late SessionRepository repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sessions_test');
    repo = SessionRepository(Directory('${temp.path}/sessions'));
  });

  tearDown(() => temp.delete(recursive: true));

  SessionRecord session(String id, DateTime startedAt) {
    final r =
        SessionRecorder(
            id: id,
            startedAt: startedAt,
            plannedDuration: const Duration(minutes: 50),
            mode: FeedbackMode.continuous,
          )
          ..record(score: 72.345, state: FocusState.focused)
          ..recordGap()
          ..record(score: null, state: FocusState.unavailable);
    return r.finish();
  }

  test('empty history when nothing was saved', () async {
    expect(await repo.list(), isEmpty);
  });

  test('round-trips summary and timeline', () async {
    final original = session('a', DateTime(2026, 11, 11, 9, 30));
    await repo.save(original);

    final loaded = await repo.load('a');
    expect(loaded, isNotNull);
    final s = loaded!.summary;
    expect(s.id, 'a');
    expect(s.startedAt, DateTime(2026, 11, 11, 9, 30));
    expect(s.duration, original.summary.duration);
    expect(s.plannedDuration, const Duration(minutes: 50));
    expect(s.averageScore, original.summary.averageScore);
    expect(s.timeIn(FocusState.focused), const Duration(seconds: 1));
    expect(s.mode, FeedbackMode.continuous);

    expect(loaded.timeline, hasLength(3));
    expect(loaded.timeline[0].score, 72.3);
    expect(loaded.timeline[1].gap, isTrue);
    expect(loaded.timeline[2].score, isNull);
    expect(loaded.marks.map((m) => m.kind), [
      MarkKind.gapStart,
      MarkKind.gapEnd,
    ]);
  });

  test('lists newest first', () async {
    await repo.save(session('old', DateTime(2026, 11, 1)));
    await repo.save(session('new', DateTime(2026, 11, 10)));
    await repo.save(session('mid', DateTime(2026, 11, 5)));
    expect((await repo.list()).map((s) => s.id), ['new', 'mid', 'old']);
  });

  test('delete removes the session from the list and the device', () async {
    await repo.save(session('a', DateTime(2026, 11, 1)));
    await repo.save(session('b', DateTime(2026, 11, 2)));
    await repo.delete('a');
    expect((await repo.list()).map((s) => s.id), ['b']);
    expect(await repo.load('a'), isNull);
    final files = repo.directory.listSync().map((f) => f.path).toList();
    expect(files.where((f) => f.contains('/a.')), isEmpty);
  });

  test('a corrupt summary file is skipped', () async {
    await repo.save(session('ok', DateTime(2026, 11, 1)));
    await File('${repo.directory.path}/bad.summary.json').writeAsString('{');
    expect((await repo.list()).map((s) => s.id), ['ok']);
  });
}
