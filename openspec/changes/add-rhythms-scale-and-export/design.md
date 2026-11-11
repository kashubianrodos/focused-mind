# Design

## Context

This change builds on `add-desktop-focus-monitor`; see proposal.md for the why. What it relies on:

- **Estimator:** `EmotionalMathEstimator` runs `processData()` every 100 ms. Its settings already zero delta and gamma (`setZeroSpectWaves(true, 0, 1, 1, 1, 0)`), so `readSpectralDataPercents()` returns theta, alpha and beta shares of the remaining power. EEGWaves uses the same `EmStArtifacts` library with the same zeroed bands, and that is what its rhythm pie shows.
- **Engine:** `FocusEngine` averages the focus index per second over clean steps, smooths it with an EMA (τ ≈ 3 s) and publishes a `FocusReading` at 1 Hz. `ScoreScale` maps the index to the 0–100 score around the user's baseline B:
  - `B + (100 − B)·tanh(i/span)` above the baseline;
  - `B + B·tanh(i/span)` below it.
- **Sessions:**
  - `SessionRecorder` builds a 1 Hz `TimelinePoint` list plus marks.
  - `SessionRepository` stores `<id>.summary.json` and `<id>.timeline.json` under app support.
  - History lists the summaries.
- **Live view:** `LiveSessionView` is a single `Column`: score and state, the focus chart, time and status rows. Charts use `fl_chart` 1.3.
- **Sandbox:** the app is sandboxed with Bluetooth only. Writing outside its container needs a user-selected location and the `files.user-selected.read-write` entitlement. That entitlement covers only the item the user picked, so a folder picker is needed to write two files.

## Goals / Non-Goals

**Goals:**
- One source of truth: the scale, rhythms and score all come out of the same estimator step and the same per-second publish, so they agree at every second.
- Older session files keep loading, and their exports just have empty columns.
- Raw recording costs nothing when the setting is off.

**Non-Goals:**
- Delta and gamma rhythms, and per-hemisphere rhythms.
- Re-importing exported CSVs, or EDF/BDF formats.
- Exporting from the live session (Export lives in history, after a session is saved).
- Recording raw signal during the signal check and calibration (recording starts when tracking starts).
- Changing feedback behaviour; the zones are display only.

## Decisions

### D1. Scale position = focus score; zones from fixed index bands
Because the score is already a monotonic map of the focus index with the baseline at index 0, the scale position is the score. Zones are bands of the index, at ±1 span (tanh(1) ≈ 0.76):

| Zone | Index | Score with baseline B |
|---|---|---|
| Deep relaxation | i < −span | < B − 0.76·B |
| Relaxation | −span ≤ i < 0 | up to B |
| Concentration | 0 ≤ i < span | up to B + 0.76·(100 − B) |
| Deep concentration | i ≥ span | above that |

With B = 50 the boundaries are 12, 50 and 88.

- `ScoreScale` gains `zoneOf(score)` and `zoneBoundaries`, so the gauge, the recorder and the exporter share one definition.
- A baseline change moves the boundaries along with the score. The recorder stores the zone per second (computed with the baseline at that second), so history stays correct after later baseline changes.

Alternatives considered:
- A separate scale from `relAttention`/`relRelaxation` with its own smoothing, as EEGWaves draws them. It could disagree with the score at the same second, and it would need a second calibration story.
- Equal 25-point zones. They ignore the baseline, so the calibrated level would not sit on the Relaxation/Concentration boundary.

### D2. Rhythm shares come from the estimator and are smoothed like the score
- `EstimatorOutput` gains `rhythms` (theta, alpha, beta), read with `readSpectralDataPercents()` after each step once calibration has finished. It takes the last entry and renormalises so theta + alpha + beta = 100. It is null when there is no entry or the total is 0.
- `FocusEngine` averages rhythm shares per second over the same clean steps as the index, smooths each with the same EMA (τ ≈ 3 s), renormalises, and publishes `FocusReading.rhythms` (`RhythmShares?`).
- Rhythms are unavailable exactly when the score is unavailable, and the EMA is held, not reset.

Alternative: raw per-second shares. They flicker visibly in a pie at 1 Hz, and EEGWaves also shows averaged values.

### D3. Live view layout: scrollable body, gauge pinned at the bottom
`LiveSessionView` becomes a `Column` with two parts:
- an `Expanded` scrollable body:
  1. a header row with the score, state and time, and the rhythm pie on the right;
  2. the focus chart;
  3. the stacked rhythm chart, with the same x range and gap shading as the focus chart;
  4. the status rows.
- a fixed `FocusScaleGauge` at the bottom.

The gauge is a `CustomPainter`:
- a horizontal bar with four coloured zones, labelled;
- a needle at the score, which animates to each new reading over 300 ms;
- the current zone name in bold, or "Signal unavailable" with no needle.

The pie and stacked chart use `fl_chart`:
- `PieChart` as a donut, with percentages on the segments and a legend.
- The stacked chart is a `LineChart` with three cumulative series (theta, theta + alpha, 100), filled with `betweenBarsData`. `fl_chart` has no native stacked area, and cumulative lines with between-fills draw the same thing.

The summary and history detail reuse the stacked chart and add two things: average rhythm shares, and time per zone (stat cards, keys `stat-zone-<name>`).

Colours stay consistent everywhere: theta, alpha and beta each have one colour (as in EEGWaves' rhythm colours), and the zones run from cool for relaxation to warm for concentration. These are defined once in `lib/ui/palette.dart`.

### D4. Data model: optional timeline fields and summary fields
- `TimelinePoint` gains `zone` (`FocusZone?`) and `rhythms` (`RhythmShares?`). Their JSON keys are `z` (zone name) and `r` (`[θ, α, β]` rounded to 0.1). Both are omitted when null, and both read back as null when missing, so old files load unchanged.
- `SessionSummary` gains:
  - `timeInZone` (`Map<FocusZone, Duration>`, empty for old sessions);
  - `averageRhythms` (`RhythmShares?`);
  - `hasRawRecording` (bool, default false).
- These are computed in `SessionRecorder.finish()`, excluding gaps and unavailable seconds, like the existing stats.

Timeline size grows from about 25 to about 45 bytes a second, roughly 240 KB for 90 minutes.

### D5. Export: folder picker plus a pure CSV builder
- **Builder:** `SessionCsv.timeline(SessionRecord)` returns the CSV text and is pure and unit-tested.
  - Header: `elapsed_s,time,focus_score,focus_state,scale_zone,theta_pct,alpha_pct,beta_pct,gap,feedback_mode,mark`
  - `time` is ISO 8601 local time (`startedAt + elapsed`).
  - Numbers are written with `.` as the decimal point and one decimal.
  - Unavailable cells are empty.
  - `mark` is `drop`, `recovery`, `gap_start` or `gap_end`; several marks in one second are joined with `;`.
  - Fields are RFC 4180-quoted where needed (none should need it).
- **Folder:** `file_selector`'s `getDirectoryPath()` asks for a folder, with the confirm button labelled "Export here". Writing both files needs the folder grant, because a save dialog grants only one file.
- **File names:**
  - `focused-mind_<yyyy-MM-dd_HH-mm>.csv` for the timeline;
  - `…_raw.csv` for the raw signal;
  - if a name is taken, `_2`, `_3`, … is appended (spec: never overwrite).
- **Writing:** an `ExportService` writes the files with `File.writeAsString`. The raw CSV is streamed with an `IOSink`, converting batches as it goes, so a long recording isn't held in memory. Errors become an `ExportResult.failed(message)`, and the history page shows a SnackBar with the folder path or the error.
- **Entitlements:** add `com.apple.security.files.user-selected.read-write` to the Debug and Release entitlements. No network entitlement.

Alternatives considered:
- A save dialog per file. The user would see two dialogs, and the second file can't silently go next to the first under the sandbox.
- A share sheet. That's macOS-only UI and less predictable for CSVs.
- A `csv` package dependency. The format here is fixed and trivial.

### D6. Raw recording: compact binary on disk, CSV only on export
- **Setting:** `record_raw_signal` (bool, default false) in `SettingsRepository`, separate from `FeedbackSettings`, because it isn't feedback. It's shown in Settings under "Data" with the text "Record raw signal: stores the full EEG of each session (about 20 MB per hour) so it can be exported."
- **Recorder:** `RawSignalRecorder` subscribes to `connection.samples` when tracking begins, only if the setting is on at session start.
  - It writes `<id>.raw.bin` next to the session files.
  - Each sample is a little-endian record of 5 × float32: seconds since tracking start, then O1, O2, T3 and T4 in volts. That is 20 bytes per sample, or about 18 MB per hour at 250 Hz.
  - Seconds come from a sample counter at the device sampling rate. The counter is re-anchored to wall time after each gap, so the timestamps show the gap.
  - It buffers in memory and flushes once per second with `RandomAccessFile.writeFrom`.
- **Lifecycle:**
  - On `end()`, it closes the file and the summary records `hasRawRecording`.
  - If tracking never began, it writes nothing.
  - `SessionRepository.delete` also removes `<id>.raw.bin`.
  - On load, the repository ignores a stray `.raw.bin` with no summary.
- **Export:** converts volts to microvolts with three decimals: `t_s,o1_uv,o2_uv,t3_uv,t4_uv`.

Alternatives considered:
- Writing CSV directly. About 2.5 times bigger, and slower to write at 250 Hz.
- Int16 samples. Dry-electrode offsets can exceed the range, and the absolute range isn't known until the hardware task.

### D7. Testing
- **Pure unit tests:**
  - zone mapping and boundaries for several baselines;
  - the rhythm average, EMA and renormalisation in the engine (fake estimator with set rhythm shares);
  - the CSV builder (header, empty cells, marks, old sessions);
  - the raw format round trip, and timestamps across a gap;
  - repository delete removing the raw file.
- **Widget tests:**
  - the gauge (zone label, needle position key, unavailable state);
  - the pie (percent labels) and the stacked chart present in the live view;
  - the summary zone cards;
  - history Export, with the folder picker behind an injectable `pickFolder` function, writing into a temp directory, plus cancel and failure paths;
  - the Settings toggle persisting.
- **End to end:** the simulated session on real EmotionalMath checks that rhythm shares appear and move the right way: more beta at high simulated focus, more alpha and theta at low focus.

## Risks / Trade-offs

- **[`readSpectralDataPercents()` may return nothing in some steps or before enough data]** → Treat as unavailable for that step, and keep the last value through the per-second average. A unit test on the real library with the simulator confirms values appear after calibration.
- **[The simulator's rhythm content is synthetic]** → The rhythm direction checks are coarse (beta share higher at high focus). Real proportions are checked with the band in the existing hardware task.
- **[Raw recording during a long session fills disk]** → Off by default, the cost is stated in Settings, and the session's delete removes it. A write error stops the raw recording (logged and shown once as a SnackBar) but never stops the session.
- **[Sandbox folder grant is per-pick]** → Each export asks for a folder. We don't store security-scoped bookmarks; that's simpler, and users expect to pick a folder each time.
- **[Live view gets busier]** → The header and charts scroll and the gauge stays pinned. The minimum window size is checked in the widget test at 800×600.
- **[fl_chart stacked emulation]** → Cumulative series must be monotonic, which holds by construction since the shares are ≥ 0. Gaps break all three series together.

## Migration Plan

- No data migration: new JSON fields are optional, and old sessions show and export without them.
- Adding the entitlement needs a rebuild only. Rollback is reverting the change; newer session files stay readable by the older code, because unknown JSON keys are ignored.
