import '../focus/focus_state.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String formatMinutes(Duration d) {
  if (d.inMinutes >= 1) {
    final s = d.inSeconds.remainder(60);
    return s == 0 ? '${d.inMinutes} min' : '${d.inMinutes} min $s s';
  }
  return '${d.inSeconds} s';
}

extension FocusStateLabel on FocusState {
  String get label => switch (this) {
    FocusState.focused => 'Focused',
    FocusState.neutral => 'Neutral',
    FocusState.distracted => 'Distracted',
    FocusState.unavailable => 'Signal unavailable',
  };
}
