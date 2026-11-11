# Focused Mind

A macOS app that helps you stay focused while you work. It reads EEG from a
BrainBit-family headband (developed against the **Mindo** band), estimates
your focus in real time and plays a soundscape (birds or ocean) as feedback:

- **Alert** mode (default): quiet while you are focused; the sound fades in
  when your focus drops and fades out when you are back.
- **Continuous** mode: the sound plays while you are focused, louder the more
  focused you are, and goes quiet when your focus drops.

Sessions (25/50/90 minutes or open-ended) show a live focus graph, a menu bar
indicator, an end-of-session summary and a local history.

During a session the live view also shows, as in BrainBit's EEGWaves app:

- **Focus scale**, a gauge pinned to the bottom of the window, with four
  zones: Deep relaxation, Relaxation, Concentration and Deep concentration.
  The needle is the focus score. Your calibrated level sits on the
  Relaxation/Concentration boundary (the baseline, 50 by default), and the
  "deep" zones start well away from it (below 12 and above 88 at baseline
  50).
- **Brain rhythms**: a pie of the current theta, alpha and beta shares, and a
  stacked chart of them over the session.

The summary adds time per scale zone, average rhythm shares and the rhythm
chart. Sessions recorded before these existed still open without them.

### Export

In **History**, the share button on a session (or **Export** in its detail
view) asks for a folder and writes `focused-mind_<date>_<time>.csv`. That
file has one row per second: time, focus score, state, scale zone, theta,
alpha and beta %, gaps, feedback mode, and drop/recovery marks. Existing
files are never overwritten (`_2`, `_3`, … is appended).

**Settings › Data › Record raw signal** (off by default) also keeps the full
250 Hz O1/O2/T3/T4 EEG of each new session, about 20 MB per hour. Export
then writes a second file, `…_raw.csv`, in microvolts. Deleting a session
deletes its recording. Android and iPhone
are planned on the same Flutter codebase.

> The focus score is an estimate for personal, wellness use only. Focused
> Mind is not a medical device. All data stays on your Mac.

## Requirements

- macOS 12 or later
- Flutter 3.47+ (Dart 3.13+): `brew install --cask flutter`
- Xcode (full install from the App Store), then
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` and
  `sudo xcodebuild -runFirstLaunch`
- CocoaPods: `brew install cocoapods`

Check with `flutter doctor` (the macOS/Xcode line must be green).

## Run

```sh
flutter pub get
flutter run -d macos
```

Debug builds offer a **Simulated headband** in the scan list, so the whole app
(calibration, focus score, feedback, sessions) works without hardware.

## Tests

```sh
flutter analyze
flutter test                          # unit + widget + host end-to-end tests
flutter test integration_test -d macos  # full simulated sessions in the built app
```

Host tests load BrainBit's prebuilt `libEmStArtifacts.dylib` from the pub
cache, so the focus maths in the tests is the real vendor library.

## CI and releases

`.github/workflows/macos.yml` runs on GitHub's macOS runners:

- **Every push to `main` and every pull request:** `flutter analyze` and
  `flutter test`, then a release build packaged as a DMG. The DMG is
  attached to the run as an artifact.
- **A tag starting with `v`** (for example `git tag v0.1.0 && git push
  origin v0.1.0`) also publishes a GitHub release with
  `FocusedMind-<version>.dmg`. The version comes from the tag. Tags with a
  `-`, such as `v0.2.0-beta.1`, are marked as pre-releases.

Without signing secrets the app is ad-hoc signed. macOS then blocks the
first launch: right-click the app and choose **Open**, or allow it in
System Settings › Privacy & Security. To ship a signed and notarized DMG,
add these repository secrets:

| Secret | What |
|---|---|
| `MACOS_CERTIFICATE_P12` | Developer ID Application certificate and key, exported as .p12, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PASSWORD` | Password of that .p12 |
| `MACOS_SIGNING_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_SPECIFIC_PASSWORD` | For notarization (`notarytool`); app-specific password from appleid.apple.com |

## Headband

- Switch the band on and keep it close to the Mac, then use **Scan** on the
  Focus page. The last band you connected is offered as one-click connect.
- Before each session the app checks electrode contact (O1/O2 at the back,
  T3/T4 at the temples). Move hair aside under any electrode shown as poor.
- Calibration takes about 10 seconds: sit still with your eyes open. The
  focus score is relative to that calibrated level, which scores the
  **Baseline** (50 by default). If feedback marks you as distracted too
  often, raise the baseline in Settings; lower it for stricter feedback.
- Mindo is reported by the BrainBit SDK as the `Headband` device type. See
  [docs/hardware.md](docs/hardware.md) for what is known and what still needs
  checking on real hardware.

## Project layout

| Path | What |
|---|---|
| `lib/headband/` | Device models, `HeadbandConnection` (timeouts, reconnection), simulator, `NeuroSdkHeadbandSource` and the FFI binding to the neurosdk2 C API |
| `native/`, `hook/build.dart` | C++ shim that copies SDK callback data for Dart, compiled automatically by the build hook |
| `lib/focus/` | `EmotionalMath` estimator, `FocusEngine` (calibration, 1 Hz smoothed score and rhythm shares), baseline-centred `ScoreScale` and scale zones, focus states |
| `lib/feedback/` | Drop/recovery tracking, gain policy for both modes, audio playback |
| `lib/sessions/` | Session lifecycle, recording, local JSON storage, raw EEG recording, CSV export |
| `lib/ui/`, `lib/app/` | Screens, app wiring, menu bar |
| `third_party/neurosdk2/` | Vendored C headers for the FFI binding (`dart run ffigen --config ffigen.yaml`) |
| `assets/sounds/` | Generated soundscapes (`python3 tool/generate_sounds.py`), see `LICENSES.md` |
| `openspec/` | Specs, design and task list for this change |
