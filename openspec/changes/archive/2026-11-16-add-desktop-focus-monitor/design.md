# Design

## Context

The repository is empty apart from a Muse app package (`.xapk`) kept as UX reference. See proposal.md for motivation and specs/ for required behavior.

What we know about the vendor stack (checked 2026-11-11):

- **`neurosdk2` (pub.dev 1.0.21, MIT, prebuilt binaries)**: the device SDK for Flutter. Supports Android, iOS, macOS (a bundled `libneurosdk2.dylib`, macOS 10.14+) and Windows. Needs Dart ≥ 3.4.3 and Flutter ≥ 3.22.
  - Flow: `Scanner.create([FSensorFamily...])`, then `sensorsStream`, then `createSensor(info)`, which blocks while it connects.
  - Streams: `signalDataStream` (o1, o2, t3, t4 in volts at 250 Hz), `resistDataStream`, `batteryPowerStream`, `sensorStateStream`.
  - The SDK does not reconnect on its own.
- **`em_st_artifacts` (1.0.4, MIT, FFI, macOS supported)**: the `EmotionalMath` class.
  - Input: bipolar channels, left = T3−O1 and right = T4−O2, at 250 Hz. Filters are built in.
  - Optional calibration (`setCalibrationLength`, `getCalibrationPercents`).
  - Output: `readMentalData()` returns `MindData` with `relAttention` and `instAttention` in percent. `relAttention` is relative to the calibration baseline.
  - Artifact flags: `isBothSidesArtefacted`, `isArtifactedSequence`, `isArtifactedLeft` and `isArtifactedRight`.
- **Mindo band**: 4 dry electrodes at O1, O2, T3 and T4, 250 Hz, BLE. It is not listed in any SDK device table.
- **BrainBit Neurofeedback 1.3.5 (vendor app, reference)**: a Unity/IL2CPP app that bundles `libneurosdk2`, `libem_st_artifacts`, `libspectrumlib` and `libfilters`. Its C# layer has a dedicated Headband path: `HeadbandSDK.cs`, `IHeadbandSensor`, `SensorLEHeadband`, `addSignalDataCallbackHeadband`, `addResistCallbackHeadband` and `HEADBAND_WARNING_RESISTANCE`. That is how it talks to Mindo.
  - Per device it feeds the signal into two maths channels: "Emotional", which is `EmotionalMath` in bipolar mode with a side-priority choice, and "Neurro", which is Welch-spectrum based with individual-alpha calibration methods.
  - Its soundscape and media settings carry `ValueCorrelation` (Forward or Backward), `ValueMultiplayer`, `MinValue`/`MaxValue` and `IsLooping`. In other words, sound loudness is mapped from the brain value either directly or inversely.
- **Headband in the SDK**:
  - The C API (`sdk_api.h` / `cmn_type.h`) defines `SensorLEHeadband = 11`, `HeadbandSignalData {PackNum, Marker, O1, O2, T3, T4}` and `HeadbandResistData {PackNum, O1, O2, T3, T4}`, plus `addSignalDataCallbackHeadband` and `addResistCallbackHeadband`.
  - The macOS `libneurosdk2.dylib` bundled in the `neurosdk2` Flutter package (universal x86_64/arm64) exports these as plain C symbols, along with `createScanner`, `sensorsScanner`, `createSensor`, `connectSensor`, `execCommandSensor` and `addBatteryCallback`.
  - The package's Dart API does not expose Headband (`FSensorFamily` has no `leHeadband`). Its Android Java and Darwin Obj-C layers do have `Headband` classes.
- **Muse app (reference)**: calibration first; states active, neutral and calm; birds for attention sustained more than 5 s; "recoveries" counted when focus returns; a session graph and review afterwards. We reuse these ideas, but with the opposite trigger: our sound plays when focus is low.

## Goals / Non-Goals

**Goals:**
- One Flutter codebase where everything except the platform runner is reusable on Android and iOS.
- Keep the focus and feedback logic pure Dart and hardware-free, so the simulator and unit tests can exercise it.
- Connect to Mindo the way the vendor app does: neurosdk2's Headband device type through the C API.

**Non-Goals:**
- Shipping Android or iOS builds, our own EEG signal processing, cloud sync, or Windows/Linux packaging. (The SDK supports Windows, but it isn't tested.)

## Decisions

### D1. Flutter app at the repository root, macOS target only for now
`flutter create --platforms=macos` with the package name `focused_mind`. Android and iOS are added later with `flutter create --platforms=android,ios .`.
Alternatives: SwiftUI covers macOS and iOS but not Android; Python with `pyneurosdk2` would be thrown away for mobile.

### D2. Layered architecture with a `HeadbandSource` interface

```
HeadbandSource (NeuroSdkHeadbandSource | SimulatedHeadbandSource)
  └─> FocusEngine (wraps EmotionalMath behind FocusEstimator interface)
        └─> FocusStateMachine (smoothing + threshold + hysteresis, pure Dart)
              ├─> DropTracker (drops/recoveries, mode-independent)
              │     ├─> FeedbackController (mode policy, fades, intensity → AudioOutput)
              │     └─> SessionRecorder (timeline, stats → SessionRepository)
```

`HeadbandSource` exposes:
- connection state
- the device list from a scan
- a contact-quality stream
- a stream of `EegSample(o1, o2, t3, t4)` at 250 Hz
- battery level

Both the vendor SDK and the audio player sit behind interfaces, so the bottom three layers can be tested with fakes and fake time (`fake_async`).

State management uses `flutter_riverpod`, because it gives us testable providers without a widget tree.
Alternative considered: bloc, which adds more boilerplate for the same result.

### D3. Device layer: our own Dart FFI binding to the neurosdk2 C API (vendor-app method)
We follow the BrainBit Neurofeedback app, which reaches Mindo through the C API's Headband functions, and do the same from Dart:

- **Bindings:** `lib/headband/ffi/neurosdk2_bindings.dart` is generated with `ffigen` from the vendor headers `sdk_api.h` and `cmn_type.h`. The headers are vendored under `third_party/neurosdk2/include/` with their version noted. The bindings are trimmed to:
  - scanner: create, start, stop, sensors, free
  - sensor: create, connect, disconnect, free, execCommand
  - callbacks: connection state (`addConnectionStateCallback`) and battery
  - Headband signal and resistance callbacks
  - BrainBit and BrainBit2 signal and resistance callbacks
- **Native library:** we load the `libneurosdk2.dylib` that the `neurosdk2` Flutter plugin already bundles and signs into the app (`DynamicLibrary.open('libneurosdk2.dylib')`). The plugin stays a dependency only to ship the binary on each platform; we don't use its Dart API.
- **Callbacks:** the native side calls back on SDK threads, and for signal data it passes a pointer to a buffer it frees as soon as the callback returns. `NativeCallable.listener` posts each call to the Dart isolate and runs it later, after that buffer is gone, so it is safe only for by-value data:
  - Battery and connection state (plain ints) use `NativeCallable.listener` directly.
  - Signal and resistance go through a small C++ shim, `native/fm_shim.cpp`, built by a native-assets build hook (`hook/build.dart`, `native_toolchain_c`) and bound with `@Native` in `lib/headband/ffi/fm_shim.dart`. The shim's `fm_*` functions are registered as the SDK callbacks. Each copies the batch into a malloc'd array of doubles (O1, O2, T3, T4 per sample; ohms for resistance) and posts it to a `NativeCallable.listener` passed as the SDK's `userData`. Dart copies the array into a `Float64List` and frees it with `fm_free`.
  - The shim compiles against the vendored headers, so its struct layouts match the SDK. Unit tests call the `fm_*` functions the way the SDK does and free the source buffer straight after the call.
  - Alternatives considered: the experimental `NativeCallable.isolateGroupBound` (synchronous on the SDK thread, no C code, but not stable yet), and a Swift platform channel (macOS only).
- **Blocking calls:** `createSensor` and `connectSensor` block while they connect, so they run on a helper isolate (`Isolate.run`), passing native pointers as addresses. While scanning, the device list is polled with `sensorsScanner` every 500 ms rather than through the scanner's pointer-based callback.
- **Fakeable layer:** `NeuroSdkApi`/`NeuroSensor` (`lib/headband/neurosdk_api.dart`) hide the FFI. `FfiNeuroSdkApi` implements them, and `NeuroSdkHeadbandSource` maps them to `HeadbandSource`. The library is loaded on first scan or connect, and a load failure surfaces as a scan error.
- **`NeuroSdkHeadbandSource`:**
  - scans with filters `[SensorLEHeadband, SensorLEBrainBit, SensorLEBrainBit2]`
  - chooses the signal and resistance callbacks by the `SensFamily` the device reports
  - maps everything to `EegSample(o1, o2, t3, t4)` and per-electrode ohms

  Headband is the primary path; BrainBit and BrainBit 2 come for free.
- **Hardware check:** the first task with the real band confirms that Mindo reports `SensorLEHeadband` and that signal and resistance arrive. If it reports another family, the adapter already covers BrainBit and BrainBit 2. The simulator lets the rest of the work carry on in parallel.

Alternatives:
- Fork the Flutter plugin to add Headband to its Dart API. That is more code to maintain, and it would drift from upstream.
- Write a Swift platform channel around `NTHeadband`. That is macOS-only, and Android would need a second implementation.

FFI against the C API reuses the same Dart code on Android (`libneurosdk2.so`) and iOS (the xcframework).

### D4. Contact quality: resistance before the session, artifact flags during it
The SDK can't stream resistance and signal at the same time.

- **Before the session:** the pre-session signal check sends `CommandStartResist` and reads the per-electrode ohms from `HeadbandResistData`. It maps ohms to quality levels: good below 500 kΩ, fair below 2 MΩ, poor otherwise (infinity counts as poor). These thresholds get tuned in the spike. The vendor app has its own `HEADBAND_WARNING_RESISTANCE` threshold; its value isn't readable from the metadata.
- **During the session:** we switch to `startSignal`, and per-side quality comes from `isArtifactedLeft` and `isArtifactedRight` (see the spec requirement "Signal quality during a session").

### D5. Focus score = EmotionalMath's calibration-relative index on a baseline-centred scale

Configuration, from the vendor's README defaults:
- samplingRate 250, processWinFreq 25, fftWindow 1000, nFirstSecSkipped 4
- bipolarMode on, 50 Hz notch (EU mains; this becomes a setting later)
- calibration length 6 s; the spec allows up to 60 s, which leaves room for the artifact retries

Processing:
- Samples are pushed in batches of about 25 every 100 ms, followed by `processData()`.
- `relAttention` is above 0 only when the wearer is more focused than at calibration, and `relRelaxation` only when they are less focused; both are percentages without an upper bound. Their difference is the **focus index**: 0 at the calibration level, positive when more focused, negative when less.
- The per-second index is clamped to ±150 and fed into an exponential moving average with a time constant of about 3 s.
- The smoothed index is mapped to the 0–100 score with a saturating scale (`ScoreScale`): the calibration level gets the user's **baseline** B (default 50, adjustable 20–80 in Settings), and `score = B + (100 − B)·tanh(index/50)` above it, `B + B·tanh(index/50)` below it. With the default threshold of 40, "distracted" therefore means "clearly below your own calibrated level".
- Raising the baseline makes every reading score higher (fewer alerts); lowering it makes feedback stricter. A baseline change applies from the next published score, because the mapping runs after the smoothing.
- The score is published at 1 Hz, which meets the "at least once per second" requirement.
- While `isArtifactedSequence()` or `isBothSidesArtefacted()` is true, the score is `unavailable`, and the EMA is held rather than reset, so it resumes in under 3 s.

Alternatives considered:
- `instAttention`, which needs no calibration but is noisier and not personalized.
- Our own beta/(alpha+theta) ratio from `spectrum_lib`, which means more DSP for us to own.

`FocusEstimator` is an interface, so either can be swapped in later. The vendor app's "Neurro" spectral channel would be a third option if `relAttention` proves poor on Mindo.

Rejected: using `relAttention` directly as the score. It reads about 0 at the calibration level, so with a threshold of 40 the wearer would count as distracted at their normal level and alert mode would play almost constantly.

### D6. Focus state machine (pure function of score history + settings)
- `distracted`: score below the threshold T.
- `focused`: score of at least T + 15.
- `neutral`: anything in between.

`DropTracker` adds the timing, the same for both modes:
- A drop becomes active after `distracted` has lasted the trigger delay (default 5 s).
- It ends with a recovery after `focused` has lasted 3 s.
- `neutral` and `unavailable` don't change it.

Because the start and stop conditions use different states, the drop doesn't flicker on and off at the threshold. Both the feedback controller and the session recorder consume `DropTracker`, so the summary counts are identical in either mode.

### D6a. Feedback mode policy (vendor app's Forward/Backward correlation)
`FeedbackController` turns (drop active?, score, unavailable duration, mode, muted) into a target gain. A 2 s ramp then moves the actual gain toward that target. With T = threshold and V = user volume:

| Mode | No drop active | Drop active |
|---|---|---|
| Alert | 0 | `V × clamp(0.4 + 0.6 × (T − score)/T, 0.4, 1)` |
| Continuous | `V × clamp(0.4 + 0.6 × (score − T)/(100 − T), 0.4, 1)` | 0 |

Overrides:
- Muted, or the score unavailable for more than 10 s, sets the target to 0.
- Switching mode only changes the target, so the 2 s ramp handles the transition.

This mirrors the vendor app's `ValueCorrelation` Forward/Backward idea. The policy is a pure function, unit-tested with a table per spec scenario.

### D7. Audio via `just_audio` with looping assets and software fades
`just_audio` supports macOS through AVFoundation and handles gapless loops.
- Assets are 1–2 minute loopable `.m4a` files, `assets/sounds/birds.m4a` and `assets/sounds/ocean.m4a`, from a CC0 or royalty-free source. The license is recorded in `assets/sounds/LICENSES.md`.
- The player loops continuously during a session, and the D6a target gain is applied by stepping `setVolume` every 50 ms. The player is paused only while the gain stays at 0 for more than 5 s, to save CPU.
- The end chime is a short asset as well.

Alternative: `audioplayers`, which has weaker gapless looping.

### D8. Local persistence
- **Settings** (feedback mode, soundscape, volume, threshold, baseline, trigger delay, last device serial/address/family): `shared_preferences`.
- **Sessions:** one JSON file per session under the app support directory (`path_provider`). Each holds the summary plus a 1 Hz timeline of score, state and marks for feedback, recovery and gap. A 90-minute session is about 5,400 points, roughly 150 KB.
- The history list reads only the summary headers.
- No networking packages are added. To support the "Data stays on the device" requirement, the macOS entitlements omit `com.apple.security.network.client`.

Alternative: SQLite with `drift`, which is not needed at this data size and can be migrated to later.

### D9. macOS shell
- **Menu bar:** `tray_manager` shows the state glyph and score, with Open, Mute and End session actions. `window_manager` handles hiding the window.
- **Entitlements:** `com.apple.security.app-sandbox` and `com.apple.security.device.bluetooth`.
- **Info.plist:** `NSBluetoothAlwaysUsageDescription`.
- **Charts:** `fl_chart`.

### D10. Reconnection policy
When the sensor-state callback (`addConnectionStateCallback` via FFI) reports a disconnect during or outside a session:
- The source moves to `reconnecting` and calls `connect()` every 5 s for 60 s.
- If that fails, it moves to `disconnected`, disposes the sensor and shows a notification.
- During a session, the recorder pauses the timer and marks the gap.
- If the reconnect succeeds within 60 s, the `EmotionalMath` instance is kept, so no recalibration is needed. Its artifact handling absorbs the restart.

## Risks / Trade-offs

- **[Mindo identified as Headband only from vendor-app reverse inspection]** → The first hardware task confirms the reported family. The adapter also handles BrainBit and BrainBit 2. The simulator unblocks the rest of the work.
- **[Our FFI binding vs. the C API's evolution]** → Pin the `neurosdk2` plugin version and vendor the matching headers. A smoke test checks that the symbols resolve at startup and shows a clear error if one doesn't.
- **[FFI callback lifetime/threading]** → Pointer data is copied by the C++ shim on the SDK thread before the SDK frees it; only by-value data uses `NativeCallable.listener` directly. Callbacks are removed before the callables are closed. Unit-test the shim with freed source buffers and the source with a fake `NeuroSdkApi`, and test the real binding manually with the band.
- **[Loading neurosdk2 outside the app]** → Loading the dylib in the `flutter test` host blocks in its Bluetooth start-up and can trip Gatekeeper, so tests never load it: the symbol check runs `nm` on the bundled binary, and the app loads it only on first scan.
- **[The plugin's own native init conflicting with direct FFI use]** → We never call the plugin's Dart API, so its native side stays idle. If loading the library twice causes problems, vendor the dylib directly into the macOS runner instead.
- **[Closed-source binaries labeled MIT; unclear vendor terms]** → Confirm redistribution terms with BrainBit before any public release. This doesn't block development.
- **[`relAttention` may not track the subjective feeling of focus]** → Show the raw score in a debug overlay. Make the threshold and baseline user-adjustable. Spend the spike's real-use sessions tuning the EMA, the scale's span (50) and the defaults.
- **[Dry electrodes on hair at O1/O2 give a noisy signal]** → Guide the user in the signal check. Treat artifacts as "unavailable" rather than "low focus" so false alarms don't happen.
- **[FFI processing on the UI isolate]** → The load is small (250 Hz × 4 channels). If profiling shows frame drops, move the engine to a background isolate.
- **[Sandboxed BLE quirks on macOS]** → Verify in the spike with a signed debug build, not only `flutter run`.

## Migration Plan

This is a greenfield project with nothing to migrate.
- Add `*.xapk` to `.gitignore`, so the two reference packages (about 120 MB each) never get committed.
- Mobile later: add the platform runners, request Android BLE permissions at runtime, add the iOS Info.plist keys. Replace `tray_manager` with an ongoing notification on Android and a Live Activity on iOS. Run audio as a foreground service on Android and in background audio mode on iOS.

## Open Questions

- The final resistance thresholds, EMA time constant and score-scale span depend on real Mindo data. They are tuned in the spike and don't change the specs.
- The exact royalty-free sound sources are picked during implementation, provided the license allows redistribution.
