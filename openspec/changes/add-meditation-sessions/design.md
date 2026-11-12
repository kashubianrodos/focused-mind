# Design

## Context

What exists today:

- **One session controller:** `SessionController` runs every session: signal check, calibration, tracking at 1 Hz, gaps, and the end of the session. On each `FocusReading` it does four things, in order:
  1. classifies the score with `classifyFocus(score, threshold)` into focused, neutral, distracted or unavailable;
  2. feeds `DropTracker`, which turns that state into drops and recoveries using `triggerDelay` and a 3 s `recoveryDuration`;
  3. updates `FeedbackController` (score, `dropActive`);
  4. records a `TimelinePoint` with the zone from `ScoreScale.zoneOf`.
- **Gain:** `targetGain()` in `lib/feedback/gain_policy.dart` maps the mode, the active drop and the score to a gain. Alert plays during a drop; Continuous plays outside a drop and gets louder with the score.
- **Summary stats:** `SessionSummary` stores `timeInState`, `drops`, `recoveries`, `longestFocused`, `timeInZone`, `averageRhythms` and `mode`. These come from the recorded states, so they follow whatever classification the controller fed in.
- **Scale and gauge:** `ScoreScale` maps the focus index to the score around the baseline B. It also defines the zones and their boundaries (`toScore(−span)`, B, `toScore(span)`). `FocusScaleGauge` paints the four zones from low to high.
- **Start screen:** the duration selector is a `SegmentedButton` in `_StartView` (`lib/ui/focus_page.dart`). Settings are stored in `SettingsRepository`.
- **Specs:** there are no main specs yet, because the earlier changes are not archived. The behaviour of this change lives in the new `meditation-sessions` capability.

## Goals / Non-Goals

**Goals:**
- A meditation session differs from a focus session only through the session type, chosen at start. The headband, calibration, scale, rhythms, raw recording and export all run on the same code paths.
- Recorded data stays comparable across types. The timeline keeps the raw focus score and zone, so a session can be re-read either way.
- Focus sessions behave exactly as before (the existing tests stay green unchanged).

**Non-Goals:**
- Separate meditation settings such as their own threshold, soundscape or trigger delay. Meditation reuses the soundscape, volume, trigger delay and baseline.
- Guided meditation audio, breathing pacers or timers other than the existing durations.
- Switching type mid-session.
- History filters or statistics per type.

## Decisions

### D1. `SessionKind` is chosen at start and fixed for the session
- **Type:** add `enum SessionKind { focus, meditation }` with labels "Focus session" and "Meditation session".
- **Starting:** `SessionController.start({planned, kind})` stores the kind for the session, and `LiveSession` exposes it.
- **Remembering:** the start screen keeps the selection in `SettingsRepository.lastSessionKind`, saved when a session starts and read on launch. It defaults to focus.
- **Selector:** a second `SegmentedButton` above the duration selector, with keys `kind-focus` and `kind-meditation`. The heading changes to "Start a focus session" or "Start a meditation session".

Alternative considered: a third value of `FeedbackMode`. Rejected, because the type also changes classification, display and stats, not only sound, and the feedback setting must keep its meaning for focus sessions.

### D2. Meditation states reuse `FocusState`, classified by zone
In a meditation session the controller classifies with `classifyCalm(score, scale)` instead of `classifyFocus`:

| Zone | State recorded | Shown as |
|---|---|---|
| Deep relaxation, Relaxation | `focused` | Calm |
| Concentration, Deep concentration | `distracted` | Restless |
| score unavailable | `unavailable` | Signal unavailable |

So `focused` means "on goal" and `distracted` means "off goal". `DropTracker`, `SessionRecorder` and the summary stats then work unchanged:
- drops become restless episodes;
- `timeInState[focused]` becomes time calm;
- `longestFocused` becomes the longest calm stretch.

The UI picks labels by kind with `stateLabel(state, kind)`: Calm/Restless for meditation, Focused/Neutral/Distracted for focus. The zone boundary is the baseline, so being Calm matches the user's calibrated level, and the focus threshold setting is not used in meditation. There is no neutral band, because `DropTracker`'s trigger delay and recovery time already damp flicker at the boundary.

Alternative considered: a separate `CalmState` enum, with its own tracker and stats. It would duplicate `DropTracker`, `SessionRecorder` stats, the summary and the CSV for no visible gain.

### D3. Calm score is a display transform
- **Formula:** `calmScore = 100 − focusScore`, computed only for display: the live number, the live graph, and the summary and history graphs.
- **Storage:** the timeline and export keep the raw focus score (spec: the focus score column stays raw).
- **Chart:** `FocusChart` gets an optional `invert` flag (`kind == meditation`) that plots `100 − score`. It hides the focus threshold line, because the threshold doesn't apply in meditation, and shows a dashed line at the calm level of the zone boundary, `100 − B`.

### D4. Mirrored gauge
`FocusScaleGauge` gets `mirrored: bool`:
- **Painting:** it paints the zones in reverse order, with the boundaries at `100 − b` (boundaries and zones themselves unchanged).
- **Needle:** it sits at `100 − score`.
- **Labels:** the zone labels are reversed.
- **Colours:** each zone keeps its colour; only its position flips.
- **Semantics:** the semantics value still reads `"<score> <zone>"` with the raw focus score, so existing tests and accessibility stay meaningful. A widget test checks that Deep relaxation is the rightmost zone and that the needle is on the right for a low focus score.

### D5. Meditation gain
`targetGain` gains a `kind` and the `ScoreScale`. For `SessionKind.meditation` it ignores `FeedbackMode`:
```
if dropActive (restless episode) or score == null → 0
B = scale.baseline, deep = scale.zoneBoundaries[0]
level = ((B − score) / (B − deep)).clamp(0, 1)   // 0 at boundary, 1 in Deep relaxation
gain = volume · fraction(level)                  // same 0.4…1 floor as Continuous
```
Muting, the volume, and silence after 10 s unavailable all apply as before.
- **Before an episode:** while the wearer is in Concentration but no restless episode has started yet (within the trigger delay), `level` is 0 and the sound plays at the floor, 40 % of the volume. That matches Continuous mode during a not-yet-confirmed drop.
- **Controller:** `FeedbackController` takes the kind and scale through `applySettings` and `start`, and `SessionController` passes them in.

### D6. Session type on screen and in data
- **Session label:** a `SessionKindChip` (key `session-kind`) shows the type at the top of the signal-check, calibrating, calibration-failed, live and summary views. `LiveSessionView` places it at the top of its scroll body, above the connection header, so it stays visible on phones.
- **Summary stats:** in meditation the cards read "Time calm", "Longest calm" and "Restless episodes" instead of "Time focused", "Longest focus" and "Drops". The keys stay the same.
- **Data:** `SessionSummary.kind` is written as JSON `kind` (`focus` or `meditation`), and a missing value reads as focus. The history list shows an icon and label per entry (key `kind-<id>`). The detail view passes the kind to the summary.
- **CSV:** `SessionCsv.timeline` appends a trailing `session_type` column, so existing column positions don't change. Its `focus_state` cell holds the kind's label in lower case (`calm` or `restless` for meditation). That matches what the user saw, and the raw `focus_score` sits alongside it.

### D7. Testing
- **Unit tests:**
  - `classifyCalm` at the boundaries for baselines 30, 50 and 70;
  - the meditation `targetGain`: zero during an episode, the floor at the boundary, full in Deep relaxation, mute and unavailable;
  - `SessionSummary` JSON with `kind` and without it (an old file);
  - the CSV `session_type` column, and `focus_state` labels for meditation.
- **Widget tests:**
  - the start-screen selector defaults to focus, remembers meditation across restarts, and shows the heading;
  - the live view at phone width in meditation shows the "Meditation session" label, the calm score and the mirrored gauge;
  - the summary card labels;
  - the history kind marker.
- **Controller test:** a scripted meditation session with the fake estimator, at low focus and then high focus. It checks a restless episode after the trigger delay, the feedback gain dropping to 0, and the summary counts.
- **End to end:** extend the simulated scenario with a meditation run on the real EmotionalMath. At low simulated focus the session is mostly Calm and the sound plays.

## Risks / Trade-offs

- **[Reusing `FocusState.focused` for "calm" is easy to misread in code]** → Name the classifier `classifyCalm`, document the mapping on `SessionKind`, and keep all user-visible wording behind `stateLabel(state, kind)`.
- **[No neutral band means more Calm/Restless switching near the boundary]** → Sound and episodes are damped by the trigger delay and recovery time. The live state label may still flip at 1 Hz. Watch for this in the hardware session, and add a margin later if it is distracting.
- **[A changed CSV header could break scripts that parse by position]** → The column is appended at the end, and existing positions are unchanged.
- **[Older app versions reading new summaries]** → An unknown `kind` key is ignored, so a meditation session would show as a focus session with its stats labelled as focus. That is acceptable.
