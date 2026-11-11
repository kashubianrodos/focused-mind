import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/sessions/session_recorder.dart';

import '../support/app_harness.dart';
import '../support/memory_session_repository.dart';

MemorySessionRepository repoWithSession({bool raw = false}) {
  final r = SessionRecorder(id: 's1', startedAt: DateTime(2026, 11, 11, 9, 5));
  for (var i = 0; i < 30; i++) {
    r.record(
      score: 60,
      state: FocusState.neutral,
      rhythms: RhythmShares.normalized(30, 40, 30),
    );
  }
  return MemorySessionRepository()
    ..saved['s1'] = r.finish(hasRawRecording: raw);
}

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('fm_export'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<void> openHistory(WidgetTester tester) async {
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapAndWait(WidgetTester tester, Finder button) async {
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  testWidgets('export writes the CSV and says where', (tester) async {
    final h = await pumpApp(
      tester,
      repository: repoWithSession(),
      pickExportFolder: () async => out.path,
    );
    await openHistory(tester);
    await tapAndWait(tester, find.byKey(const ValueKey('export-s1')));
    expect(find.byKey(const ValueKey('export-saved')), findsOneWidget);
    expect(find.textContaining(out.path), findsOneWidget);
    final files = out.listSync().map((e) => e.uri.pathSegments.last).toList();
    expect(files, ['focused-mind_2026-11-11_09-05.csv']);
    await shutDown(tester, h);
  });

  testWidgets('export from the session detail too', (tester) async {
    final h = await pumpApp(
      tester,
      repository: repoWithSession(),
      pickExportFolder: () async => out.path,
    );
    await openHistory(tester);
    await tester.tap(find.byKey(const ValueKey('history-s1')));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.byKey(const ValueKey('export-detail')));
    expect(find.byKey(const ValueKey('export-saved')), findsOneWidget);
    expect(out.listSync(), hasLength(1));
    await shutDown(tester, h);
  });

  testWidgets('cancelling the folder picker writes nothing', (tester) async {
    final h = await pumpApp(
      tester,
      repository: repoWithSession(),
      pickExportFolder: () async => null,
    );
    await openHistory(tester);
    await tapAndWait(tester, find.byKey(const ValueKey('export-s1')));
    expect(find.byType(SnackBar), findsNothing);
    expect(out.listSync(), isEmpty);
    await shutDown(tester, h);
  });

  testWidgets('a failed export shows an error', (tester) async {
    final h = await pumpApp(
      tester,
      repository: repoWithSession(),
      pickExportFolder: () async => '${out.path}/missing/deeper',
    );
    await openHistory(tester);
    await tapAndWait(tester, find.byKey(const ValueKey('export-s1')));
    expect(find.byKey(const ValueKey('export-failed')), findsOneWidget);
    expect(find.textContaining('Export failed'), findsOneWidget);
    await shutDown(tester, h);
  });

  testWidgets('sessions with a raw recording carry a badge', (tester) async {
    final h = await pumpApp(tester, repository: repoWithSession(raw: true));
    await openHistory(tester);
    expect(find.byKey(const ValueKey('raw-s1')), findsOneWidget);
    await shutDown(tester, h);
  });
}
