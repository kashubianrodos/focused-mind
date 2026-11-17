# Sound assets

| File | Source | License |
|---|---|---|
| `birds.m4a` | Synthesized by `tool/generate_sounds.py` (FM chirps over a soft noise bed, 64 s loop) | Original work of this project; no third-party rights |
| `ocean.m4a` | Synthesized by `tool/generate_sounds.py` (shaped noise with periodic swells, 96 s loop) | Original work of this project; no third-party rights |
| `birds_mono.m4a`, `ocean_mono.m4a` | Mono (L+R average) versions of the loops above, same script | Original work of this project; no third-party rights |
| `forest.m4a` | "Daytime Wind with Birds and Forest Grass" by Eryliaa, from Pixabay: https://pixabay.com/sound-effects/nature-daytime-wind-with-birds-and-forest-grass-451152/ . Re-encoded and loop-crossfaded by `tool/generate_sounds.py <mp3>` | [Pixabay Content License](https://pixabay.com/service/license-summary/): free to use, including commercially, no attribution required; may be bundled in an app but not redistributed as a standalone file |
| `end_chime.m4a` | Synthesized by `tool/generate_sounds.py` (decaying bell partials, 3.5 s) | Original work of this project; no third-party rights |

Except `forest.m4a`, these are generated, not recorded, so they can be redistributed with the
app. Re-generate them with `python3 tool/generate_sounds.py [forest.mp3]` (needs numpy and
macOS `afconvert`). The loops are built to be exactly periodic so the end
flows into the start.

If you replace a file with a field recording, add its source URL and license
(CC0, Pixabay Content License, or another license that allows shipping it in an app) to this table.
