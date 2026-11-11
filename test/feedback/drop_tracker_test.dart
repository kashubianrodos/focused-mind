import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/drop_tracker.dart';
import 'package:focused_mind/focus/focus_state.dart';

const d = FocusState.distracted;
const n = FocusState.neutral;
const f = FocusState.focused;
const u = FocusState.unavailable;

/// Feeds one state per second starting at t = 0 and returns the events
/// with the second they happened.
List<(int, DropEvent)> run(DropTracker tracker, List<FocusState> states) {
  final events = <(int, DropEvent)>[];
  for (var i = 0; i < states.length; i++) {
    final e = tracker.update(states[i], Duration(seconds: i));
    if (e != null) events.add((i, e));
  }
  return events;
}

void main() {
  test('sustained drop: distracted for the trigger delay records a drop', () {
    final t = DropTracker();
    final events = run(t, [n, d, d, d, d, d, d, d]);
    // Distracted since t=1, drop at t=6 (5 s later).
    expect(events, [(6, DropEvent.drop)]);
    expect(t.dropActive, isTrue);
    expect(t.drops, 1);
  });

  test('momentary dip shorter than the delay records nothing', () {
    final t = DropTracker();
    expect(run(t, [d, d, d, d, n, d, d, d, d, f]), isEmpty);
    expect(t.drops, 0);
  });

  test('recovery after focused for 3 s, counted once', () {
    final t = DropTracker();
    final events = run(t, [d, d, d, d, d, d, f, f, f, f, f, f]);
    expect(events, [(5, DropEvent.drop), (9, DropEvent.recovery)]);
    expect(t.recoveries, 1);
    expect(t.dropActive, isFalse);
  });

  test('neutral and unavailable keep an active drop going', () {
    final t = DropTracker();
    final events = run(t, [d, d, d, d, d, d, n, n, u, u, u, u, u, u, u, u, u]);
    expect(events, [(5, DropEvent.drop)]);
    expect(t.dropActive, isTrue);
  });

  test('focused run interrupted by neutral restarts the 3 s count', () {
    final t = DropTracker();
    final events = run(t, [d, d, d, d, d, d, f, f, n, f, f, f, f]);
    expect(events, [(5, DropEvent.drop), (12, DropEvent.recovery)]);
  });

  test('unavailable interrupts a distracted run, so no drop', () {
    final t = DropTracker();
    expect(run(t, [d, d, d, u, d, d, d, d]), isEmpty);
  });

  test('trigger delay is adjustable', () {
    final t = DropTracker(triggerDelay: const Duration(seconds: 3));
    expect(run(t, [d, d, d, d]), [(3, DropEvent.drop)]);
  });

  test('events stream mirrors update results', () {
    final t = DropTracker();
    final seen = <DropEvent>[];
    t.events.listen(seen.add);
    run(t, [d, d, d, d, d, d, f, f, f, f]);
    expect(seen, [DropEvent.drop, DropEvent.recovery]);
  });
}
