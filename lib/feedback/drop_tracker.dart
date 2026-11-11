import 'dart:async';

import '../focus/focus_state.dart';

enum DropEvent { drop, recovery }

/// Turns the 1 Hz focus state into focus drops and recoveries, the same for
/// both feedback modes (focus-audio-feedback spec, design D6).
///
/// A drop starts once the state has been distracted for [triggerDelay]; it
/// ends with a recovery once the state has been focused for
/// [recoveryDuration]. Neutral and unavailable never start or end a drop,
/// but they do interrupt a distracted or focused run.
class DropTracker {
  DropTracker({
    this.triggerDelay = const Duration(seconds: 5),
    this.recoveryDuration = const Duration(seconds: 3),
  });

  Duration triggerDelay;
  final Duration recoveryDuration;

  final _events = StreamController<DropEvent>.broadcast(sync: true);

  bool _dropActive = false;
  Duration? _distractedSince;
  Duration? _focusedSince;
  int drops = 0;
  int recoveries = 0;

  bool get dropActive => _dropActive;
  Stream<DropEvent> get events => _events.stream;

  /// Feeds the state observed at [at] (time since the session started).
  /// Returns the event this update produced, if any.
  DropEvent? update(FocusState state, Duration at) {
    _distractedSince = state == FocusState.distracted
        ? (_distractedSince ?? at)
        : null;
    _focusedSince = state == FocusState.focused ? (_focusedSince ?? at) : null;

    if (!_dropActive &&
        _distractedSince != null &&
        at - _distractedSince! >= triggerDelay) {
      _dropActive = true;
      drops++;
      _events.add(DropEvent.drop);
      return DropEvent.drop;
    }
    if (_dropActive &&
        _focusedSince != null &&
        at - _focusedSince! >= recoveryDuration) {
      _dropActive = false;
      recoveries++;
      _events.add(DropEvent.recovery);
      return DropEvent.recovery;
    }
    return null;
  }

  /// Forgets runs in progress (e.g. after a connection gap), keeping any
  /// active drop and the counts.
  void interrupt() {
    _distractedSince = null;
    _focusedSince = null;
  }

  void reset() {
    interrupt();
    _dropActive = false;
    drops = 0;
    recoveries = 0;
  }

  Future<void> dispose() => _events.close();
}
