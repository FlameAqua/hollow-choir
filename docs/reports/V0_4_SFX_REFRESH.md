# Hollow Choir — soft material SFX refresh

9 October 2026 · Adrian requested soothing effects to suit the game's theme and artwork.
Integrated in the uncommitted working tree; application 0.3.0 / save version 1.

## Direction and implementation

All 22 existing SFX cues have been replaced. Felted wood, porous clay, damped bronze, soft
reed/cloth friction and dark early reflections replace the high pure-tone bleeps, pitch sweeps
and escalating outcome notes. Impacts retain body; parry has the clearest upper resonance;
perfect is a small muted bell. Victory is a single settling open interval and defeat is a
lower, fading interval. Neither plays an ascending reward melody.

The sounds are original, deterministic procedural synthesis with no external samples. They
suggest acoustic materials; they are not claimed to be recordings. The existing regeneration
tool now produces the new palette, so a routine rebuild cannot restore the arcade placeholders.

The assets use the same lowercase filenames and `AudioManager.Cue` mapping. AudioManager's
only code change is its descriptive comment. Playback events, pitch variation, volume calls,
12-player pool, Music/SFX buses, settings and all combat clocks/rules are unchanged. Beat is
short and dry. Telegraph retains two pulses at 0 and 100 ms. Technical measurements put the
first sample above -40 dBFS within 8 ms for beat, telegraph, hit and parry; subjective timing
clarity with music still needs listening. Longer outcome/support tails do not hold up gameplay.

## Evidence

- Godot imported all 22 replacements successfully. This incremental import emitted no
  **Safe save failed** diagnostic; it does not settle the separate cold-import investigation.
- All 22 cue files match the runtime enum and manifest, decode as mono 44.1 kHz / 16-bit PCM,
  have zero-valued endpoints, pass peak/DC/onset checks, retain normalization-off import
  settings and reproduce byte-for-byte when regenerated on this Python runtime.
- Runtime smoke loaded and played all 22 imported streams, checked durations, no loops,
  the fixed player pool, SFX mute/volume and independence from the Music bus.
- Full suite: **262 passed, zero failed, 2,717 assertions (59.37 seconds)**. Deliberate invalid
  save and QA-isolation diagnostics belong to their expected-error/rejection tests.
- `git diff --check` passed. Existing work remains present; no commits, pushes or version bump.

Individual source sample peaks range from -18.42 to -8.64 dBFS, approximately 5–10 dB quieter
than the corresponding placeholders. The median power-weighted spectral centroid across cues
fell from 715 to 422 Hz. These numbers document a darker, quieter set; they do not establish
perceived loudness, emotional fit or in-game intelligibility. They are not LUFS/true-peak values.

Recipe: [generator](../../tools/generate_placeholder_sfx.py).
Asset notes: [SFX palette](../../assets/audio/sfx/README.md).
Per-cue hashes and measurements: [manifest](../../assets/audio/sfx/manifest.json).
Technical run logs and the pre-edit working copies are retained under ignored `.godot/`.

## Audition

[19-second palette preview](v0_4_audio/sfx-palette.wav), at exported cue gains, with a 350 ms
gap between sounds. This dry sequence helps compare materials; it does not simulate a full
battle mix. The Audio Lab's existing **Hear hit** and **Hear parry** buttons use these assets.

| Starts at | Cue | Starts at | Cue |
| --- | --- | --- | --- |
| 0.20 s | UI move | 0.64 s | UI confirm |
| 1.31 s | UI cancel | 1.82 s | Hit |
| 2.40 s | Heavy hit | 3.22 s | Weakness |
| 4.01 s | Perfect | 4.79 s | Good |
| 5.31 s | Miss | 5.82 s | Parry |
| 6.78 s | Brace | 7.36 s | Evade |
| 7.96 s | Break | 8.98 s | Status |
| 9.75 s | Heal | 10.98 s | Focus |
| 11.65 s | Telegraph | 12.16 s | Channel |
| 13.12 s | Beat | 13.54 s | Charge |
| 14.23 s | Victory | 16.13 s | Defeat |

First-playtest addendum: the reel now appends the peat, stone and wood footsteps. The original
22 sounds are unchanged. These three travel cues are quieter and use the same material palette;
the current manifest and runtime enum contain 25 cues. See the playtest-polish report for integration.

Human listening approval remains open. Listen through ordinary speakers and headphones with
music off/on, especially repeated navigation, beat/telegraph recognition, perfect versus parry,
and heavy hit versus break. The existing sound-off visual information remains authoritative.
No actual human audition or approval is inferred from technical checks. Claude should preserve
the cue filenames, user-volume authority and existing presentation/event boundaries while reviewing.
