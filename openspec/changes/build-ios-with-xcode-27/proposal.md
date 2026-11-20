# Proposal

## Why

App Store Connect accepted build 0.4.3 (37) with warning ITMS-90725. The build
was made with the iOS 26.5 SDK (Xcode 26.6 on the `macos-26` runner). From
April 2027, uploads and submissions must be built with the iOS 27 SDK (Xcode 27)
or later. Today this is only a warning, but after April 2027 every release
would be rejected at upload unless CI moves to Xcode 27.

## What Changes

- The iOS workflow's **Upload to TestFlight** job runs on GitHub's `xcode-27`
  image and selects a pinned Xcode 27 release, so uploaded builds use the iOS 27
  SDK.
- The **Build IPA** job (unsigned IPA on GitHub releases) moves to the same
  image. That way every iOS artifact of a release is built with the same SDK.
- If the app does not build or run with Xcode 27 on Flutter 3.47.9, Flutter is
  raised to the current stable release (3.50.x) in all three workflows. The
  Dart SDK constraint is raised only if Flutter requires it.
- README notes the Xcode requirement for local iPhone builds (Xcode 27 or
  later).
- The minimum iOS version (15.0) and the app's behavior are unchanged.
- Timing: this ships as the next release (0.4.4) once the 0.4.3 App Store review
  has finished. 0.4.3 stays in review untouched.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is build tooling only, with no spec-level behavior change, so the
change sets `skip_specs: true`.

## Impact

- `.github/workflows/ios.yml` (runner labels, Xcode selection).
- If Flutter is raised: `FLUTTER_VERSION` in `ios.yml`, `android.yml` and
  `test.yml`, plus possibly `pubspec.yaml` and `pubspec.lock` and CocoaPods
  (`ios/Podfile.lock`).
- `README.md` (requirements).
- Release 0.4.4 through the existing tag-driven TestFlight upload.
- Risk: `xcode-27` is a GitHub preview image, so runners may queue for longer.
