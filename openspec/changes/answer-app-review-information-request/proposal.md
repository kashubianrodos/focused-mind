# Proposal

## Why

App Review held the first submission (0.4.2) under Guideline 2.1 – Information
Needed. Apple asks for:
- a screen recording on a physical device
- a description of the app's purpose and audience
- setup instructions
- the external services the app relies on
- regional differences
- authorization for any protected third-party material

The current review notes cover only the Test mode steps. The app needs hardware
that reviewers don't have. Its simulated headband sits behind a Test mode switch
in Settings, so a reviewer who doesn't find it sees an empty scan list.

## What Changes

- **The simulated headband is always listed** in every build, including App
  Store, TestFlight and release APK, below any real headbands. The **Test mode**
  switch in Settings › Data is removed.
- **The simulated headband is listed even when Bluetooth is off or denied.**
  Today a Bluetooth error ends the scan before it appears.
- **The empty-scan hint points to the simulated headband** instead of Settings.
- **The App Review notes are kept in the repo** at
  `store/app-store/review-notes.md`. They answer all six of Apple's items:
  1. A link to the screen recording.
  2. The app's purpose and target audience.
  3. Setup: pick a real band, or "Simulated headband" from the scan list. No
     login is needed.
  4. External services: none, everything runs on the device. The on-device
     BrainBit SDK is named.
  5. Regional differences: none; the app is available in 39 European countries.
  6. Wellness use only, not a medical device. Third-party material: the Pixabay
     forest recording (Pixabay Content License) and the BrainBit SDK (MIT).
- **A recording script** describes what to film. The user records a real session
  with their headband on an iPhone running the latest iOS, starting from app
  launch. The video briefly shows that the simulated headband is in the list. It
  is uploaded to YouTube as unlisted.
- **Release 0.4.3**, then update the review notes and build in App Store Connect
  and resubmit.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `headband-connection`:
  - *Discover nearby headbands*: real headbands are listed first, and the
    empty-scan hint points to the simulator.
  - *Simulated headband* is replaced by *Always-available simulated
    headband*: always listed, with no Test mode; still listed when Bluetooth is
    unavailable.

## Impact

- **Code:**
  - `lib/app/services.dart`: the simulator is always enabled.
  - `lib/settings/settings_repository.dart`: `TestModeSetting` is removed.
  - `lib/ui/settings_page.dart`: the switch is removed.
  - `lib/ui/connect_panel.dart`: new hint text.
  - `lib/headband/headband_connection.dart`: a Bluetooth error no longer ends
    the scan.
  - `lib/headband/multi_headband_source.dart`: the list follows source order.
- **Tests:** the connect screen, settings page and headband scan tests.
- **Docs:** README (Test mode mentions), the new
  `store/app-store/review-notes.md`, and `store/google-play/listing.md` (the
  "App access" text).
- **Release:** version 0.4.3. The App Store Connect notes and build are updated
  through the API, then the app is resubmitted.
- **For the user:** QA on TestFlight, then recording and uploading the video.
- No new dependencies, no data collection, no network services.
