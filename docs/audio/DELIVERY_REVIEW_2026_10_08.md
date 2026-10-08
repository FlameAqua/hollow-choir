# First music delivery — comparison and intake record

**V0.3 update:** Adrian has approved all six base inbox songs and requested version playlists. They are
now integrated using measured, hash-named Ogg exports and end-aware crossfades. The original intake
evidence below is historical; no agent audition, seamless-loop or beat-alignment claim is added.
See [V0.3 report](../reports/V0_3_FIELD_GUIDE_AND_AUDIO.md) and the
[prepared manifest](../../assets/audio/music/prepared_manifest.json) for current processing.

Received 8 October 2026 from Adrian: six Suno originals based on the project request prompts,
two variants each for title, ordinary Briarfen battle and Mirebell boss. **All six passed technical
decode checks. Musical fit, loop joins and version selection have not been auditioned in this pass.**

Listen to the original or Ogg comparison using the links below. Comparison copies retain the entire
track and native rate, with no gain, trimming, crossfade or loop enabled. Both versions remain candidates.
Requested BPM/meter are creative direction; delivered tempo and meter are unmeasured.

| Cue | Variant | Duration | Original | Comparison | Source LUFS / true peak |
|---|---|---:|---|---|---:|
| `global_title` | v01 | 2:29.84 | [M4A](../../assets/audio/source/inbox/global_title_v01.m4a) | [Ogg](../../assets/audio/source/review/global/global_title_v01.ogg) | -14.55 / -0.06 dBTP |
| `global_title` | v02 | 2:29.96 | [M4A](../../assets/audio/source/inbox/global_title_v02.m4a) | [Ogg](../../assets/audio/source/review/global/global_title_v02.ogg) | -15.13 / -0.76 dBTP |
| `briarfen_battle` | v01 | 1:59.52 | [M4A](../../assets/audio/source/inbox/briarfen_battle_v01.m4a) | [Ogg](../../assets/audio/source/review/regions/briarfen/briarfen_battle_v01.ogg) | -14.12 / -1.24 dBTP |
| `briarfen_battle` | v02 | 1:59.64 | [M4A](../../assets/audio/source/inbox/briarfen_battle_v02.m4a) | [Ogg](../../assets/audio/source/review/regions/briarfen/briarfen_battle_v02.ogg) | -13.71 / -0.42 dBTP |
| `briarfen_boss_mirebell` | v01 | 2:29.96 | [M4A](../../assets/audio/source/inbox/briarfen_boss_mirebell_v01.m4a) | [Ogg](../../assets/audio/source/review/regions/briarfen/briarfen_boss_mirebell_v01.ogg) | -14.33 / -1.53 dBTP |
| `briarfen_boss_mirebell` | v02 | 2:29.72 | [M4A](../../assets/audio/source/inbox/briarfen_boss_mirebell_v02.m4a) | [Ogg](../../assets/audio/source/review/regions/briarfen/briarfen_boss_mirebell_v02.ogg) | -14.46 / -0.25 dBTP |

## Listening notes to capture

- Title: memorable motif, spacious reading atmosphere, and a comfortable return or one-shot ending.
- Ordinary battle: useful energy early, repeat listening without fatigue, and clear space for SFX.
- Mirebell: bell/roots identity and more weight, without musical swells implying nonexistent phases.
- For every candidate: unwanted lyrics, abrupt endings, distracting accents, favorite sections, and
  the natural point to repeat. Check three actual joins after choosing a candidate loop region.
- Record a favorite by cue and variant. Filenames and technical measurements do not choose a default.

## Measured preparation

All sources are Opus audio in M4A/MP4-family containers, 48,000 Hz stereo. Every source was completely
decoded for loudness and silence analysis; each Ogg Vorbis comparison was completely decoded again.
Exports use libvorbis quality 5 at the native rate, with the same channels and less than 0.15 seconds
of container-duration difference. This lossy conversion does not improve the supplied audio quality.
No original was renamed or overwritten; SHA-256 checks match before and after preparation.

| Candidate | Comparison LUFS | Comparison true peak | Detected silence (−50 dBFS, ≥0.25s) |
|---|---:|---:|---|
| `global_title_v01` | -14.58 | -0.07 dBTP | None detected |
| `global_title_v02` | -15.13 | -0.81 dBTP | 149.21–149.97s |
| `briarfen_battle_v01` | -14.19 | -1.37 dBTP | 118.23–119.53s |
| `briarfen_battle_v02` | -13.80 | -0.47 dBTP | 119.15–119.65s |
| `briarfen_boss_mirebell_v01` | -14.39 | -1.44 dBTP | 149.03–149.97s |
| `briarfen_boss_mirebell_v02` | -14.51 | -0.44 dBTP | None detected |

These mixes are louder than the contract’s −18 to −16 LUFS preparation target. Several have little
true-peak headroom; any eventual level adjustment belongs to a reviewed versioned export, preserving
the originals. Silence detection is a threshold measurement, not proof of an ideal intro, ending or loop.
Raw-level comparisons are retained for honest review; playback gain is not selected.

## Shared records and next stage

[Catalog v2](../../assets/audio/music/catalog.json) links six unique delivery IDs to per-source
`.delivery.json` metadata, original hashes, technical measurements and comparison hashes.
Boss inbox filenames now use `briarfen_boss_mirebell` throughout. Delivery metadata retains the
original uploaded spelling as provenance; the audio bytes are unchanged by the rename.
The user reported that the songs were based on the request prompts. Exact generation text/date,
provider track links, BPM/meter and usage evidence remain unknown rather than inferred.

All three supplied cues are `received`; exploration is still `requested`. Cue selected source/runtime
paths, delivery/version and approval fields remain null. Comparison exports live in
`assets/audio/source/review/{global,regions/briarfen}/`, excluded from Godot by `source/.gdignore`.
Musical-fit review and loop preparation precede promotion to `music/global/` or `music/regions/briarfen/`.
The existing AudioManager and gameplay clocks are unchanged; no music player was added.

Technical validation completed: six sources, six comparison files, six per-file metadata records;
two unique candidates per intended cue; source/export path and hash checks; rate/channel/duration
parity; complete decode; ledger references and null selected fields. This is separate from the
contract’s listening, exported-loop and later runtime integration acceptance tests.

[Audio contract](../../assets/audio/AUDIO_CONTRACT.md) · [Engineering handoff](../briefs/AUDIO_DELIVERY_INTAKE.md)
