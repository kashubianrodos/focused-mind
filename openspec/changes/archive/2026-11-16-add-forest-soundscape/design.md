# Design

## Context

Soundscapes are a Dart enum (`Soundscape { birds, ocean }`) in `lib/feedback/feedback_settings.dart` with a label and asset path per value. The settings page iterates `Soundscape.values`. Settings persist as JSON, with the enum stored by `name`. `fromJson` falls back to defaults for missing keys, so new fields need no migration. `JustAudioOutput` plays the asset with `LoopMode.one`. `FeedbackController.applySettings` reloads the loop when the soundscape changes mid-session.

Assets (`tool/generate_sounds.py`, numpy + `afconvert`): `birds.m4a`, `ocean.m4a` are stereo with decorrelated channels; `end_chime.m4a` is mono duplicated to two channels.

Forest source: `~/zapytania/Daytime Wind with Birds and Forest Grass by Eryliaa Royalty-free.mp3`, MP3, mono, 48 kHz, 256 kbps, 574.5 s, 18 MB.

## Goals / Non-Goals

**Goals:** "Forest" option, selectable and previewable like the others; loops without a click; a remembered mono/stereo switch that applies immediately; license recorded.

**Non-Goals:** user-imported sounds; balance or pan control; changing the default soundscape; making the forest recording stereo.

## Decisions

- **Forest:** enum value `forest`, label "Forest", asset `assets/sounds/forest.m4a`, appended last. Keep the full ~9.5 min. Equal-power crossfade of the last ~3 s into the first ~3 s for a seamless loop. Encode AAC at about 64 kbps (≈4.6 MB). Built by `generate_sounds.py` from the MP3 path; the MP3 is not committed.
- **Mono via pre-rendered assets, not runtime downmix.** `just_audio` has no cross-platform channel-mix or downmix API. Shipping `birds_mono.m4a` and `ocean_mono.m4a` (L+R averaged, written by `generate_sounds.py`) is the simplest approach that works on every platform. The cost is about 1.5 MB.
- **Forest has one asset.** The source is mono, so the same file plays for both settings.
- **The end chime has no mono variant.** It is already identical in both channels.
- **API:** `Soundscape.assetFor({required bool mono})` replaces `asset`. `FeedbackSettings` gets `bool mono = false` (JSON `mono`, included in `copyWith` and `==`/`hashCode`). `AudioOutput.load` and `preview` take the mono flag. `applySettings` reloads when the soundscape *or* `mono` changes.
- **UI:** a `SwitchListTile` "Mono sound" ("Same sound in both ears") under the soundscape list.

## Risks / Trade-offs

- **License unclear:** "Royalty-free" by Eryliaa (likely Pixabay or similar). Before shipping, confirm the source URL and that the license allows redistribution inside an app, and record both in `LICENSES.md`. If it doesn't, drop the forest part; mono still stands.
- **Bundle grows by about 6–7 MB.** Acceptable; the bitrate can be lowered if it matters.
- **Phase cancellation when averaging L+R** could thin the synthesized loops. Listen to the mono variants. If they sound thin, render mono straight from the generator (one channel's source) instead of averaging.
- **Forest seam still audible** (e.g. a bird call cut mid-fade): move the cut to a quiet stretch or lengthen the fade.
- **Spec dependency:** `focus-audio-feedback` is only in the unarchived `add-desktop-focus-monitor` change; archive that first.
