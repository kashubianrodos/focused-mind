# Tasks

## 1. Session type and data model (design D1, D6)

- [x] 1.1 Add `SessionKind { focus, meditation }` with the labels "Focus session"/"Meditation session" and a doc comment on the meaning of `FocusState` per kind (D2). Add `SessionSummary.kind`, stored as JSON `kind` and read back as `focus` when missing. Verify with unit tests that `kind` round-trips and that a pre-change summary JSON loads as focus.
- [x] 1.2 Add `lastSessionKind` and `saveLastSessionKind` (key `last_session_kind`) to `SettingsRepository`, defaulting to focus. Verify with a unit test that the value persists across repository instances.

## 2. Classification, tracking and gain (design D2, D5)

- [x] 2.1 Add `classifyCalm(score, ScoreScale)`: Relaxation or deeper is `focused` (calm), Concentration or higher is `distracted` (restless), and null is `unavailable`. Add `stateLabel(state, kind)` for Focused/Neutral/Distracted and Calm/Restless. Verify with unit tests at the zone boundary for baselines 30, 50 and 70, and for every label.
- [x] 2.2 Add the meditation branch to `targetGain` (kind and scale): 0 during a restless episode or with no score, the floor at the boundary, full in Deep relaxation, with mute and the volume applying, and `FeedbackMode` ignored. Pass the kind and scale through `FeedbackController`. Verify with unit tests for each case, and that focus-mode gains are unchanged (the existing gain tests pass as before).
- [x] 2.3 Make `SessionController.start({planned, kind})` keep the kind, classify by kind, feed the feedback controller with the kind and scale, expose the kind on `LiveSession`, and record it in the summary. Verify with a `fake_async` controller test of a scripted meditation session: low focus is Calm and the sound plays; sustained high focus gives one restless episode after the trigger delay and a gain of 0; recovery brings the sound back; the summary shows `kind: meditation` with the expected time calm and episode count. The existing focus-session controller tests must pass unchanged.

## 3. Start screen and session label (design D1, D6)

- [x] 3.1 Add the Focus/Meditation selector (keys `kind-focus`, `kind-meditation`) above the durations on the start and ended views. It defaults from `lastSessionKind`, saves when a session starts, and switches the heading text. Verify with widget tests: the default is focus; after starting a meditation session and pumping a fresh app, Meditation is selected.
- [x] 3.2 Add the `SessionKindChip` (key `session-kind`) at the top of the signal-check, calibrating, calibration-failed, live (paused included) and summary views. Verify with a widget test that it reads "Meditation session" during calibration and in the live view of a meditation session, and "Focus session" for a focus session.

## 4. Meditation display (design D3, D4, D6)

- [x] 4.1 In the live view for meditation, show the calm score (100 − score) with the Calm/Restless label and colour, and pass `invert` to `FocusChart`: it plots 100 − score, hides the focus threshold line and draws the calm boundary at 100 − B. Verify with a widget test driven by the fake estimator: a focus score of 22 shows 78 and Calm; 82 shows 18 and Restless; an unavailable score shows the unavailable state.
- [x] 4.2 Add `mirrored` to `FocusScaleGauge`, with reversed zone order and labels, the needle at 100 − score, unchanged colours per zone and unchanged semantics. Use it in meditation sessions. Verify with widget tests: Deep relaxation is the rightmost zone label; a low focus score puts the needle in the right part of the bar; the same score names the same zone mirrored and unmirrored.
- [x] 4.3 In the summary and history detail for meditation sessions, use the inverted chart and the "Time calm", "Longest calm" and "Restless episodes" cards. In the history list, mark each entry's type (key `kind-<id>`). Verify with widget tests for a meditation summary, a focus summary (labels unchanged), and a pre-change session in history shown as focus.

## 5. Export, integration and docs (design D6, D7)

- [x] 5.1 Append a `session_type` column to `SessionCsv.timeline` and write the kind's state label in `focus_state` (calm/restless for meditation). Verify with unit tests: the new header; a meditation session has `meditation` on every row with raw focus scores; a pre-change session exports `focus`.
- [x] 5.2 Extend the simulated end-to-end scenario with a meditation run on real EmotionalMath: at low simulated focus the session is mostly Calm with the sound playing, and at high focus a restless episode is recorded. Run `flutter test`, and check that `flutter analyze` is clean.
- [x] 5.3 Add a "Meditation sessions" section to `README.md` covering the selector, the calm score, the mirrored gauge, the sound and the CSV column. Verify that the README matches the start screen and settings, and update the iPhone screenshot if the live view's top changes.
- [x] 5.4 Manually, on the iPhone with Mindo: run a 10-minute meditation session. Check that the type label, calm score and mirrored gauge show, that the sound plays while relaxed and stops after a burst of concentration (for example, mental arithmetic), and that history and export show the meditation type. Note in `docs/hardware.md` whether Calm/Restless flicker near the boundary.
