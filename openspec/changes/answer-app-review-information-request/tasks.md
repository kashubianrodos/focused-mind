# Tasks

## 1. Scan pipeline

- [x] 1.1 `MultiHeadbandSource.scan()`: build each emitted list in `sources` key order, not first-emission order. Verify with a test in `test/headband/` where the simulator emits before a fake real source, and the real device still comes first.
- [x] 1.2 `HeadbandConnection.scan()`: forward `BluetoothUnavailableException` without ending the scan; other errors still end it. Verify with a test where a fake BLE source fails with Bluetooth unavailable and the simulator is merged in: the error is reported and "Simulated headband" is still emitted. `flutter test test/headband` passes.

## 2. Always offer the simulated headband

- [x] 2.1 Remove Test mode: `TestModeSetting`, `SettingsRepository.testMode` and `saveTestMode`, `AppServices.testMode`, and the Settings › Data switch. Create `SimulatedHeadbandSource` always enabled, and default `includeSimulator` to `true`. Verify `flutter analyze` is clean and `grep -rn "testMode\|Test mode" lib` finds nothing.
- [x] 2.2 Connect panel: show the new hint (design decision 4) when the scan ends with no real device, whether the list is empty or only the simulator was found. Verify in 2.3.
- [x] 2.3 Update tests:
  - `test/ui/connect_screen_test.dart`: replace the "only in Test mode" test with "a release-like scan lists the simulator below real devices and shows the hint when no real band is found".
  - `test/ui/settings_page_test.dart`: drop the Test mode switch test.
  - Add a widget test: with a Bluetooth-unavailable source, the guidance and "Simulated headband" both show, and connecting works.

  Verify `flutter test` passes in full.

## 3. Docs

- [x] 3.1 README: replace the Test mode instructions with "pick Simulated headband in the scan list". Verify `grep -n "Test mode" README.md` finds nothing.
- [x] 3.2 `store/google-play/listing.md`: update the "App access" instructions and the full description's "No headband yet?" line in the same way. Verify by grep.
- [x] 3.3 Write `store/app-store/review-notes.md`. Include one plain-text notes block that answers Apple's six items in order:
  1. Video link placeholder `<VIDEO_URL>`.
  2. Purpose and audience.
  3. Setup: a real band or "Simulated headband", no login.
  4. External services: none, with the on-device BrainBit SDK named.
  5. Same behavior in all 39 European storefronts.
  6. Wellness only, not a medical device; Pixabay forest recording (Pixabay Content License) and BrainBit SDK (MIT).

  Also include the recording script from design decision 6. Verify the block is no more than 4,000 characters (measure with `python3`).

## 4. Release 0.4.3

- [x] 4.1 Bump `pubspec.yaml` to 0.4.3, commit, tag `v0.4.3` and push. Verify the iOS workflow's "Upload to TestFlight" succeeds, and rerun it if GitHub runner capacity cancels it.
- [ ] 4.2 Ask the user to install 0.4.3 from TestFlight on their iPhone (latest iOS) and run through the recording script once as QA, with a real band and with the simulated headband. Record any bug they find as a new task before going on.

## 5. Recording and resubmission

- [ ] 5.1 Ask the user to record a real session following the script, upload it to YouTube as unlisted, and share the URL. Verify it opens without signing in: `curl -sI` returns 200, and the user confirms playback in a private window.
- [ ] 5.2 Replace `<VIDEO_URL>` in `store/app-store/review-notes.md` with the link and commit.
- [ ] 5.3 Through the App Store Connect API: wait for build 0.4.3 to be VALID, rename the version to 0.4.3, attach the build, and set `appStoreReviewDetails.notes` to the notes block. Verify by reading back the version, build and notes.
- [ ] 5.4 Get the user's go-ahead, then submit for review with the retrying script. If the endpoint returns 500s, the user clicks "Add for Review" in the web UI. Verify the version state is `WAITING_FOR_REVIEW`.
- [ ] 5.5 The user replies to the 2.1 message in App Store Connect › App Review, saying the requested information is now in the Review Notes. This is a manual step: the API has no endpoint for review messages.

## Workflow follow-up

- After approval, archive with `/opsx:archive` to sync the `headband-connection` delta into the main spec.
