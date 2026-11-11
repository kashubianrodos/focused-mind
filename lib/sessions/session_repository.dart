import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'raw_signal.dart';
import 'session_models.dart';

/// Stores each session as two JSON files in the app support directory
/// (design D8): `<id>.summary.json` for the history list and
/// `<id>.timeline.json` for the graph, plus `<id>.raw.bin` when the raw
/// signal was recorded (design D6). Nothing leaves the device.
class SessionRepository {
  SessionRepository(this.directory);

  static Future<SessionRepository> open() async {
    final base = await getApplicationSupportDirectory();
    return SessionRepository(Directory(p.join(base.path, 'sessions')));
  }

  final Directory directory;

  File _summaryFile(String id) =>
      File(p.join(directory.path, '$id.summary.json'));
  File _timelineFile(String id) =>
      File(p.join(directory.path, '$id.timeline.json'));

  /// The raw EEG recording of session [id] (may not exist).
  File rawFile(String id) => File(p.join(directory.path, '$id.raw.bin'));

  /// Starts a raw EEG recording for session [id].
  RawSampleSink openRawRecording(String id) {
    directory.createSync(recursive: true);
    return FileRawSampleSink(rawFile(id));
  }

  Future<void> save(SessionRecord record) async {
    await directory.create(recursive: true);
    final id = record.summary.id;
    await _timelineFile(id).writeAsString(jsonEncode(record.timelineJson()));
    // Summary last: a session appears in history only once fully written.
    await _summaryFile(id).writeAsString(jsonEncode(record.summary.toJson()));
  }

  /// Past session summaries, newest first. Unreadable files are skipped.
  Future<List<SessionSummary>> list() async {
    if (!await directory.exists()) return const [];
    final summaries = <SessionSummary>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.summary.json')) continue;
      try {
        summaries.add(
          SessionSummary.fromJson(
            jsonDecode(await entity.readAsString()) as Map<String, Object?>,
          ),
        );
      } on Object {
        continue;
      }
    }
    summaries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return summaries;
  }

  Future<SessionRecord?> load(String id) async {
    final summaryFile = _summaryFile(id);
    final timelineFile = _timelineFile(id);
    if (!await summaryFile.exists() || !await timelineFile.exists()) {
      return null;
    }
    final summary = SessionSummary.fromJson(
      jsonDecode(await summaryFile.readAsString()) as Map<String, Object?>,
    );
    final data =
        jsonDecode(await timelineFile.readAsString()) as Map<String, Object?>;
    return SessionRecord(
      summary: summary,
      timeline: [
        for (final e in data['timeline']! as List)
          TimelinePoint.fromJson((e as Map).cast<String, Object?>()),
      ],
      marks: [
        for (final e in data['marks']! as List)
          SessionMark.fromJson((e as Map).cast<String, Object?>()),
      ],
    );
  }

  Future<void> delete(String id) async {
    for (final f in [_summaryFile(id), _timelineFile(id), rawFile(id)]) {
      if (await f.exists()) await f.delete();
    }
  }
}
