import 'package:flutter/material.dart';

import '../focus/session_kind.dart';

/// Shows which type of session is running, at the top of every session
/// screen (meditation-sessions spec, design D6).
class SessionKindChip extends StatelessWidget {
  const SessionKindChip(this.kind, {super.key});

  final SessionKind kind;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Chip(
      key: const ValueKey('session-kind'),
      avatar: Icon(switch (kind) {
        SessionKind.focus => Icons.center_focus_strong,
        SessionKind.meditation => Icons.self_improvement,
      }, size: 18),
      label: Text(kind.label),
      visualDensity: VisualDensity.compact,
    ),
  );
}
