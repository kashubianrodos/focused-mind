# Proposal

## Why

The app ships only for Android and iPhone. The macOS build was never able to
connect to Mindo, the main supported band, because macOS has no public API to
bond a Bluetooth LE device. It is not released or maintained, so its setup
and its macOS-only behavior should leave the active project. It is archived
for reference rather than deleted.

## What Changes

- **BREAKING** The macOS app is discontinued. The `macos/` runner project and
  the menu bar indicator (`menu_bar.dart` and its tests) move to
  `archive/macos/`, with a README that explains why and how to restore them.
- `tray_manager` and `window_manager` are removed from the dependencies.
  `main.dart` no longer starts the menu bar.
- README describes an Android and iPhone app. Run and integration-test
  instructions target a connected phone.
- The host tests still run on a Mac with BrainBit's macOS libraries. That is
  the development machine, not a shipped app.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `focus-sessions`: the macOS menu bar requirement (*Compact always-visible
  indicator*) is removed.

## Impact

- Code: `lib/main.dart`, `pubspec.yaml` and `pubspec.lock`,
  `analysis_options.yaml`, `integration_test/simulated_session_test.dart`.
- Moved into the archive: `macos/`, `lib/app/menu_bar.dart`,
  `test/app/menu_bar_test.dart`.
- Docs: `README.md`, the new `archive/macos/README.md`.
- Android and iOS builds are unchanged.
