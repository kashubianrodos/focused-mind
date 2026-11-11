import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/drop_tracker.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/focus/rhythms.dart';
import 'package:focused_mind/sessions/raw_signal.dart';
import 'package:focused_mind/sessions/session_csv.dart';
import 'package:focused_mind/sessions/session_models.dart';
import 'package:focused_mind/sessions/session_recorder.dart';

List<List<String>> parse(String csv) {
  expect(csv.endsWith('\r\n'), isTrue);
  return [
    for (final line in csv.split('\r\n').where((l) => l.isNotEmpty))
      line.split(','),
  ];
}

void main() {
  group('raw signal', rawTests);
  final shares = RhythmShares.normalized(20, 30, 50);

  SessionRecord scripted() {
    final r = SessionRecorder(id: 's', startedAt: DateTime(2026, 11, 11, 9));
    final tracker = DropTracker();
    var t = 0;
    void second(double? score, FocusState state) {
      final event = tracker.update(state, Duration(seconds: t++));
      r.record(score: score, state: state, event: event, rhythms: shares);
    }

    for (var i = 0; i < 3; i++) {
      second(70, FocusState.focused);
    }
    for (var i = 0; i < 6; i++) {
      second(20, FocusState.distracted); // drop after 5 s
    }
    r
      ..recordGap()
      ..recordGap();
    t += 2;
    second(null, FocusState.unavailable);
    for (var i = 0; i < 4; i++) {
      second(80, FocusState.focused); // recovery after 3 s
    }
    return r.finish();
  }

  test('header plus one row per second with the expected cells', () {
    final record = scripted();
    final rows = parse(SessionCsv.timeline(record));
    expect(rows.first, SessionCsv.timelineHeader);
    expect(rows, hasLength(record.timeline.length + 1));
    expect(rows.skip(1).every((r) => r.length == 11), isTrue);

    expect(rows[1], [
      '0',
      '2026-11-11T09:00:00',
      '70.0',
      'focused',
      'concentration',
      '20.0',
      '30.0',
      '50.0',
      '0',
      'alert',
      '',
    ]);
    final drop = rows.indexWhere((r) => r.last == 'drop');
    expect(rows[drop][0], '8');
    final gap = rows.firstWhere((r) => r.last == 'gap_start');
    expect(gap[8], '1');
    expect(gap[2], '', reason: 'no score during a gap');
    // The unavailable second right after the gap: gap end, empty values.
    final afterGap = rows.firstWhere((r) => r.last == 'gap_end');
    expect(afterGap.sublist(2, 8), ['', 'unavailable', '', '', '', '']);
    expect(rows.any((r) => r.last == 'recovery'), isTrue);
  });

  test('a pre-change session has the same columns with empty new cells', () {
    final summary = SessionSummary.fromJson({
      'id': 'old',
      'startedAt': '2026-11-01T10:00:00.000',
      'durationSeconds': 1,
      'plannedSeconds': null,
      'averageScore': 48.0,
      'timeInState': {'neutral': 1},
      'drops': 0,
      'recoveries': 0,
      'longestFocusedSeconds': 0,
      'mode': 'continuous',
    });
    final record = SessionRecord(
      summary: summary,
      timeline: [
        TimelinePoint.fromJson({
          's': 0,
          'v': 48.0,
          'st': 'neutral',
          'm': 'continuous',
        }),
      ],
      marks: const [],
    );
    final rows = parse(SessionCsv.timeline(record));
    expect(rows[1], [
      '0',
      '2026-11-01T10:00:00',
      '48.0',
      'neutral',
      '',
      '',
      '',
      '',
      '0',
      'continuous',
      '',
    ]);
  });

  test('cells with commas or quotes are quoted', () {
    expect(SessionCsv.row(['a', 'b,c', 'd"e']), 'a,"b,c","d""e"\r\n');
  });
}

void rawTests() {
  test('raw CSV round trip in microvolts, including a gap', () async {
    final dir = await Directory.systemTemp.createTemp('fm_csv');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/s.raw.bin');
    // Two samples, then a jump to t = 25 s after a gap.
    FileRawSampleSink(file)
      ..write(
        Float32List.fromList([
          0, 10e-6, -20e-6, 30e-6, 40e-6, //
          0.004, 11e-6, -21e-6, 31e-6, 41e-6, //
          25, 12e-6, -22e-6, 32e-6, 42e-6,
        ]),
      )
      ..close();
    final csvFile = File('${dir.path}/out.csv');
    final sink = csvFile.openWrite();
    await SessionCsv.rawSignal(file, sink);
    await sink.close();
    final rows = parse(await csvFile.readAsString());
    expect(rows.first, SessionCsv.rawHeader);
    expect(rows, hasLength(4));
    expect(rows[1], ['0.0000', '10.000', '-20.000', '30.000', '40.000']);
    expect(rows[2][0], '0.0040');
    expect(rows[3][0], '25.0000');
    expect(double.parse(rows[3][4]), closeTo(42, 0.001));
  });
}
