# Sound assets

| File | Source | License |
|---|---|---|
| `birds.m4a` | Synthesized by `tool/generate_sounds.py` (FM chirps over a soft noise bed, 64 s loop) | Original work of this project; no third-party rights |
| `ocean.m4a` | Synthesized by `tool/generate_sounds.py` (shaped noise with periodic swells, 96 s loop) | Original work of this project; no third-party rights |
| `end_chime.m4a` | Synthesized by `tool/generate_sounds.py` (decaying bell partials, 3.5 s) | Original work of this project; no third-party rights |

All three are generated, not recorded, so they can be redistributed with the
app. Re-generate them with `python3 tool/generate_sounds.py` (needs numpy and
macOS `afconvert`). The loops are built to be exactly periodic so the end
flows into the start.

If you replace a file with a field recording, add its source URL and license
(CC0 or another license that allows redistribution) to this table.
