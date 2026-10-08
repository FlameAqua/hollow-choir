# V0.3 engineering review

8 October 2026 · application version 0.3.0 (unchanged) · working tree on `dev`, uncommitted.
Handoff: [V0.3 Claude handoff](../briefs/V0_3_CLAUDE_HANDOFF_PROMPT.md). Authority:
[V0.3 contract](../design/V03_FIELD_GUIDE_AND_AUDIO.md) and [review brief](../briefs/V0_3_REVIEW.md).
Implementation evidence: [V0.3 report](V0_3_FIELD_GUIDE_AND_AUDIO.md).

I reviewed the Field Guide, the music transport, the Audio Lab, the media tools and the 200%
reaction footer, then fixed the defects I could reproduce. Each fix has a regression test that
fails against the original V0.3 code. The V0.2.1 and V0.3 work is preserved. No combat rule,
balance value, timing window, binding, content ID or save format changed, and `save_version` is
still 1. The human gates remain open; nothing here measures hearing or comprehension.

## Findings and fixes

The music findings were measured by a scratch probe. It drives the real `MusicMixer` with the
prepared Oggs against Godot's audio server, using the headless Dummy driver and the real Windows
WASAPI driver, with Master muted so nothing is audible. "Cursor" means the stream frame that the
outgoing deck will mix next.

| # | Defect (V0.3 as delivered) | Evidence before | Fix | Evidence after |
|---|---|---|---|---|
| A1 | Same-song switches started the incoming deck *ahead* of the outgoing one. Once a deck had been mixed, the position read added the time since the last mix, which is an estimate of what the listener hears, not where the decoder is. Every switch therefore jumped forward and the error accumulated. | WASAPI (10 ms mixes): start error 0.5–7.6 ms, mean 3.3 ms. Decoded offset during overlap up to 10.3 ms. 20 toggles drifted +111 ms. Dummy driver (93 ms mixes): mean 48 ms, max 88 ms, +540 ms drift. | Switches start at the outgoing deck's cursor. While a deck is unmixed, that is exactly the position written; once mixed, it is the decoder position. The listening estimate is kept for status display only. | Start error 0.00 ms (−0.02…0). Remaining offset is at most one 128-frame decoder block (2.7 ms at 48 kHz). 20 toggles: +11.5 ms, within the mix granularity. |
| A2 | Switching back to the variant still fading out started a second copy of the same file on the other deck, a few milliseconds apart. Both copies played through the fade, which causes comb filtering or a flam. The quieter deck was cut abruptly. | WASAPI: copies 3.9 ms (no mix between requests) and 7.4 ms (0.3 s into the fade) apart. Dummy: 26 ms and 123 ms. The intense deck was cut at 1.7 dB below the louder deck. | The mix still sounding on the outgoing deck fades back in from its current level. The other deck fades out instead of being cut, and no third player is used. | No duplicate on either driver; both decks keep different mixes and fade smoothly. |
| A3 | The end overlap always lasted the full crossfade, even when less music remained. This happens after a seek near the end, a late tick, or an end reached during a fade. | Seek to 0.5 s before the end gave a 3.00 s fade-in. After the outgoing mix ended, the incoming one sat about 8 dB below its target for roughly 2.5 s. | The overlap is limited to the outgoing mix's remaining time (minimum 0.05 s). | 0.50 s (Dummy) and 0.49 s (WASAPI). Normal end overlaps are still the full 3 s. |
| A4 | A seek on a deck that had just ended reported success but did nothing. `AudioStreamPlayer.seek()` is a no-op unless the player is already playing. | Returned true, nothing played, position 0.000. | `seek` restarts the deck with `play(position)`. | Plays from 12.06 s and 12.13 s. |
| A5 | Audio Lab: after Preview ending, pressing Stop left the countdown visible ("automatic transition in 0.0 seconds"). | Reproduced in a test. | Stop clears the preview state. | Covered by a test. |
| A6 | The keyboard-seek test never pressed a key the game recognises. Its synthetic event set only `keycode`, while InputBindings and its `ui_*` mirrors match physical keys. Its assertion still passed because the old pending position read grew with wall-clock time. | `ui_right` matched false, and the slider value was unchanged by the press. | The test sends a realistic key (both `keycode` and `physical_keycode`). It asserts the slider moves one step and the stream seeks exactly there. | Covered by a test. |
| K1 | The research gates were written twice. The battle's affinity gate (`PreviewRules.affinity_known`, `>= STUDIED`) and the Field Guide's (`BattleKnowledge.saved_affinities_known`) were separate copies of the same rule, so they could drift apart unnoticed. | Code review. A test I added fails when the battle threshold is changed alone (Studied: expected false, got true). | `ResearchRules.affinities_known / moves_known / tendencies_known` are now the only gates. Engine previews, `BattleKnowledge` and `FieldGuideReadout` all call them. | The new test checks that the guide and the battle agree at every level. |
| K2 | The Field Guide labelled any unrecognised saved research source as "Quest", because of the `EnumText` fallback. Version-1 saves accept arbitrary integers. | A source list of [Inspect, 42] showed "Inspected, Quest". | Unknown values are skipped. The saved list is not modified. | Covered by a test. |

The other contract points held up. The review found nothing to fix in these:

- **Knowledge boundary:**
  - unseen species never appear;
  - Observed shows notes and sources, Studied adds affinities, Understood adds stats, traits and the initial move cards, and Mastered adds tendencies, rare interactions, later-phase moves and phase opening moves;
  - temporary battle reveals never reach the guide;
  - unknown saved IDs are ignored, and reading the guide never saves.
- **Boss music:** the cue is chosen from the encounter's enemies, and every enemy is on stage from the first frame (there are no reinforcements or summons). Music never follows hidden phases.
- **Saves:** V0.3 and this review changed no save, progression or settings code.
- **Pause and focus:** the mixer uses `PROCESS_MODE_ALWAYS` and a real-time clock. Neither Combat Speed nor `Engine.time_scale` affects it.
- **Randomness:** music selection uses its own random number generator.
- **Volume:** the Music and Master buses remain authoritative.
- **Players and cleanup:**
  - at most two decks play, and only one remains after a fade;
  - a deck's stream is released when its fade finishes, and on exit;
  - the full suite exits without leaked objects or resources.
- **Media:**
  - a second preparation run produced byte-identical library, manifest, catalog and sidecar files;
  - all seven source/export hash pairs match the manifest;
  - the two renamed boss files are byte-identical to their committed originals;
  - no runtime code reads the catalog, manifest or inbox.
- **Screens:** focus and scrolling at 100/150/200%, the fixed Back button, and the two visible reaction-help lines at 200% are covered by tests and match the V0.3 captures, which I reviewed.

## Architecture and API

The public API is unchanged:

- `MusicMixer`: `request`, `audition`, `next_mix`, `seek`, `test_loop`, `playback_status`, `playing_count`.
- `AudioManager`: `request_music`, `battle_music`.

Internally:

- **Per-deck state:** `MusicMixer` keeps the track on each deck and that deck's pending play/seek position.
- **Two positions:** `_cursor(deck)` is used for alignment and end scheduling; `_position()` is the listening estimate shown in status.
- **Switching:** `_switch_in_place` handles same-song switches, either reusing the still-sounding deck or starting the variant at the cursor.
- **Helpers:** `_play` and `_release` centralise deck start and release.

Contract behaviour now in force:

- A quick switch back to a mix that is still audible fades back to it.
- The end overlap is at most the outgoing mix's remaining time.
- A seek restarts a deck that has already ended.
- A third distinct request during a fade still replaces the quieter deck, as the contract specifies, without a third player.

The research gates live in `ResearchRules` (engine side) because previews must apply them without
depending on the UI. `BattleKnowledge.saved_*` delegates to them.

No Resource fields, generated library, save format, content data or settings changed.

## Files changed in this review

| File | Change |
|---|---|
| `src/audio/music_mixer.gd` | A1–A4 (cursor alignment, deck reuse, bounded end overlap, restart on seek) |
| `scenes/main/audio_lab.gd` | A5: Stop clears the ending preview |
| `src/battle/rules/research_rules.gd`, `src/battle/preview/preview_rules.gd`, `src/ui/battle/presentation/battle_knowledge.gd` | K1: one set of research gates |
| `src/ui/field_guide_readout.gd` | K2: unknown saved sources skipped |
| `tests/unit/test_music.gd` | 4 tests: cursor start, deck reuse, bounded overlap, restart on seek |
| `tests/ui/test_audio_lab.gd` | Stop test; realistic key event and exact keyboard-seek assertions (A6) |
| `tests/ui/test_v03_field_guide.gd` | Guide/battle gate agreement at every level; unknown sources |
| `docs/DATA_CONTRACTS.md`, `assets/audio/AUDIO_CONTRACT.md`, `docs/design/V03_FIELD_GUIDE_AND_AUDIO.md`, `docs/TESTING.md`, `docs/RELEASE_NOTES.md`, `docs/CLAUDE_PROMPT.md`, `README.md` | Behaviour and evidence updates |
| `docs/reports/V0_3_ENGINEERING_REVIEW.md`, `docs/reports/v0_3_review/audio_lab_ending_100.png` | This report and a re-capture of the real Lab with the reviewed transport |

## Validation

Every run used a fresh isolated home under `.godot/qa/`. The baseline was a fresh copy of the
delivered tree, imported before use.

| Check | Baseline (V0.3 as delivered) | After review |
|---|---|---|
| Fresh import | clean | not re-run (the import cache was unaffected) |
| `check_scripts.gd` | 189 checked, 0 failed | 189 checked, 0 failed |
| Full suite | 205 passed, 1,937 assertions, 43.45 s | **212 passed, 0 failed, 1,976 assertions, 44.18 s** |
| Diagnostics | 4 invalid-save errors, 1 rejected-action warning | identical; no leak or orphan warnings |
| Python preparation/import tests | 8 passed | 8 passed |
| Seeded simulation smoke (240 battles) | exit 0, 7.6 s | exit 0, 7.6 s; output identical apart from timing |
| 96-battle event fingerprint (V0.2.1 method) | V0.2.1 total `dfc16832…cf7f82` | identical, including every per-battle hash |
| Preparation idempotence | — | re-run in a copy: every generated file byte-identical, all 7 exports cached |
| Mutation checks | — | each of the 7 new or changed regression tests fails on the delivered code; the gate-agreement test fails once a threshold diverges |
| Re-capture | — | Audio Lab ending preview at 100%, using the real Preview ending control (fixture) |

The capture is a labelled fixture: the harness drives the real controls and freezes the moment.

Commands (substitute the Godot executable):

```sh
python tools/qa_godot.py --godot <exe> --home .godot/qa/<run> --headless --script res://tools/check_scripts.gd
python tools/qa_godot.py --godot <exe> --home .godot/qa/<run> --headless --script res://tests/run_tests.gd
python tools/qa_godot.py --godot <exe> --home .godot/qa/<run> --headless --script res://tools/simulate.gd -- --encounter=all --exec=MIXED --runs=10 --seed=1
python -m unittest discover -s tests -p "test_*.py"
python tools/qa_godot.py --godot <exe> --home .godot/qa/<run> --hidden --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_battle.gd -- --state=audio-lab --preview-ending --out=res://docs/reports/v0_3_review/audio_lab_ending_100.png
```

## Listening versus measurement

Transport tests and probes measure positions, levels and player counts. They do not establish
how a join or a switch sounds. No one listened during this review. Speaker and headphone
listening, three joins per variant, and SFX intelligibility (AUDIO-03 and AUDIO-05) remain open.

These offline measurements are inputs for that listening session. I used FFmpeg on the prepared
Oggs, rendering each join exactly as the mixer would: an equal-power square-root overlap at the
mixer's levels.

- **End joins (momentary EBU R128 loudness).** The 3 s overlap dips 4.4–10.7 LU below the quieter
  neighbouring section at every join:

  | Join | Dip |
  |---|---|
  | Title v01→v02 | −10.7 |
  | Title v02→v01 | −7.7 |
  | Battle v01→v02 | −6.4 |
  | Battle v02→v01 | −6.1 |
  | Intense v01→itself | −6.5 |
  | Boss v01→v02 | −6.4 |
  | Boss v02→v01 | −4.4 |

  The cause is the content: each mix ends with an outro and starts with a soft intro. Battle mixes
  open about 7–9 LU quieter than they end, and the boss mixes about 3–11 LU quieter. Expect an
  audible lull at every rotation. Listening should decide whether to keep it, cut loop regions, or
  start the next mix after its intro.
- **Edges.** The first and last millisecond of every export peaks at 40/32767 or less, so there are
  no edge clicks.
- **Base v01 against intense v01.**
  - The onset envelopes align at 0 ms lag at all ten checkpoints from 10 to 100 s (correlation 0.62–0.88).
  - Waveform cross-correlation at 10, 40, 70 and 100 s gives lags of 0, 0, 0 and −1.4 ms (correlation 0.53–0.85).
  - Both estimate 72.3 BPM, though autocorrelation can mis-pick an octave.
  - The prepared lengths differ (118.28 s against 118.50 s) only because each file's trailing silence was trimmed separately.

  The two files appear to share one time grid and partly the same audio. They are the best
  candidate for a first aligned-layer pair. That is not verified yet: it needs a full-length scan,
  shared trim bounds and listening.
- **SFX against the music bed, at default volumes.** Defaults are Music 0.7, SFX 0.8 and the −12 dB
  track trim. I compared each cue's loudest 50 ms window with the music's 95th-percentile 50 ms
  window (battle and boss playlists):

  | Cue | Full band (dB) |
  |---|---|
  | Telegraph | +13.1 |
  | Beat | +3.4 |
  | Perfect | +15.4 |
  | Good | +13.0 |
  | Miss | +11.2 |
  | Brace | +16.5 |
  | Evade | +11.4 |
  | Parry | +17.5 |
  | Hit (played at −8 dB) | +8.9 |
  | Heavy hit | +20.4 |
  | Charge | +15.8 |

  The rhythm beat's full-band margin is small, but its energy sits above 4 kHz, where it is
  18–22 dB clear of the music bed. Normal hits match the music in the mid band (0.0 dB). This is a
  level proxy only. Masking also depends on timing and spectrum, so listening decides whether the
  beat or hit cues need attention.

## Known limitations

- **Two decks are not sample-locked.** A Godot probe started a 110 Hz tone and its phase-inverted
  copy on two decks at the cursor; they cancel to only 89.5%. That suits independent full mixes but
  not simultaneous layers. In the same probe, `AudioStreamSynchronized` cancelled to exactly zero.
- **Third request during a fade.** A third distinct mix requested mid-fade still replaces the quieter
  deck. Godot fades a stopped playback over 64 frames, so there is no click, but if that deck is
  loud the drop is abrupt. The contract forbids a third player.
- **Audio Lab seeks are hard cuts.** Arrow keys and gamepad move the playhead 0.1 s per press.
  Godot 4.7's `Slider` has no separate keyboard step (`custom_step` is gone), so a larger step is a
  UI decision.
- **Startup loading.** All seven prepared streams load at startup, about 17.8 MB of compressed Ogg.
- **Boss cue by content ID.** `AudioManager.battle_music()` still detects the boss by its content ID
  (`mirebell_cantor`). The contract sanctions this for now.
- **Position reads are approximate.** Pending-mix detection relies on the audio server's last-mix
  time. Status positions are a listening estimate without device-latency compensation, and under
  the headless Dummy driver they advance in about 93 ms steps.
- **Tooling inconsistencies.** Six manifest records were cached before `source_channels` and
  `source_codec` were added, so they lack those fields. `prepare_music.py` accepts `_v0` names,
  which the importer rejects.
- **Captures play audio.** They use the real audio device unless run with `--audio-driver Dummy`
  (now documented).
- **Stray folders.** The project root contains four empty, untracked editor-profile folders
  (`export_templates`, `feature_profiles`, `script_templates`, `text_editor_themes`, created at
  10:35). I left them untouched.

## Proposed adaptive-audio extension points

These are proposals with no runtime change. They decide no intensity thresholds and add no hidden
triggers.

1. **Aligned-layer content contract.** This is the smallest version that can be verified. A
   `sync_group` becomes active only when all of these hold:
   - every layer in the group shares the cue and version;
   - every layer has the same native rate and the same frame count after preparation;
   - preparation trims the whole group to shared start and end frames, rather than detecting silence per file;
   - an automated alignment check passes and is recorded in the manifest (for example `alignment_verified` with its measurements). The check compares envelope and waveform at least every 10 s across the whole file and requires every lag within ±1 ms (48 frames);
   - a human listening sign-off is recorded separately.

   The first candidate is base v01 plus intense v01 (measured above).
2. **Aligned-layer transport.** Godot 4.7.2 already provides it; the probe showed exact cancellation
   and live per-layer volume.
   - Each deck plays a group as one `AudioStreamSynchronized`. Build one per deck, because layer
     volumes are properties of the stream resource.
   - Changing tone within a group ramps `set_sync_stream_volume` with the mixer's existing real-time
     equal-power fade on that deck. There is no deck switch, seek or position estimate.
   - Rotation and cue changes keep today's two-deck crossfade between groups.
   - `AudioStreamInteractive` (bar/beat-quantised transitions) becomes an option only once streams
     carry measured `bpm`, `beat_count` and `bar_beats`.
   - Step changes in layer volume between mix blocks need a listening check.
3. **Public-state intensity mapping.** A presentation-side policy would read only what the player
   has already been shown:
   - the PresentationLedger after `hud_changed` (per-unit presented HP/max, Broken, alive, round, conditions);
   - announced `PHASE_CHANGED` events;
   - displayed intents, filtered by knowledge (their threat bands).

   It would never read engine state, future events, undeclared intents or hidden phase data, and
   never follow reaction or attack timing. Its rules:
   - evaluate only at stable points (start of planning, after a batch);
   - require a minimum dwell between changes;
   - request tones through the existing `AudioManager.request_music(cue, tone)`;
   - keep its thresholds in a Director-owned `MusicIntensityPolicy` Resource, disabled by default.

   Tests would assert that it reads only the ledger, that engine results and replays are identical
   with it on or off, and that muting music loses no information.
4. **Data-driven battle cue.** A presentation-only `music_cue` on `EncounterDefinition` would replace
   the boss ID check. This is a content-data field, so it needs Director approval.
5. **Later, if listening or memory requires it:** per-track loop regions in sample frames (to
   tighten the lulls at joins), and per-cue lazy or threaded stream loading.

## Handoff to the Director

The V0.3 transport now holds its timestamp contract to within one decoder block. Rapid toggles
and end-of-mix recovery behave cleanly, and the Field Guide shares one set of research gates with
battle. Every check passes, and determinism is byte-identical.

Still open:

- the M1.1 fresh-player READ/REACT sessions;
- a physical-controller pass;
- colour and contrast review;
- comfort with the 400 ms preparation beat;
- 200% text on a real monitor;
- artist sprite cleanup;
- music listening: three joins per variant, the measured lulls at joins, SFX intelligibility with
  speakers and headphones, and the tone switch between base and intense v01.

Decisions requested:

1. Keyboard/gamepad seek step in the Audio Lab (currently 0.1 s per press).
2. Whether to keep the lulls at joins or address them with loop regions or a later start into the next mix.
3. Whether to authorise an aligned-layer pilot with base v01 plus intense v01. This is presentation
   only: preparation would trim the pair to shared bounds and then verify it with the measurements
   and a listening sign-off.
4. Audio Lab copy nits: "1 active players", and the tone buttons don't show which tone is active.

**Next gated step toward the vertical slice:**

1. Run the [M1.1 session pack](../playtests/M1_1_SESSION_PACK.md) and turn its findings into a
   scoped fix brief.
2. Only after an explicit go decision, compare the all-reset and potion-only expedition carry
   policies and choose the save, retry and resource boundaries.
3. Then specify one bounded route that uses the existing encounters and has one visible world
   consequence.

Music listening and the optional layer pilot can run in parallel, because neither changes
gameplay. Nothing was committed or pushed.
