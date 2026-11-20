# Design

## Context

- `ios.yml` has two jobs:
  - `build` (Build IPA, `macos-15`, unsigned `flutter build ios`)
  - `testflight` (Upload to TestFlight, `macos-26`, `xcodebuild archive` and
    `-exportArchive` with an App Store Connect API key, cloud-managed signing)
- Neither job selects Xcode explicitly, so each uses the image's default:
  Xcode 26.6 with the iOS 26.5 SDK on `macos-26`.
- GitHub provides Xcode 27 only on the preview image `xcode-27` (macOS 27). Its
  default is Xcode 27.1 at `/Applications/Xcode.app`, and it also has 27.0 and
  27.2. There is no `macos-27` GA label yet.
- Flutter is pinned to 3.47.9 (`FLUTTER_VERSION`, same in all workflows).
  Flutter 3.50.x is the current stable release.
- Local development uses Xcode 26.6.
- BrainBit's frameworks (`neurosdk2` 1.0.21, `em_st_artifacts` 1.0.4) ship as
  prebuilt binaries through CocoaPods. Xcode 27 must still link them for arm64
  iOS.

## Goals / Non-Goals

**Goals:**
- Every TestFlight or App Store upload is built with an iOS 27 SDK, with the
  exact Xcode version pinned in the workflow.
- Builds stay reproducible, with no reliance on a runner image's changing
  default.

**Non-Goals:**
- Raising the iOS deployment target or adopting iOS 27 APIs.
- Moving the host test job (`test.yml`, `macos-15`) to Xcode 27. It runs
  `flutter test` on the Mac host and doesn't produce store binaries.
- Replacing the 0.4.3 build that is currently in review.

## Decisions

1. **Runner `xcode-27` plus an explicit `xcode-select`.** Add a step before
   anything else runs:
   ```
   sudo xcode-select -s /Applications/Xcode_27.2.app
   ```
   followed by `xcodebuild -version`, so the log shows the version used.
   Pinning 27.2 (the newest on the image, with the iOS 27.2 SDK) avoids silent
   changes when GitHub moves the default.
   - Alternative considered: `maxim-lobanov/setup-xcode`. It adds a
     third-party action for one shell line, so it was rejected.
   - Alternative considered: keep `macos-26` and wait for Xcode 27 there.
     GitHub ships the next major Xcode on its own image, so waiting doesn't
     help.

2. **Both iOS jobs move together.** The unsigned IPA on GitHub releases is
   built the same way as the TestFlight build, so a release isn't made with two
   different SDKs. The cost is one more job on the preview pool. That's
   acceptable because it only runs on push, PRs and tags.

3. **Try Flutter 3.47.9 first, then upgrade if needed.** The first step is a
   manual `workflow_dispatch` run of `ios.yml` on a branch.
   - If archive and export succeed and the app runs on the iPhone, Flutter
     stays as it is.
   - If the build fails with Xcode 27 (for example, a Flutter tool or
     CocoaPods incompatibility), bump `FLUTTER_VERSION` to the latest 3.50.x
     in all workflows, so Android and tests stay on the same Flutter. Then run
     `flutter pub get`, `flutter analyze` and `flutter test` locally and fix
     whatever the upgrade breaks.

   A Flutter upgrade touches every platform, so it happens only when needed.

4. **Ship as 0.4.4 after the 0.4.3 review.** Uploading a new build doesn't
   affect a version in review, but it is only a warning until April 2027. To
   keep things simple, release 0.4.4 with the tag once 0.4.3 is approved or
   rejected. 0.4.4 then becomes the next App Store version.

## Risks / Trade-offs

- [The preview image queues for a long time, or is unavailable] → Rerun the
  failed job, as before. Switch the label to the GA name once GitHub announces
  it. Mention the preview status in a workflow comment.
- [The BrainBit prebuilt frameworks fail to link or validate under Xcode 27] →
  This shows up in the branch dispatch run before any release. If it happens,
  stay on Xcode 26 until April 2027 and report the problem to BrainBit (the
  frameworks are theirs).
- [`Xcode_27.2.app` is removed from the image later] → The `xcode-select` step
  fails loudly. Update the pinned path.
- [Upgrading Flutter changes app behavior] → Run the full test suite and the
  TestFlight QA pass with the recording script before submitting 0.4.4.

## Migration Plan

1. Branch. Change the runners and add the Xcode selection. Run `ios.yml` by
   hand on the branch: both jobs must pass, and the TestFlight upload must
   produce a build with no ITMS-90725 warning email.
2. Upgrade Flutter only if step 1 fails.
3. Merge. After the 0.4.3 review finishes, tag `v0.4.4`.

Rollback: revert the workflow commit. Uploads go back to Xcode 26, which is
valid until April 2027.

## Open Questions

- When does GitHub promote the Xcode 27 image to GA, and under which label?
  This doesn't change the approach; the label can be updated whenever that
  happens.
