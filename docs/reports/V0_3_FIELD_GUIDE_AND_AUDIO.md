# V0.3 — Field Guide, music playlists and Audio Lab

8 October 2026 · application version 0.3.0 · working tree on `dev`, uncommitted.
Scope: [design contract](../design/V03_FIELD_GUIDE_AND_AUDIO.md).
Return review: [engineering brief](../briefs/V0_3_REVIEW.md).

## Delivered

The title now opens a Field Guide over existing saved bestiary and weapon practice. Species remain
hidden until Observed. Learned sources, config-derived progress, existing creature art, affinities,
initial move cards/traits and mastered tendencies unlock at their established research levels.
Later boss move cards require Mastered. Existing Understood species-trait descriptions retain the
battle policy and may mention later moves; the guide does not reveal phase thresholds. Temporary
Inspect/hit reveals stay in battle. Reading, scrolling and selecting never grant progress or save.
Unknown saved IDs are ignored. Practice remains unrecorded; Lab's Record progress remains opt-in.

Adrian explicitly approved all six inbox songs and requested random version playlists with future
tone groups. All six base mixes are integrated: two versions each for title, Briarfen battle and
Mirebell boss. The subsequent v01 battle intense example is also integrated (seven tracks total).
AudioManager owns two persistent streaming decks on the existing Music bus. A private shuffle bag
uses every version before reshuffling and avoids immediate repeats when alternatives exist.
Same-cue requests preserve playback. Scene changes crossfade in 0.75 seconds; track endings overlap
the next version for up to three seconds using equal-power gains. Rapid requests replace the quieter
deck. Missing cues fade to silence. Pause/focus loss keep music running; Combat Speed and gameplay
RNG do not drive music. Existing Music/Master volume and mute remain authoritative.

`tools/prepare_music.py` discovers `<cue>_v<number>[_<tone>]`. It fully decodes sources,
measures loudness/edge silence, prepares native-rate stereo Oggs
with restrained constant gain and tiny edge ramps, and verifies unchanged source hashes. Exports
are named by source hash. Current exports are cached; source swaps produce new files, and removed
inbox files leave active playlists. Old exports remain recoverable and unselected. The generated
typed library is independent of the delivery catalog. Preparation must run after inbox changes,
followed by Godot import; an exported game does not scan the excluded source tree.

`tools/import_music.py` accepts one or more paths or inbox filenames, copies external originals,
normalizes names and rebuilds the prepared library. Different existing audio is protected;
explicit `--replace` archives previous audio and metadata. The two boss originals and their
sidecars now use underscores; both audio hashes match their original tracked files. Historical
original_filename metadata is retained alongside current_filename. See [usage](../audio/MUSIC_IMPORT.md).

The title's Audio Lab selects songs, versions and tones. Same-song selections crossfade at the
current source timestamp, including leading-trim mapping. New songs and Next version start at
zero. Preview ending skips to five seconds before automatic end rotation and shows a countdown.
The playhead accepts click/drag/keyboard seeking. Seeking during a fade commits the selected mix
and clears outgoing audio at the old timestamp; nonfinite seeks are rejected and bounds clamp.
It exposes live track/position, fade and active-player status plus existing hit/parry SFX. Settings
volume applies; no progress/settings are written. Back stays outside scrolling, and manual selection
does not pin rotation. Auditions and matching-version/fallback switches update shuffle history.

Pending play/seek reads use the newly requested position until the audio server advances to another
mix; this prevents pre-command mix age from accumulating through fast switches. The transport uses
Godot's documented position interpolation after that first mix. See [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html).

Tone requests prefer matching versions, then fall back to base/calm/available mixes. Future files
such as `briarfen_battle_v3_intense.m4a` can join without hard-coding a v1/v2 limit. This is full-mix
crossfading. Simultaneous calm/intense layers need verified matching arrangement, sample start/rate,
duration, tempo and loop bounds plus a synchronized playback adapter. `sync_group` is reserved;
no beat alignment, active layer mixing or automatic intensity routing is claimed for current songs.
Future intensity changes must follow public/presented state, never hidden attacks or phases.
The intense example's prepared length is 118.50 seconds versus 118.28 for base v01. The files have
not been verified as aligned arrangements; Claude's engine integration should establish content
alignment, transport and public-state intensity inputs before automatic adaptive-layer playback.

The reaction footer now uses two rows measured from the actual font height. All three reaction keys,
unavailability marks and the first-press rule fit at 200%, including the Pause-before Begin prompt.
The real preparation UI, 400 ms beat, graders, assists and fresh-press latches are unchanged.

## Validation

| Check | Result |
|---|---|
| Godot script check | 189 scripts, 0 failed |
| Full Godot suite | 205 passed, 0 failed, 1,937 assertions, 44.58 seconds |
| Python preparation/import suite | 8 passed; real decode/trim, native rate, unchanged source, cache, replacement, future naming, ledger addition/removal, copied originals, sidecar renames, archived swaps and duplicate protection |
| Seeded simulation smoke (initial V0.3; combat unchanged by audio follow-up) | 8 existing encounters × 3 existing loadouts × 10 MIXED runs, seed 1; completed with exit 0 in 7.6 seconds |
| Current music preparation | 7 tracks, 3 playlists; repeated file-argument import used cached media; all 7 source/export hash pairs verified |
| Visual fixtures | Original five plus Audio Lab at 100%, scrolled controls at 200% and the ending-preview countdown at 100%, reviewed below |
| Whitespace check | `git diff --check` passed |

The full suite emitted only its expected four invalid-save fixture errors and one rejected-action
warning; no exit-time resource leaks remained. Simulation still reports existing OVERLONG and
AI/PARTY NEVER USED investigation flags. Those are balance/policy observations, not crashes, and
were not retuned in this presentation pass. These runs do not prove pacing, strategy or human fun.
Combat, progression/save and gameplay data files were not changed. No 96-battle before/after byte
comparison is claimed for this pass; replay/determinism regressions and private music RNG are tested.

All checks used isolated homes under `.godot/qa/`, preserving the player's saves/settings. The
headless editor import emitted a Windows safe-save diagnostic; resource imports completed and
subsequent script, suite, simulation and rendered runs succeeded. No antivirus/editor policy change
was made. Headless audio checks exercise transport and bus state, not device latency or listening.

Commands (substitute the installed Godot executable via `--godot`):

```sh
python tools/qa_godot.py --home .godot/qa/<fresh-run> --headless --script res://tools/check_scripts.gd
python tools/qa_godot.py --home .godot/qa/<fresh-run> --headless --script res://tests/run_tests.gd
python tools/qa_godot.py --home .godot/qa/<fresh-run> --headless --script res://tools/simulate.gd -- --encounter=all --exec=MIXED --runs=10 --seed=1
python -m unittest discover -s tests -p 'test_*.py'
python tools/prepare_music.py
python tools/import_music.py briarfen_battle_v01_intense.m4a
```

## Visual evidence

These captures use explicit in-memory progress and held preparation fixtures. No save was written;
they show the real UI and do not measure comprehension, timing comfort or controller use.

- [Field Guide at 100%](v0_3/field_guide_100.png)
- [Field Guide at 200%](v0_3/field_guide_200.png)
- [Empty Field Guide at 200%](v0_3/field_guide_empty_200.png)
- [Weapon practice at 200%](v0_3/weapon_practice_200.png)
- [Reaction preparation/help at 200%](v0_3/reaction_200.png)
- [Audio Lab at 100%](v0_3/audio_lab_100.png)
- [Audio Lab at 200%](v0_3/audio_lab_200.png)
- [Ending-preview countdown at 100%](v0_3/audio_lab_ending_100.png)

The refreshed Audio Lab captures use a real 45-second seek; the ending fixture invokes the real
Preview ending control. The 200% view is explicitly scrolled to the playhead/transport controls.
Transport tests cover source offsets, shorter targets, rapid toggles, actual overlapping-player
positions after audio frames, seeks during fades, the five-second run-up and native pointer/keyboard
slider events. They do not establish sample-perfect phase alignment or audible seam quality.

At 200%, guide details deliberately scroll; Back and page selection remain outside that scroll.
The normal creature view retains existing art proportions. No new art, encounters or mechanics.

## Open gates and next stage

The M1.1 fresh-player READ/REACT clarity gate remains open, together with physical controller,
color/contrast and preparation-comfort review. Adrian's approval establishes musical fit/selection;
agent listening to runtime joins, SFX masking and three repeated joins per variant remains open.
No independent usage-license verification or seamless/beat-synchronized loop claim is made.

The next gameplay stage still depends on a documented clarity go decision. Then compare all-reset
and potion-only expedition carry policies, explicitly choose save/retry/resource boundaries, and
specify one bounded route using current encounters plus one visible world consequence. No world
runtime, attrition or new combat content was added by this pass. Save compatibility remains version 1.
Nothing was committed, pushed or published.
