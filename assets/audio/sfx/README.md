# Hollow Choir SFX — soft material palette v02

On 9 October 2026 Adrian requested soothing effects to match the game's art and theme. The 22
existing runtime cues now use muted wood, porous ceramic, damped bronze, cloth/reed friction and
short, dark room reflections. These are original procedural sounds, not field recordings or
third-party samples. This request authorizes runtime replacement; human listening approval is
still pending. Music is unchanged.

The first playtest pass adds three quieter travel cues: `step_peat`, `step_stone` and `step_wood`.
They use filtered soft friction, a muted granular contact and a hollow wooden contact. Footfalls
follow distance actually travelled, use authored tile material data and stop when blocked.
The original 22 enum positions and WAV bytes are preserved; the total is now 25 runtime cues.

`AudioManager.Cue` still maps to the same lowercase WAV filenames. No event, reaction window,
timing clock, pitch-variation call, player pool, bus or user volume setting changed. The beat
stays short and dry; telegraph retains two pulses separated by 100 ms. Attack onsets remain
prompt. Longer support/outcome tails do not delay gameplay.

| Cue family | Material and purpose |
| --- | --- |
| UI move / confirm / cancel | Felted wood tap, ceramic warmth, lower wooden return |
| Hit / heavy / weakness | Wood, skin and filtered grit; warmer bronze accent for weakness |
| Good / perfect / miss | Clay tap, muted bell, soft brushed contact; no reward chirps |
| Parry / brace / evade | Clearer bronze ring, low padded impact, cloth-and-air movement |
| Break | Porous crack, short gap, rounded low body |
| Status / heal / focus | Reed friction, waterlike clay/bronze resonance, a small ceramic touch |
| Telegraph / channel / beat / charge | Dry two-tap warning, low imperfect hum, wood tick, breath swell |
| Victory / defeat | A single settling open interval with material texture; no ascending jingle |
| Peat / stone / wood footsteps | Low, short material contacts with slight runtime pitch variation |

Regenerate with `python tools/generate_placeholder_sfx.py`. The historical tool name is kept for
compatibility; running it now produces this palette. It uses only Python's standard library and
private per-cue seeds. `--out PATH` writes a comparison set; `--preview PATH.wav` makes an ordered
audition reel. Repeated generation produces identical WAV bytes on the supported Python runtime.

Runtime: 44.1 kHz, 16-bit PCM, mono, no loops. Rounded onsets, endpoint fades and filtered texture
reduce sharp clicks and high-frequency fatigue. Peak ceilings range from -20.00 to -8.64 dBFS,
with individual cue levels rather than full-scale normalization. Existing Godot imports keep
normalization off so this balance survives import. `manifest.json` records source hashes, durations,
sample peaks and RMS; these are technical measurements, not LUFS, true peak or an audition.

See [the integration review and audition order](../../../docs/reports/V0_4_SFX_REFRESH.md).
Music/ambience must not replace or masquerade as reaction, beat, impact or outcome cues. The sibling
[audio contract](../AUDIO_CONTRACT.md) remains authoritative for music deliveries.

V0.5C appends `rune_low`, `rune_mid` and `rune_high`: three original procedural stone tones
from `tools/generate_exploration_sfx.py`, using the existing modal material synthesizer.
`exploration_manifest.json` records separate provenance and measurements. Original 25 cue
positions and WAV bytes are preserved. The three approximately 0.569-second contacts peak at
-17.39 dBFS before the host's -3 dB trim and user SFX volume. Godot normalization and looping
stay off. Playback follows saved strikes only; static text and rune shapes carry the same state
when muted. No new music or recording is required. Human listening approval remains pending;
technical measurements are not an audition.

V0.5 playtest revision adds five original operation cues: `ui_equip` (cloth/wood seating),
`ui_unequip` (soft release), `craft_smith` (damped metal contact with a wooden body), `craft_brew` (rounded clay/
water contacts), and `purchase` (a small ceramic exchange). `tools/generate_playtest_ui_sfx.py`
uses the existing synthesizer with private seeds and writes only these five assets plus
`playtest_operations_manifest.json`. Existing WAV bytes and enum positions are preserved.
These mono PCM16/44.1 kHz cues peak at -17.08 dBFS before the adapter's -6 dB trim and user volume;
normalization/looping remain off. Navigation uses UI_MOVE at -12 dB and deliberate selection
UI_CONFIRM at -9 dB. OperationFeedback listens once to adopted changed operation facts and delegates
cue choice to AudioManager.operation_cue; rejected/no-op commands and automatic saves are silent.
The integrated host removes generic-confirm success calls; the presentation regression checks
one cue per adopted operation, with failed writes and re-choices silent.
No sound timing drives gameplay. Generation and measurements are complete; in-game mix, repetition
and listening approval remain pending. See the [Director revision report](../../../docs/reports/V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md).
