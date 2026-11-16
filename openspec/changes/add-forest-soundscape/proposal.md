# Proposal

## Why

The app offers only two synthesized soundscapes ("Birds chirping", "Ocean waves"). The user has a real field recording, "Daytime Wind with Birds and Forest Grass" by Eryliaa (royalty-free MP3, ~9.5 min, mono 48 kHz), and wants it as a third, more natural option.

The bundled birds and ocean loops are stereo with different left/right content. Some people find stereo ambience uncomfortable or distracting (especially on headphones, or with hearing in one ear only), so the user should be able to switch to mono.

## What Changes

- Add a third soundscape, **"Forest"**, built from that recording, bundled as `assets/sounds/forest.m4a` with the end crossfaded into the start so it loops without a click.
- Add a **"Mono sound"** setting (off by default, so stereo stays the default). When on, every soundscape and its preview play with the same signal in both channels. The setting is remembered across launches and applies immediately, including mid-session.
- Record the forest recording's source and license in `assets/sounds/LICENSES.md`.
- Existing saved settings keep working (new fields fall back to their defaults).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `focus-audio-feedback`: "Soundscape selection" adds "Forest"; new requirement "Mono or stereo playback".

## Impact

- `lib/feedback/feedback_settings.dart`: `Soundscape.forest`; new `mono` setting (JSON `mono`); asset chosen by soundscape + mono.
- `lib/feedback/audio_output.dart`, `lib/feedback/feedback_controller.dart`: load the mono or stereo asset and reload when `mono` changes.
- `lib/ui/settings_page.dart`: "Mono sound" switch.
- `tool/generate_sounds.py`: also write `birds_mono.m4a`, `ocean_mono.m4a`, and build `forest.m4a` from the MP3.
- `pubspec.yaml`: new assets. Bundle grows by about 6–7 MB (forest ~4.6 MB, mono variants ~1.5 MB).
- Tests for settings, the settings page and the feedback controller.
- `focus-audio-feedback` currently lives only in the in-progress change `add-desktop-focus-monitor`; that change must be archived before this one.
