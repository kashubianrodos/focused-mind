# Tasks

## 1. Focus zones and scale gauge (spec: focus-scale, design D1, D3)

- [x] 1.1 Add `FocusZone` (deep relaxation, relaxation, concentration, deep concentration) with labels. Add `ScoreScale.zoneOf(score)` and `zoneBoundaries` using index bands at ±1 span. Verify with unit tests that the boundaries are 12/50/88 at baseline 50 and move with baseline 30 and 70, that the calibration level sits on the Relaxation/Concentration boundary, and that zones never decrease as the score rises.
- [x] 1.2 Add `lib/ui/palette.dart` with the zone and rhythm colours. Build `FocusScaleGauge`: a `CustomPainter` with four labelled zones, a needle animating to the score over 300 ms, the current zone name, and "Signal unavailable" with no needle when the score is null. Verify with widget tests for the zone label, needle position (via a keyed semantics value), the unavailable state, and a baseline change moving the boundaries.

## 2. Rhythm shares (spec: brain-rhythms, design D2)

- [x] 2.1 Add `RhythmShares` (theta, alpha, beta, summing to 100; JSON as `[θ, α, β]`). `EmotionalMathEstimator` reads `readSpectralDataPercents()` after calibration and returns the last entry renormalised, or null if there is none or the total is 0. Verify with a unit test on the real library and the simulator that shares appear after calibration and add up to 100, and that the beta share is higher at simulated focus 0.9 than at 0.1.
- [x] 2.2 Extend `FocusEngine` to average rhythm shares per second over clean steps, smooth each with the score's EMA (held while unavailable), renormalise, and publish `FocusReading.rhythms`. Extend `FakeEstimator` with settable shares. Verify with unit tests that shares sum to 100, are null while the score is unavailable, resume without reset after artifacts, and that an outlier second is dampened.

## 3. Recording zones and rhythms (specs: focus-scale, brain-rhythms, design D4)

- [x] 3.1 Add optional `zone` and `rhythms` to `TimelinePoint` (JSON keys `z` and `r`, omitted when null), and `timeInZone`, `averageRhythms` and `hasRawRecording` to `SessionSummary` (missing means empty/null/false). Verify with unit tests that the new fields round-trip, and that a timeline and summary in the pre-change format load with the new fields empty.
- [x] 3.2 Make `SessionRecorder` record the zone (with the baseline in force at that second) and the rhythms per point, and compute `timeInZone` and `averageRhythms` excluding gaps and unavailable seconds. `SessionController` passes the reading's rhythms and the current scale. Verify with a scripted recorder test (known zones and shares, including a gap) and a session controller test where, after a mid-session baseline change, each recorded zone matches its score under the new scale (the same brain activity stays in the same zone, design D1).

## 4. Live view, summary and history views (specs: focus-scale, brain-rhythms, design D3)

- [x] 4.1 Build `RhythmPie` (an `fl_chart` donut with percent labels and a legend, plus an unavailable state) and `RhythmStackedChart` (cumulative series with `betweenBarsData`, breaks at gaps and unavailable seconds, the same x range as the focus chart). Verify with widget tests that the pie shows the three percentages, the unavailable state shows no segments, and the chart has three filled layers that break at a gap.
- [x] 4.2 Restructure `LiveSessionView`: a scrollable body (header with score, state, time and the pie; focus chart; stacked rhythm chart; status rows) and `FocusScaleGauge` pinned at the bottom. Verify with a widget test driven by the fake estimator at 800×600 that the gauge stays visible at the bottom after scrolling, and that the pie, stacked chart and gauge update on the next reading.
- [x] 4.3 Extend the summary and history detail with time-in-zone stat cards (`stat-zone-<name>`), average rhythm shares and the stacked rhythm chart; omit the rhythm views for sessions without rhythm data. Verify with widget tests for a new session and for a pre-change session loaded from JSON.

## 5. Export and raw recording (spec: session-export, design D5, D6)

- [x] 5.1 Implement `SessionCsv.timeline(SessionRecord)` with the D5 header, ISO local time, one decimal, empty cells for unavailable values and `;`-joined marks. Verify with unit tests: a scripted session with a gap, drop and recovery (row count = seconds, the expected cells), and a pre-change session (same columns, empty rhythm and zone cells).
- [x] 5.2 Add the `record_raw_signal` setting to `SettingsRepository` and a "Data" section on the Settings screen with the toggle and its storage note. Verify with a widget test that it defaults to off and persists across restarts.
- [x] 5.3 Implement `RawSignalRecorder`:
  - the D6 binary format: little-endian float32 × 5, flushed every second;
  - a sample counter re-anchored after gaps;
  - start on tracking only if the setting is on, close on end;
  - a write error stops recording without stopping the session.
  
  Wire it into `SessionController`, set `hasRawRecording`, and make `SessionRepository.delete` remove `<id>.raw.bin`. Verify with `fake_async` tests: setting off writes nothing; setting on writes 250 records per second; timestamps jump across a 20 s gap; delete removes the file; a simulated write failure leaves the session running.
- [x] 5.4 Implement `SessionCsv.rawSignal` streaming from `<id>.raw.bin` to an `IOSink` (`t_s,o1_uv,o2_uv,t3_uv,t4_uv`, volts → µV with three decimals). Verify with a round-trip unit test on a generated file, including a gap.
- [x] 5.5 Add `file_selector` and the `com.apple.security.files.user-selected.read-write` entitlement (Debug and Release). Implement an `ExportService` with an injectable folder picker:
  - `focused-mind_<yyyy-MM-dd_HH-mm>.csv` plus `_raw.csv` when the session has a raw recording;
  - `_2`, `_3`, … appended rather than overwriting;
  - results are success with the folder path, cancelled, or failed with a message.
  
  Verify with unit tests into a temp directory: names, no overwrite, both files when raw exists, cancel writes nothing, and an unwritable folder gives a failure.
- [x] 5.6 Add the Export action to each history entry (and the history detail), with a SnackBar for the saved folder or the error and a raw-recording badge on entries that have one. Verify with widget tests using a fake picker (success, cancel and failure), and manually in the built app that the folder picker opens and the files land in the chosen folder.

## 6. Integration and docs

- [x] 6.1 Extend the simulated end-to-end scenario (host test on real EmotionalMath, and `integration_test` on macOS) to check that rhythm shares and zones are recorded, that the zone reaches Concentration or Deep concentration at high simulated focus and Relaxation or below at low focus, and that exporting the saved session writes a CSV whose row count matches the session length. Verify `flutter test` and `flutter test integration_test -d macos` pass.
- [x] 6.2 Update `README.md` (scale zones, rhythm views, Export and raw recording with its storage cost) and `docs/hardware.md` (check rhythm proportions on real Mindo data, and record whether the ±1-span zone bands feel right). Verify `flutter analyze` is clean and the README matches the Settings and history screens.

## Workflow follow-up

- Archive `add-desktop-focus-monitor` before archiving this change, so these capabilities sit next to its `focus-tracking` and `focus-sessions` specs.
