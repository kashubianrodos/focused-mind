# Tasks

## 1. Build with Xcode 27 in CI

- [x] 1.1 In `.github/workflows/ios.yml`, set both jobs (`build` and `testflight`) to `runs-on: xcode-27`, with a comment that this is GitHub's preview image for Xcode 27. Add a first step, `sudo xcode-select -s /Applications/Xcode_27.2.app && xcodebuild -version`, and update the comment above `testflight` about the SDK requirement. Verify the YAML parses: `python3 -c "import yaml,sys;yaml.safe_load(open('.github/workflows/ios.yml'))"`.
- [ ] 1.2 Push a branch and start `ios.yml` by hand with `gh workflow run ios.yml --ref <branch>`. This uploads a TestFlight-only build of the current version; the version in review is untouched. Verify that the log shows `Xcode 27.2`, both jobs succeed, and the uploaded build is VALID in App Store Connect with no ITMS-90725 email.

## 2. Flutter upgrade (only if 1.2 fails because of Flutter or CocoaPods)

- [ ] 2.1 If 1.2 passed, mark this task N/A in a note. Otherwise set `FLUTTER_VERSION` to the latest 3.50.x in `ios.yml`, `android.yml` and `test.yml`, upgrade local Flutter, run `flutter pub get` and `cd ios && pod update`, and commit the lock files. Verify that `flutter analyze` is clean, `flutter test` passes, and rerunning 1.2 succeeds.
- [ ] 2.2 If 1.2 fails because the BrainBit frameworks don't link or validate, stop. Record the error, keep Xcode 26 (still valid until April 2027), and raise it with the user and BrainBit. Verify that the decision is written down in this file before going on.

## 3. Docs

- [x] 3.1 README: under Requirements, require Xcode 27 or later for iPhone builds. Under CI and releases, say the iOS jobs use the `xcode-27` image with Xcode 27.2 pinned. Verify by reading the diff.

## 4. Merge and release

- [ ] 4.1 Open a PR, wait for checks, and merge once the user approves. Verify that `main` contains the change.
- [ ] 4.2 Once the 0.4.3 App Store review has finished (approved or rejected), bump `pubspec.yaml` to 0.4.4, tag `v0.4.4` and push. Verify that the TestFlight upload succeeds, the build is VALID, and Apple sends no ITMS-90725 warning.
- [ ] 4.3 Ask the user to install 0.4.4 from TestFlight and run through the recording script in `store/app-store/review-notes.md` once, with the real band and the simulated one. Record any bug as a new task.

## Workflow follow-up

- When GitHub releases the Xcode 27 image under a GA label (for example `macos-27`), switch `runs-on` to it.
- Submit 0.4.4 to the App Store as the next version when the user decides to, then archive this change with `/opsx:archive`.
