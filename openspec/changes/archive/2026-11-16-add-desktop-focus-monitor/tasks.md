# Tasks

## 1. Project setup

- [x] 1.1 Add `.gitignore` (Flutter defaults plus `*.xapk`, `*.apk`) and verify `git status` no longer lists either reference `.xapk` (Muse, BrainBit Neurofeedback)
- [x] 1.2 Run `flutter create --platforms=macos --org <reverse-domain> --project-name focused_mind .` and verify `flutter run -d macos` opens an empty window
- [x] 1.3 Add dependencies:
  - runtime: `neurosdk2` (pinned; used only to ship the native binary), `em_st_artifacts`, `ffi`, `flutter_riverpod`, `just_audio`, `shared_preferences`, `path_provider`, `fl_chart`, `tray_manager`, `window_manager`
  - dev: `ffigen`, `fake_async`, `mocktail`

  Verify `flutter pub get` and `flutter build macos --debug` succeed, and that the built `.app` contains `libneurosdk2.dylib`.
- [ ] 1.4 Set the macOS deployment target to 10.15 or later. Add `com.apple.security.device.bluetooth` to `DebugProfile.entitlements` and `Release.entitlements`, and add `NSBluetoothAlwaysUsageDescription` to Info.plist. Verify the built app shows the macOS Bluetooth permission prompt on first scan.
- [x] 1.5 Create the folder layout `lib/{headband,focus,feedback,sessions,settings,ui}` and set up `flutter analyze` with `flutter_lints`. Verify analyze reports no issues.

## 2. neurosdk2 FFI binding and Mindo check (design D3)

- [x] 2.1 Vendor `sdk_api.h` and `cmn_type.h` from the pinned `neurosdk2` version into `third_party/neurosdk2/include/` (with a `VERSION` note). Add an `ffigen.yaml` limited to the design D3 function list, and generate `lib/headband/ffi/neurosdk2_bindings.dart`. Verify `dart run ffigen` is reproducible and `flutter analyze` is clean.
- [ ] 2.2 Add `NeuroSdkLibrary.open()`, which loads `libneurosdk2.dylib` and checks that every bound symbol resolves. Verify with a macOS integration test that it loads inside the built app, and that a missing symbol produces a clear error.
- [ ] 2.3 Write a throwaway debug screen on the FFI bindings. It scans with `[SensorLEHeadband, SensorLEBrainBit, SensorLEBrainBit2]` and prints each device's name, serial, `SensFamily` and `SensModel`. Verify against the real Mindo, and record the reported family (expected `SensorLEHeadband` = 11) and model in `docs/hardware.md`.
- [ ] 2.4 From the same screen, connect to Mindo through the callback shim (2.6).
  - Stream `HeadbandResistData` for 30 s, then `HeadbandSignalData` for 60 s, and save the signal to a CSV in the app support dir.
  - Verify the values are in the volt range at about 250 Hz (also check with `readSamplingFrequencySensor`).
  - Record the observed resistance ranges for good and poor contact in `docs/hardware.md`.
- [ ] 2.5 Feed the recorded CSV through `EmotionalMath` with the design D5 settings in a Dart test (`test/fixtures/mindo_sample.csv`). Verify calibration finishes and focus index values (`relAttention` − `relRelaxation`) come out. If Mindo reports an unexpected family or no data in 2.3–2.4, stop and escalate to the user before building groups 3+ on hardware (the simulator path still proceeds).

- [x] 2.6 Add the native callback shim (design D3): `native/fm_shim.cpp` built by `hook/build.dart`, bound in `lib/headband/ffi/fm_shim.dart`, copying Headband/BrainBit/BrainBit2 signal and resistance data into Dart-owned memory. Verify with unit tests that call the shim like the SDK and free the source buffer right after the call.

## 3. Headband connection (spec: headband-connection)

- [x] 3.1 Define the `HeadbandSource` interface, `EegSample`, `ContactQuality`, `ConnectionState` and `DeviceInfo` models. Verify they compile, with unit tests for the ohm→quality mapping (good <500 kΩ, fair <2 MΩ, poor otherwise or infinite).
- [x] 3.2 Implement `SimulatedHeadbandSource`: synthetic 4-channel EEG with controllable alpha/beta mix (focus level), contact quality, battery and forced disconnects. Verify with unit tests that the sample rate is 250 Hz and that setting focus high or low shifts `relAttention` in the matching direction through `EmotionalMath`.
- [ ] 3.3 Implement `NeuroSdkHeadbandSource` on the FFI bindings, behind a thin `NeuroSdkApi` wrapper so it can be faked.
  - Scan with a 15 s timeout; connect with a 60 s timeout (Mindo may need several createSensor attempts).
  - Pick Headband, BrainBit or BrainBit2 signal/resist callbacks by the reported `SensFamily`.
  - Switch between resist and signal modes via `execCommandSensor`.
  - Battery via `addBatteryCallback`; connection state via `addConnectionStateCallback`.
  - Close callables and free the native objects on dispose.

  Verify with unit tests on a fake `NeuroSdkApi` (family dispatch, timeouts, dispose), and manually with Mindo that scan, connect, contact quality and battery all appear. Log the result in `docs/hardware.md`.
- [x] 3.4 Implement the reconnection policy (retry every 5 s for 60 s, then disconnected with a notification). Verify with `fake_async` unit tests for "brief signal loss" and "headband gone" using a fake SDK wrapper.
- [ ] 3.5 Detect Bluetooth off or permission denied and expose an actionable error. Verify by denying Bluetooth for the app in System Settings: the app shows the guidance message instead of scanning.
- [ ] 3.6 Persist the last connected device and offer one-click connect on launch. Verify with a unit test on the settings repository and manually by relaunching the app.
- [x] 3.7 Build the Connect screen: scan list, connection state, per-electrode contact quality, battery with a ≤15% warning, and the simulated-device option in debug builds only. Verify with widget tests using `SimulatedHeadbandSource`.

## 4. Focus tracking (spec: focus-tracking)

- [ ] 4.1 Define the `FocusEstimator` interface and an `EmotionalMathEstimator` that builds the T3−O1 and T4−O2 bipolars, pushes in batches every 100 ms, and exposes calibration percent, `relAttention`, `relRelaxation` (the focus index) and artifact flags. Verify with a unit test on the 2.5 fixture.
- [x] 4.2 Implement `FocusEngine`: 1 Hz score publishing, an EMA with τ≈3 s, `unavailable` during artifacts with the EMA held, and per-side signal quality. Verify with unit tests for one outlier reading (dampened), artifact → unavailable → resume within 3 s, and the update rate.
- [x] 4.3 Implement the calibration flow: a gate that needs every electrode at fair or better, a 6 s calibration with progress, and failure after 60 s with a reason and restart. Verify with `fake_async` tests for the success, poor-contact-blocks and disturbed-fails scenarios.
- [x] 4.4 Implement `FocusStateMachine` (distracted < T ≤ neutral < T+15 ≤ focused). Verify with table-driven unit tests, including a threshold change taking effect on the next update.
- [x] 4.5 Add a first-launch wellness notice ("estimate, not medical") and the same wording in the About screen. Verify with a widget test that it appears only on first launch.

- [x] 4.6 Implement the baseline-centred score scale (design D5): the engine smooths the focus index and maps it with `ScoreScale` (calibration level = baseline, default 50); add the baseline (20–80) to settings and the Settings screen, applied mid-session. Verify with unit tests for the scale, a session test for a mid-session baseline change, a widget test for the slider, and the end-to-end simulated session with the default threshold.

## 5. Audio feedback (spec: focus-audio-feedback)

- [ ] 5.1 Add CC0 or royalty-free loopable `birds.m4a`, `ocean.m4a` and `end_chime.m4a` under `assets/sounds/`, with sources and licenses in `assets/sounds/LICENSES.md`. Verify each loops without an audible gap with `just_audio` on macOS.
- [ ] 5.2 Define the `AudioOutput` interface and a `JustAudioOutput` implementation with play/loop, stop and volume stepping every 50 ms for 2 s fades. Verify manually with a debug button that fades are smooth.
- [x] 5.3 Implement `DropTracker`: a drop after `distracted` has lasted the trigger delay, a recovery after `focused` has lasted 3 s, with neutral and unavailable leaving it unchanged. Verify with `fake_async` unit tests for sustained drop, momentary dip, neutral hold and unavailable hold.
- [x] 5.4 Implement the design D6a gain policy as a pure function:
  - Alert mode: silent with no drop; deficit-scaled while a drop is active.
  - Continuous mode: focus-scaled with no drop; silent while a drop is active.
  - Overrides: muted, or more than 10 s unavailable, gives 0.

  Verify with table-driven unit tests covering every alert, continuous, mute and unavailable scenario in the focus-audio-feedback spec.
- [x] 5.5 Implement `FeedbackController`, which combines `DropTracker` and the gain policy, applies 2 s ramps to `AudioOutput`, handles a mode switch mid-session by re-targeting the ramp, and pauses the player after 5 s at zero gain. Verify with `fake_async` tests with a fake `AudioOutput` that check ramp timing in both modes and on a mid-session mode switch.
- [x] 5.6 Add a feedback settings repository and screen: feedback mode (Alert by default, or Continuous) with a one-line description of each, soundscape picker with preview, volume, threshold 0–100 (default 40) and trigger delay 3–30 s (default 5). Verify with widget tests that changes persist across restarts and apply mid-session.

## 6. Sessions (spec: focus-sessions)

- [x] 6.1 Implement `SessionController` with these states: idle, signal check, calibrating, running, paused (disconnected), ended. Support planned durations of 25, 50 or 90 minutes or open-ended, play the end chime, and stop feedback on end. Verify with `fake_async` unit tests for start-blocked-without-device, planned duration elapsing, and a 20 s disconnect pausing and resuming without recalibration.
- [x] 6.2 Implement `SessionRecorder`, fed by `DropTracker`: a 1 Hz timeline of score, state, feedback mode and drop, recovery and gap marks, plus summary stats (duration, average, time per state, drops, recoveries, longest focused stretch) that exclude gaps. Verify with unit tests, including a scripted session with 2 drops and 2 recoveries.
- [x] 6.3 Implement `SessionRepository`: one JSON file per session in the app support dir, a header-only history list (newest first), and delete. Verify with unit tests using a temp directory, including a round trip of summary and timeline.
- [x] 6.4 Build the live session view: score, state, an `fl_chart` graph growing at 1 Hz, elapsed and remaining time, connection, per-side signal quality, the feedback mode, and a feedback playing/muted indicator with a mute button. Verify with a widget test driven by `SimulatedHeadbandSource`.
- [x] 6.5 Build the summary screen and the history list with an open/delete confirmation. Verify with widget tests that a past session shows its saved stats and graph and that delete removes it.
- [ ] 6.6 Add the menu bar indicator with `tray_manager` (state and score, Open, Mute, End session) and hide-to-tray with `window_manager`. Verify manually: hide the window mid-session, then mute and end from the menu bar.
- [ ] 6.7 Confirm no network entitlement or networking dependency is present. Verify that `com.apple.security.network.client` is absent from the entitlements and that a full simulated session works with Wi-Fi off.

## 7. Integration and docs

- [x] 7.1 Add an integration test (`integration_test/`) that runs a full simulated session in each feedback mode. In alert mode, a forced focus drop starts the sound and a recovery stops it. In continuous mode, the sound plays while focused, goes silent on the drop and returns on recovery. In both, end the session and check the summary appears in history. Verify `flutter test integration_test -d macos` passes.
- [ ] 7.2 Run a 25-minute real session with the Mindo band, and record in `docs/hardware.md` the false-alarm rate and the tuned threshold, EMA and resistance defaults. Verify defaults are updated in code if they changed.
- [ ] 7.3 Write `README.md` covering setup (Flutter version, `flutter run -d macos`), hardware pairing tips, the simulator, and the privacy/wellness note. Verify a clean clone builds by following it.
