import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'session_csv.dart';
import 'session_models.dart';
import 'session_repository.dart';

/// Asks the user for a folder; null when they cancel.
typedef PickFolder = Future<String?> Function();

/// macOS asks for a folder. Android's picker returns a `content://` URI that
/// `dart:io` can't write to, so exports go to Downloads/Focused Mind there.
Future<String?> pickExportFolder() async {
  if (!Platform.isAndroid) {
    return getDirectoryPath(confirmButtonText: 'Export here');
  }
  final downloads = await const MethodChannel(
    'focused_mind/android',
  ).invokeMethod<String>('downloadsDir');
  final folder = Directory(p.join(downloads!, 'Focused Mind'));
  await folder.create(recursive: true);
  return folder.path;
}

sealed class ExportResult {
  const ExportResult();
}

class ExportSaved extends ExportResult {
  const ExportSaved(this.folder, this.files);
  final String folder;
  final List<String> files;
}

class ExportCancelled extends ExportResult {
  const ExportCancelled();
}

class ExportFailed extends ExportResult {
  const ExportFailed(this.message);
  final String message;
}

/// Exports a saved session into a folder the user picks (session-export
/// spec, design D5): the timeline CSV, plus the raw signal CSV when the
/// session has one. Never overwrites an existing file.
class ExportService {
  ExportService(this.repository, {PickFolder? pickFolder})
    : _pickFolder = pickFolder ?? pickExportFolder;

  final SessionRepository repository;
  final PickFolder _pickFolder;

  Future<ExportResult> export(String sessionId) async {
    final folder = await _pickFolder();
    if (folder == null) return const ExportCancelled();
    final written = <File>[];
    try {
      final record = await repository.load(sessionId);
      if (record == null) return const ExportFailed('Session not found');
      final base = fileBaseName(record.summary);
      final timeline = _unused(folder, base, '');
      written.add(timeline);
      await timeline.writeAsString(SessionCsv.timeline(record), flush: true);

      final raw = repository.rawFile(sessionId);
      if (record.summary.hasRawRecording && await raw.exists()) {
        final rawCsv = _unused(folder, base, '_raw');
        written.add(rawCsv);
        final sink = rawCsv.openWrite();
        try {
          await SessionCsv.rawSignal(raw, sink);
        } finally {
          await sink.close();
        }
      }
      return ExportSaved(folder, [for (final f in written) p.basename(f.path)]);
    } on Object catch (e) {
      // Leave no half-written files behind.
      for (final f in written) {
        try {
          if (f.existsSync()) f.deleteSync();
        } on Object {
          // best effort
        }
      }
      return ExportFailed(e is FileSystemException ? e.message : '$e');
    }
  }

  /// `focused-mind_<yyyy-MM-dd_HH-mm>` from the session's local start time.
  static String fileBaseName(SessionSummary s) {
    final t = s.startedAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'focused-mind_${t.year}-${two(t.month)}-${two(t.day)}'
        '_${two(t.hour)}-${two(t.minute)}';
  }

  /// `<base><suffix>.csv`, or with `_2`, `_3`, … when that name is taken.
  static File _unused(String folder, String base, String suffix) {
    var n = 1;
    while (true) {
      final name = n == 1 ? '$base$suffix.csv' : '$base${suffix}_$n.csv';
      final f = File(p.join(folder, name));
      if (!f.existsSync()) return f;
      n++;
    }
  }
}
