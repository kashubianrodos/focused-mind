import 'package:flutter/material.dart';

import '../focus/focus_engine.dart';
import '../headband/models.dart';

extension ElectrodeLabel on Electrode {
  String get label => switch (this) {
    Electrode.o1 => 'O1 (back left)',
    Electrode.o2 => 'O2 (back right)',
    Electrode.t3 => 'T3 (left temple)',
    Electrode.t4 => 'T4 (right temple)',
  };
}

Color contactColor(ContactQuality q, ColorScheme scheme) => switch (q) {
  ContactQuality.good => Colors.green.shade600,
  ContactQuality.fair => Colors.amber.shade700,
  ContactQuality.poor => scheme.error,
};

/// Per-electrode contact quality with a hint when any electrode is poor.
class ContactView extends StatelessWidget {
  const ContactView({super.key, required this.report});

  final ContactReport? report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = report;
    if (r == null) {
      return const Text('Measuring electrode contact…');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in Electrode.values)
              Chip(
                key: ValueKey('contact-${e.name}'),
                avatar: Icon(
                  Icons.circle,
                  size: 12,
                  color: contactColor(r[e], scheme),
                ),
                label: Text('${e.label}: ${r[e].name}'),
              ),
          ],
        ),
        if (r.poorElectrodes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Adjust the band so ${r.poorElectrodes.map((e) => e.label).join(', ')} '
            'touches the skin. Moving hair aside under the electrode helps.',
            style: TextStyle(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

/// Left/right signal quality during a session.
class SideQualityView extends StatelessWidget {
  const SideQualityView({super.key, required this.left, required this.right});

  final SideQuality? left;
  final SideQuality? right;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget side(String name, SideQuality? q) => Chip(
      avatar: Icon(
        Icons.circle,
        size: 12,
        color: q == SideQuality.good
            ? Colors.green.shade600
            : (q == null ? scheme.outline : scheme.error),
      ),
      label: Text('$name: ${q?.name ?? '–'}'),
    );
    return Wrap(
      spacing: 8,
      children: [side('Left', left), side('Right', right)],
    );
  }
}
