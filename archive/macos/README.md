# macOS app (discontinued)

Focused Mind started as a macOS app. The macOS build is **no longer
maintained**: the app now ships only for Android and iPhone. This folder
keeps the macOS pieces for reference in case the Mac app comes back. Nothing
here is built, analyzed or tested.

| Path | What it was |
|---|---|
| `macos/` | The Flutter macOS runner project (Xcode project, entitlements for Bluetooth and audio, app icons) |
| `menu_bar.dart` | `MenuBarController`: the menu bar indicator showing the focus state and score during a session, with open window, mute and end session items. It lived in `lib/app/` and was started from `main.dart` on macOS |
| `menu_bar_test.dart` | Its tests (were in `test/app/`) |

## Why it stopped

Mindo, the band the app was developed against, has to be bonded (paired)
before the BrainBit SDK can connect to it. macOS has no public API to bond a
Bluetooth LE device, so the Mac app never connected to Mindo (see
[docs/hardware.md](../../docs/hardware.md)). The phones can bond it.

## Still in the main project

- The host tests (`flutter test`) still run on macOS and load BrainBit's
  prebuilt macOS libraries (`test/support/native_libs.dart`); that is the
  development machine, not the app.
- `lib/headband/ffi/neurosdk_library.dart` still knows the macOS library name
  (`libneurosdk2.dylib`).
- `docs/hardware.md` keeps the macOS findings.

## Bringing it back

1. Move `macos/` back to the repository root and `menu_bar.dart` to
   `lib/app/`, `menu_bar_test.dart` to `test/app/`.
2. Add `tray_manager: ^0.8.3` and `window_manager: ^0.6.0` to `pubspec.yaml`.
3. In `lib/main.dart`, after creating the services:

   ```dart
   if (Platform.isMacOS) {
     await MenuBarController(
       services.session,
       isMuted: () => services.feedback.muted,
     ).start();
   }
   ```

4. Remove `archive/**` handling for these files from `analysis_options.yaml`
   (keep `macos/**` excluded), restore the "Compact always-visible indicator"
   requirement in `openspec/specs/focus-sessions/spec.md`, and run
   `flutter run -d macos`.
