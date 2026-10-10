# V0.5 exploration presentation assets

10 October 2026 · Codex Director integration · candidate human art/listening review remains open.

The existing terrain, standing stones, actors, cloth/leather frames and original paintings are
reused. No authored area was regenerated and no painting was replaced.

`assets/art/world/exploration_v05/` adds original repo-native stepped SVGs: weathered walkable
rune stone, one/two/three incision overlays, a rusted iron seam and a root-framed niche. Palette
uses warm near-black, worn stone, olive moss and muted rust. Bright saved incisions have a static
shape change; no new shader, light, particles, flashing or motion. These are code-native assets,
not AI-generated bitmap art or a claim of final pixel-artist cleanup.

`assets/art/global/ui/items/fenrunner_leathers_v01.svg` extends the existing coat/item icon
language with oiled brown leather, a belt and a water-shedding mark. It is wired on the existing
Fenrunner Leathers definition, which retains its authored effects and stats.

`tools/generate_exploration_sfx.py` creates three original procedural stone contacts using the
existing soft-material synthesizer. No external samples or user recordings are used. The
separate `assets/audio/sfx/exploration_manifest.json` records file hashes, durations, PCM sample
peaks and RMS. Original 25 cue enum positions and WAV bytes are preserved; three cues append.
Runtime imports keep normalization/looping off and use the existing SFX bus/volume/pool.
The tones are scene-authored presentation metadata, triggered only after a saved strike.

Technical checks and rendered fixtures do not constitute human art or listening approval.
Existing approved Gloamstead and Briarfen music is reused, so no additional music request is
needed. See [the test sheet](../playtests/V0_5_INTEGRATED_TEST.md) for listening checks.
