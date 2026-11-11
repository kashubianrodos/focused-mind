import 'package:flutter/material.dart';

const wellnessNoticeText =
    'Focused Mind estimates your focus from EEG to give you gentle audio '
    'feedback while you work. The focus score is an estimate for personal, '
    'wellness use only. It is not a medical device and does not measure, '
    'diagnose or treat any condition.';

Future<void> showWellnessNotice(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    title: const Text('Before you start'),
    content: const SizedBox(width: 420, child: Text(wellnessNoticeText)),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('I understand'),
      ),
    ],
  ),
);
