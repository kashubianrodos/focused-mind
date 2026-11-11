import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../sessions/export_service.dart';
import '../sessions/session_models.dart';
import 'format.dart';
import 'summary_view.dart';

/// Past sessions, newest first (focus-sessions spec: "Session history").
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late Future<List<SessionSummary>> _summaries;
  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    _services = ref.read(servicesProvider);
    _summaries = _services.sessions.list();
    _services.historyVersion.addListener(_reload);
  }

  @override
  void dispose() {
    _services.historyVersion.removeListener(_reload);
    super.dispose();
  }

  void _reload() => setState(() {
    _summaries = _services.sessions.list();
  });

  Future<void> _delete(SessionSummary s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          'The session from ${_date(s.startedAt)} will be removed from this '
          'Mac. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final services = ref.read(servicesProvider);
    await services.sessions.delete(s.id);
    services.historyVersion.value++;
  }

  /// Exports [s] into a folder the user picks, then says where it went.
  Future<void> _export(SessionSummary s, BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _services.export.export(s.id);
    final message = switch (result) {
      ExportSaved(:final folder, :final files) =>
        'Exported ${files.join(' and ')} to $folder',
      ExportCancelled() => null,
      ExportFailed(:final message) => 'Export failed: $message',
    };
    if (message == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: ValueKey(result is ExportSaved ? 'export-saved' : 'export-failed'),
        content: Text(message),
      ),
    );
  }

  Future<void> _open(SessionSummary s) async {
    final services = ref.read(servicesProvider);
    final record = await services.sessions.load(s.id);
    if (record == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Session · ${_date(s.startedAt)}'),
            actions: [
              Builder(
                builder: (context) => TextButton.icon(
                  key: const ValueKey('export-detail'),
                  onPressed: () => _export(s, context),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export'),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SummaryView(
              record: record,
              threshold: services.settings.value.threshold,
            ),
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _summaries,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(
            child: Text('No sessions yet. Finished sessions appear here.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = items[i];
            final avg = s.averageScore?.round().toString() ?? '–';
            return ListTile(
              key: ValueKey('history-${s.id}'),
              title: Text(_date(s.startedAt)),
              subtitle: Text(
                '${formatMinutes(s.duration)} · average focus $avg · '
                '${s.drops} drops · ${s.recoveries} recoveries',
              ),
              onTap: () => _open(s),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.hasRawRecording)
                    Tooltip(
                      key: ValueKey('raw-${s.id}'),
                      message: 'Raw signal recorded',
                      child: const Icon(Icons.graphic_eq),
                    ),
                  IconButton(
                    key: ValueKey('export-${s.id}'),
                    tooltip: 'Export to CSV',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => _export(s, context),
                  ),
                  IconButton(
                    key: ValueKey('delete-${s.id}'),
                    tooltip: 'Delete session',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(s),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
