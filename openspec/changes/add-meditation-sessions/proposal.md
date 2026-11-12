# Proposal

## Why

The same headband measurement that shows how focused the wearer is also shows how calm they are. Calm is the other end of the same scale. Today every session rewards concentration. Users who want to settle down — before sleep, between meetings, or as a breathing practice — have no session that rewards the relaxed end of the scale. A meditation session reuses everything the app already has: connection, calibration, scale, rhythms, history and export. It reverses only the goal, the display and the sound.

## What Changes

- **Session type selector:** the session start screen gets a selector with **Focus** and **Meditation**. It defaults to the last type used.
- **Focus sessions:** they behave exactly as today.
- **Meditation sessions:** the goal is the relaxed, calm end of the scale.
  - **Calm score:** the live view shows a calm score of 100 − the focus score, with the state *Calm* (in Relaxation or Deep relaxation) or *Restless* (in Concentration or Deep concentration). The live graph plots the calm score.
  - **Mirrored gauge:** the scale gauge runs Deep concentration → Concentration → Relaxation → Deep relaxation, left to right, so the needle moves right as the wearer calms down. The zones, colours and boundaries are unchanged.
  - **Sound:** the soundscape plays continuously. It gets louder the deeper the wearer goes into Relaxation, up to full volume in Deep relaxation. It goes silent once the wearer has stayed in Concentration or Deep concentration for the trigger delay, and comes back after the usual recovery time back in Relaxation or below. The Alert/Continuous feedback setting does not apply to meditation sessions.
  - **Restless episodes:** these take the place of focus drops (the same tracking, reversed). A restless episode starts after the trigger delay in Concentration or above, and ends after the recovery time back in Relaxation or below.
- **Session type on screen:** a label at the top of every session screen shows the type, *Focus session* or *Meditation session*: signal check, calibration, the live session and the summary. History shows each session's type, and its detail view uses the calm wording and calm score for meditation sessions.
- **Saved data:** session records save their type. Sessions saved before this change load as focus sessions.
- **Export:** the CSV export gains a `session_type` column (`focus` or `meditation`). `focus_score` stays the raw focus score in both types.
- **Unchanged:** connection, calibration, the baseline, raw recording, the rhythm pie and chart, the menu bar and settings.

## Capabilities

### New Capabilities
- `meditation-sessions`: covers the session type (focus or meditation), choosing it, the meditation goal, the calm score and states, the mirrored scale gauge, meditation sound feedback, showing the type during and after a session, and the session type in history and export.

### Modified Capabilities
None. The related capabilities (`focus-sessions`, `focus-audio-feedback`, `focus-scale`, `session-export`) are still in unarchived changes, so there are no main specs to modify. Focus-session behaviour stays as those changes specify, and the new requirements live in `meditation-sessions`.

## Impact

- **Code:**
  - `lib/ui/focus_page.dart`: start screen selector and type label.
  - `lib/ui/live_session_view.dart`, `lib/ui/focus_scale_gauge.dart` (mirroring), `lib/ui/focus_chart.dart` (calm series), `lib/ui/summary_view.dart`, `lib/ui/history_page.dart`.
  - `lib/sessions/session_controller.dart`: session type, and the classification and feedback per type.
  - `lib/sessions/session_models.dart` and `session_recorder.dart`: a `kind` field.
  - `lib/sessions/session_csv.dart`: a new column.
  - `lib/feedback/gain_policy.dart`: the meditation gain.
  - `lib/settings/settings_repository.dart`: the last session type used.
- **Data:** summaries gain an optional `kind` field, and old files still load. The CSV gains one trailing column.
- **Dependencies:** none new.
- **Docs:** a README section on meditation sessions.
