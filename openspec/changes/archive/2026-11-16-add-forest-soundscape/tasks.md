## 1. Assets

- [x] 1.1 Confirm the source URL and license of "Daytime Wind with Birds and Forest Grass" by Eryliaa allow redistribution in the app (if not, skip the forest tasks)
- [x] 1.2 Extend `tool/generate_sounds.py`: write `birds_mono.m4a` and `ocean_mono.m4a` (L+R averaged into both channels)
- [x] 1.3 Extend `tool/generate_sounds.py`: build `forest.m4a` from the MP3 path (decode with `afconvert`, ~3 s equal-power loop crossfade, AAC ~64 kbps)
- [ ] 1.4 Generate the assets (done); listen to the forest loop seam and the mono variants
- [x] 1.5 Add rows for `forest.m4a` (source URL, author, license) and the mono variants to `assets/sounds/LICENSES.md`
- [x] 1.6 Register the new assets in `pubspec.yaml`

## 2. Code

- [x] 2.1 `feedback_settings.dart`: add `Soundscape.forest` ("Forest"); replace `asset` with `assetFor({required bool mono})`
- [x] 2.2 `feedback_settings.dart`: add `mono` (default false) to the constructor, `copyWith`, `toJson`/`fromJson`, `==`/`hashCode`
- [x] 2.3 `audio_output.dart` (+ `test/support/fake_audio_output.dart`): `load` and `preview` take the mono flag and use `assetFor`
- [x] 2.4 `feedback_controller.dart`: reload the loop when `soundscape` or `mono` changes mid-session
- [x] 2.5 `settings_page.dart`: "Mono sound" switch below the soundscape list; previews use the current mono setting

## 3. Tests

- [x] 3.1 Settings: `forest` and `mono` round-trip; JSON without `mono` loads as stereo
- [x] 3.2 Settings page: "Forest" is listed and previewable; the mono switch saves the setting and previews follow it
- [x] 3.3 Feedback controller: toggling `mono` mid-session reloads and resumes playback
- [x] 3.4 Run `flutter test` and `flutter analyze`
