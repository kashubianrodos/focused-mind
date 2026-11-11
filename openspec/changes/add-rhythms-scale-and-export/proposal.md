# Proposal

## Why

The focus score alone tells the user *whether* their focus dropped, not *what* their brain was doing. The BrainBit EEGWaves app (`EEGWaves.Android.apk`, used as a reference) shows two richer views on the same EmotionalMath output we already compute: a relaxation–concentration scale with four named zones, and the share of alpha, beta and theta rhythms as a pie and over time. It also lets users export a session to CSV. That export is the only way to look at the data in other tools or to share it with someone helping tune the app (for example, the hardware tuning in the desktop focus monitor's task 7.2).

## What Changes

- **Relaxation–concentration scale:** a gauge pinned at the bottom of the live session view, updated in real time. It has four zones, as in EEGWaves: Deep relaxation, Relaxation, Concentration and Deep concentration. It shows the same calibration-relative focus index as the focus score. The user's baseline sits on the boundary between Relaxation and Concentration, and the "deep" zones are at the extremes. The focus score, focus states, threshold and sound feedback are unchanged.
- **Brain rhythms:**
  - a live pie (donut) of the current alpha, beta and theta shares;
  - a stacked area chart of the three rhythms over the session.
  
  Both appear in the live session view, and both are saved with the session and shown again in its summary and history.
- **Session recording:** every second of the timeline also stores the scale zone and the alpha/beta/theta percentages. The scale position is the focus score itself, so it isn't stored twice. Sessions saved before this change still open, without rhythm or scale data.
- **Export from history:** each session in history gets an **Export** action that writes a CSV of its 1-second timeline into a folder the user picks, as in EEGWaves ("Select a location to save the session").
- **Optional raw EEG recording:** a setting, off by default, records the raw 250 Hz O1/O2/T3/T4 signal during sessions, like EEGWaves' "Record raw signal (CSV)". When a session has a recording, Export also writes it as a second CSV. The Settings screen states the storage cost (about 20 MB per hour).

## Capabilities

### New Capabilities
- `focus-scale`: the four-zone relaxation–concentration scale, its mapping from the focus index and baseline, and the real-time gauge.
- `brain-rhythms`: alpha, beta and theta shares from the EEG, shown live as a pie and over time as a stacked chart, recorded per session.
- `session-export`: exporting a saved session's data to CSV, and optionally recording and exporting the raw EEG signal.

### Modified Capabilities
None in `openspec/specs/`. That folder is empty until `add-desktop-focus-monitor` is archived.

This change extends behaviour that the in-flight change defines: the live session view, the summary and history in `focus-sessions`, and the focus index and baseline in `focus-tracking`. To keep the two changes independent, the new requirements live in the three new capabilities. Archive `add-desktop-focus-monitor` first, so these build on its specs.

## Impact

- **Code:**
  - `lib/focus/`: the estimator also reads `readSpectralDataPercents()`; the engine publishes rhythm shares and the scale value with each reading; a new `FocusZone` mapping.
  - `lib/sessions/`: the timeline gains new fields, with backward-compatible JSON; a CSV exporter; a raw-signal writer.
  - `lib/ui/`: a scale gauge, a rhythm pie and a stacked rhythm chart; Export in history; the raw-recording setting.
- **Dependencies:** `file_selector`, for the macOS folder picker. `fl_chart`, already a dependency, draws the pie and the stacked chart. The gauge is a custom painter.
- **Entitlements:** add `com.apple.security.files.user-selected.read-write`, so the sandboxed app can write into the folder the user picks. There is still no network access, and data leaves the app only through a file the user chooses.
- **Storage:** the timeline grows by about 40%. A raw recording is about 20 MB per hour in a separate file next to the session, and deleting the session deletes it too.
- **Reference:** EEGWaves, which uses the same `EmStArtifacts` library with delta and gamma zeroed, like our `setZeroSpectWaves(true, 0, 1, 1, 1, 0)`. That is why its pie shows exactly theta, alpha and beta.
