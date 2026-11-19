# Tasks

## 1. Archive the macOS app

- [x] 1.1 Move `macos/`, `lib/app/menu_bar.dart` and `test/app/menu_bar_test.dart` to `archive/macos/`, and add `archive/macos/README.md` (why it was discontinued, what is kept, how to restore it). Verify that `git status` shows renames.
- [x] 1.2 Remove the menu bar start from `lib/main.dart`, drop `tray_manager` and `window_manager` from `pubspec.yaml`, and exclude `archive/**` from analysis. Verify `flutter analyze` is clean.
- [x] 1.3 Update the README and the integration test notes for Android and iPhone only. Verify that `grep -n -i macos README.md` only shows the development machine, CI and archive lines.
- [x] 1.4 Run `flutter test` and check it passes (224 tests).
