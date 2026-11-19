# Design

## Context

Motivation: see proposal.md, "Why".

- `AppServices.create` builds the simulated headband source as
  `SimulatedHeadbandSource(enabled: () => includeSimulator || testMode.value)`.
  `includeSimulator` defaults to `kDebugMode`, and `testMode` is a
  `TestModeSetting` stored in preferences under `test_mode` and switched in
  Settings › Data.
- `MultiHeadbandSource.scan()` merges the sources into a map keyed by the order
  they first emitted. The simulator yields `[]` immediately, so it can end up
  first, before any real band.
- `HeadbandConnection.scan()` ends the whole scan on the first error. With
  Bluetooth off or denied, the scan stops before the simulator is listed.
- App Store Connect's Notes field takes plain text up to 4,000 characters, and
  the recording has to be a link.

## Goals / Non-Goals

**Goals:**
- From a fresh install, a reviewer gets to a running session with no settings
  change: Scan → Simulated headband → Start session. This holds even if they
  deny Bluetooth.
- The repo is the single source for the review notes.

**Non-Goals:**
- Detecting App Review or adding behavior only reviewers see.
- Automating the recording or the YouTube upload.
- Hiding the simulator from people who own a band. It stays clearly named
  "Simulated headband" and is listed below real devices.

## Decisions

1. **Remove Test mode instead of defaulting it to on.** Always enabling the
   simulator leaves the setting with nothing to do. Changes:
   - Delete `TestModeSetting`, `SettingsRepository.testMode`,
     `saveTestMode`, the Settings switch and `AppServices.testMode`.
   - `SimulatedHeadbandSource` is created without `enabled` (or with
     `enabled: () => true`).
   - `includeSimulator` stays as a create parameter for tests that need a
     real-only scan, but defaults to `true`.
   - The old `test_mode` preference is simply left unread.

   Alternative considered: keep the switch, default it to on. Rejected, because
   a switch that only hides a demo entry adds noise to Settings.

2. **A stable list order.** `MultiHeadbandSource.scan()` emits the
   concatenation in the order of the `sources` map, which `AppServices` builds
   with real sources first, rather than in first-emission order. This is a
   small change: iterate `sources.keys` when building the output list.

3. **A Bluetooth error no longer ends the whole scan.**
   `HeadbandConnection.scan()` forwards a `BluetoothUnavailableException` to
   the listener but doesn't call `finish()`. The scan ends normally (all
   sources done, or `scanTimeout`). Other errors keep today's stop-on-error
   behavior. The connect panel already shows the error text and the device
   list together.

   Alternative considered: special-case the simulator in the panel. Rejected,
   because the scan pipeline is the right owner of this behavior.

4. **Hint text.** When the scan ends with no real device (the list is empty, or
   only the simulator was found), show: "No headband found. Make sure it is
   switched on and charged, keep it close to this device, then scan again. No
   headband? Pick Simulated headband to try the app." The panel tells the
   simulator apart by `HeadbandFamily.simulated`.

5. **Review notes are a Markdown file with one plain-text block.** The block in
   `store/app-store/review-notes.md` is pushed to
   `appStoreReviewDetails.notes` through the API. It contains no Markdown,
   because the field doesn't render it.

6. **The recording is a real session following a fixed script.** On an iPhone
   running the latest iOS, start the screen recording from Control Center. The
   video runs about 2–3 minutes:
   1. Fresh install, then launch from the home screen. The wellness notice
      appears.
   2. The Bluetooth prompt.
   3. Scan: the real band and "Simulated headband" are both listed.
   4. Connect the real band and show contact quality.
   5. Pick Focus, 25 min, and Start.
   6. Signal check and calibration.
   7. The live score, scale, rhythms and soundscape, with sound on.
   8. Lock the screen briefly to show the session keeps running.
   9. End the session and show the summary.
   10. History, then export to Files.
   11. Switch to Meditation and start briefly.
   12. Settings: the sound choice.

   The app has no account, user-generated content or paid features, and the
   notes say so.

7. **0.4.3 replaces 0.4.2 on the same App Store version.** Use the tag-driven
   CI, rename the version, attach the build, update the notes and submit with
   the retrying script. If the review-submission endpoint returns 500s again,
   fall back to the web UI.

## Risks / Trade-offs

- [Band owners see a demo entry they don't need] → It is named clearly and
  listed last.
- [A reviewer judges the app on simulated data only] → The video shows a real
  band and real EEG. The notes explain that the simulator feeds the same
  scoring, feedback and session pipeline.
- [With Bluetooth denied, the progress indicator runs the full 15 s] → This is
  the same as a normal empty scan, and the guidance and simulator appear at
  once.
- [The video link breaks] → Use an unlisted video, not private, and check the
  link before each submission.
- [The notes go over 4,000 characters] → A task checks the length before
  pushing.

## Migration Plan

No data migration. The `test_mode` key is left in preferences, unused.
Rollback: revert the commit. The old code reads the key again and works.
