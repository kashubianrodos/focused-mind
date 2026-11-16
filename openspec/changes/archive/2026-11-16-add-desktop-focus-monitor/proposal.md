# Proposal

## Why

Staying focused during deep work is hard, and people usually notice they drifted only minutes later. A consumer EEG headband (BrainBit family; the Mindo band for testing) can estimate attention in real time, so the app can nudge the user back with a gentle sound the moment focus drops, the way the Muse app gives audio neurofeedback during meditation. The repository is empty, so this change establishes the first product slice: a macOS desktop app, built so the same code can later ship on Android and iPhone.

## What Changes

- New Flutter application (macOS target enabled first; Android and iOS targets reserved, not shipped in this change).
- Discover, connect to and monitor a BrainBit-family headband over Bluetooth LE, including electrode contact quality, battery level and automatic reconnection. The Mindo test band is supported as the SDK's "Headband" device type, connected the same way the vendor's BrainBit Neurofeedback app does it (direct calls into the BrainBit native SDK).
- A short calibration step at the start of each session, then a continuously updated focus score (0–100) derived from the EEG signal, with artifact-contaminated stretches excluded instead of reported as low focus.
- Audio feedback in two user-selectable modes:
  - **Alert** (default): when focus stays below a user-set threshold for a few seconds, a soundscape fades in; it fades out when focus recovers.
  - **Continuous**: the soundscape plays while the user is focused, louder the more focused they are, and goes quiet when focus is lost.

  The user picks the soundscape (birds chirping or ocean waves) and its volume.
- Focus sessions: start/stop a work session, see the live focus graph, get an end-of-session summary (average focus, time focused, number of drops and recoveries), and keep a local session history.
- A simulated headband source so the app can be developed, demoed and tested without hardware.

Out of scope for this change: Android/iOS builds, cloud accounts or sync, sleep/meditation programs, raw EEG export, and any medical claims.

## Capabilities

### New Capabilities
- `headband-connection`: discovering, pairing with and maintaining a connection to an EEG headband, including contact quality, battery and reconnection, plus a simulated device.
- `focus-tracking`: per-session calibration and the live focus score, including how artifacts and poor signal are handled.
- `focus-audio-feedback`: when and how the selected soundscape plays in response to focus (alert and continuous modes), and the user's mode, soundscape, volume and threshold choices.
- `focus-sessions`: the session lifecycle, live view, end-of-session summary and locally stored history.

### Modified Capabilities
<!-- None: there are no existing specs in this project. -->

## Impact

- New codebase: Flutter/Dart project at the repository root with a macOS runner; new dependencies on the BrainBit neurosdk2 SDK and its emotions/attention library, an audio playback package and a local storage package.
- The Flutter `neurosdk2` Dart API does not expose the Headband type that Mindo uses, although its bundled native library does. The app therefore includes its own Dart FFI binding to the neurosdk2 C API.
- macOS app sandbox entitlements and Info.plist entries for Bluetooth.
- Bundled audio assets (birds, ocean) that must be royalty-free or licensed for redistribution.
- The Muse and BrainBit Neurofeedback `.xapk` files in the repository root are reference material only. They are not used by the app and should not be committed.
