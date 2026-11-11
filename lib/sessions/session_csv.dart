import 'dart:io';

import 'raw_signal.dart';
import 'session_models.dart';

/// Builds the CSV files a session exports to (session-export spec,
/// design D5).
abstract final class SessionCsv {
  static const timelineHeader = [
    'elapsed_s',
    'time',
    'focus_score',
    'focus_state',
    'scale_zone',
    'theta_pct',
    'alpha_pct',
    'beta_pct',
    'gap',
    'feedback_mode',
    'mark',
  ];

  /// One row per second of [record]'s timeline; unavailable values are
  /// empty cells, and several marks in one second are joined with `;`.
  static String timeline(SessionRecord record) {
    final marks = <int, List<String>>{};
    for (final m in record.marks) {
      (marks[m.second] ??= []).add(_markName(m.kind));
    }
    final start = record.summary.startedAt;
    final out = StringBuffer()..write(_row(timelineHeader));
    for (final p in record.timeline) {
      final r = p.rhythms;
      out.write(
        _row([
          '${p.second}',
          _localIso(start.add(Duration(seconds: p.second))),
          _num(p.score),
          p.state.name,
          p.zone?.name ?? '',
          _num(r?.theta),
          _num(r?.alpha),
          _num(r?.beta),
          p.gap ? '1' : '0',
          p.mode.name,
          (marks[p.second] ?? const []).join(';'),
        ]),
      );
    }
    return out.toString();
  }

  static const rawHeader = ['t_s', 'o1_uv', 'o2_uv', 't3_uv', 't4_uv'];

  /// Streams a raw recording ([RawSignalFormat]) to [out] as CSV: seconds
  /// since tracking start (4 decimals, i.e. per 250 Hz sample) and the four
  /// electrodes in microvolts (3 decimals). Batches are converted as they
  /// are read, so long recordings are never held in memory.
  static Future<void> rawSignal(File raw, IOSink out) async {
    out.write(_row(rawHeader));
    await for (final batch in readRawRecords(raw)) {
      final text = StringBuffer();
      for (var i = 0; i < batch.length; i += RawSignalFormat.valuesPerRecord) {
        text
          ..write(batch[i].toStringAsFixed(4))
          ..write(',')
          ..write((batch[i + 1] * 1e6).toStringAsFixed(3))
          ..write(',')
          ..write((batch[i + 2] * 1e6).toStringAsFixed(3))
          ..write(',')
          ..write((batch[i + 3] * 1e6).toStringAsFixed(3))
          ..write(',')
          ..write((batch[i + 4] * 1e6).toStringAsFixed(3))
          ..write('\r\n');
      }
      out.write(text);
    }
  }

  static String _markName(MarkKind kind) => switch (kind) {
    MarkKind.drop => 'drop',
    MarkKind.recovery => 'recovery',
    MarkKind.gapStart => 'gap_start',
    MarkKind.gapEnd => 'gap_end',
  };

  static String _num(double? v) => v == null ? '' : v.toStringAsFixed(1);

  /// ISO 8601 local time to the second, e.g. `2026-11-11T09:00:05`.
  static String _localIso(DateTime t) =>
      t.toLocal().toIso8601String().substring(0, 19);

  /// One CSV line (RFC 4180: quoted when needed, CRLF ending).
  static String row(List<String> cells) => _row(cells);

  static String _row(List<String> cells) =>
      '${cells.map(_quote).join(',')}\r\n';

  static String _quote(String cell) {
    if (!cell.contains(RegExp('[",\r\n]'))) return cell;
    return '"${cell.replaceAll('"', '""')}"';
  }
}
