# V0.3 — Field Guide and audio foundation

Owner: Director/UI integrator. 8 October 2026. Authorized by the request to continue V0.3.
The M1.1 human clarity gate is still open. This contract adds presentation for existing progression,
not a new progression system, world slice, combat mechanic or content count.

## IMPLEMENTATION BRIEF

Expose the already saved bestiary and weapon practice through a title-screen **Field Guide**.
This makes the game's knowledge hook visible outside a battle without inventing rewards or changing
how research is earned. Build bounded, focus-following lists and detail scrolling using the existing
palette, font and creature art. Empty saves explain why there are no entries. Unknown species have
no names, silhouettes or move lists. Weapon practice is a record of existing points, not an unlock tree.

Add a reusable music mixer behind AudioManager and wire title, menus and battles to three stable
cue IDs. Adrian explicitly approved all six inbox tracks and requested randomized version playlists
plus future calm/intense tone variants. This supersedes the previous single-selected-mix hold.
Prepare measured exports, preserving originals, and keep the delivery ledger separate from the
typed runtime library. Loop-join listening and beat alignment are not inferred from that approval.

Follow-up authorized by Adrian: include `briarfen_battle_v01_intense.m4a`, standardize the two boss
filenames/sidecars to underscores, add a manual Audio Lab and a file-argument importer. The lab
selects songs, versions and tones, previews an ending to test normal loop scheduling,
and plays existing hit/parry effects. It writes no progress/settings. Automatic battle-tone routing
and aligned simultaneous layers remain engineering work after a defined transport/content contract.

Fix the 200% reaction footer by giving its instruction a second line and fitting all bound keys.
Existing reaction cards remain the source for effects, risks and unavailable defenses.

Director owns this contract, screen integration and visual review. The engineering return review
should audit the knowledge boundary, music lifetime and tests; no external handoff is dispatched.

## DATA CONTRACT

- FieldGuideReadout reads ProgressState, ResearchConfig and EnemyDefinition. It contains only
  information unlocked by saved research. Temporary Inspect and revealed-hit knowledge stay in battle.
- Observed: identity, existing description/habitat/lore and saved research sources. Studied:
  affinities. Understood: base stats, traits/immunities and the initial move set/telegraph details.
  Mastered: tendencies, rare interactions and moves from later boss phases. Later-phase move cards
  are not listed below Mastered; existing Understood species-trait descriptions retain the battle
  policy (a trait may mention a later move). Phase thresholds are not listed. Share predicates with BattleKnowledge.
- Progress thresholds and point awards come from ResearchConfig; do not hard-code 1/5/10/18.
- Weapon practice displays the saved weapon_mastery totals. No new reward, level or stat bonus.
- MusicTrack/MusicPlaylist/MusicLibrary are presentation Resources outside the combat registry.
  Tracks carry version, tone, stream, source-time offset, gain and crossfade duration. Preparation records user
  authorization, source/export hashes, measurements and processing. No third-party license claim.
- Recognize `<cue>_v<number>[_<tone>]` at preparation time. The importer normalizes spaces/dashes,
  copies external originals, renames inbox audio/sidecars and archives explicit replacement swaps.
  Preserve audio bytes and source hashes through renames. Keep original filename provenance.
  Added/replaced/removed files regenerate active playlists; runtime does not inspect the inbox.
- Independent full mixes use end-aware, equal-power overlaps, with a private shuffle bag and no
  immediate repeats. Tone requests prefer a matching version, falling back to base if unavailable.
  `sync_group` is reserved; simultaneous calm/intense mixing needs sample-aligned exports with the
  same arrangement, tempo, duration and loop bounds plus a synchronized playback adapter. No false
  lockstep playback of these unmeasured full mixes. Battle-driven intensity routing is later work.
- The runtime library never parses music/catalog.json and never scans source/review folders.
- save_version stays 1. No save, binding, balance, rules or content-ID change.

## STATE FLOW

Title → Field Guide → Bestiary / Weapon practice → Back → Title. Read only; opening, selecting,
scrolling or leaving never saves, grants research, changes a loadout or seeds a battle. Existing
Lab Record progress remains the only sandbox recording opt-in; Practice remains unrecorded.

Title → Audio Lab → song/version/tone → Back → Title. Same-song tone and manual variant selections
crossfade at the existing source timestamp, accounting for preparation's leading trim. Tone switches
prefer the current version when present. Selecting the playing variant is inert; manual selection
does not pin subsequent rotation. A different song and Next version start at zero. Preview ending
seeks to five seconds before the normal end-overlap trigger (or zero for short content), displays a
countdown and waits for automatic rotation. It is disabled during a fade. Click/drag/keyboard seeking
commits the selected mix, discards outgoing audio and clamps to valid file bounds. Invalid auditions
or nonfinite seeks preserve playback. Every available tone gets a control; Back stays outside scrolling.

Title, Settings, Field Guide and sandbox setup request global_title. An active battle requests
briarfen_battle, or briarfen_boss_mirebell when the existing Cantor is present. Returning to Setup
requests title; resuming restores the battle cue. Restarting the same cue preserves position.
Pause/focus loss allow music to continue; timing retains its existing rules. Requests crossfade in
0.75 real seconds using at most two persistent players, with only one playing after completion.
Missing cues fade to silence. Repeated requests are inert; near the end, the next variant overlaps
the outro for up to three seconds. A single-version playlist crossfades into itself. No soundtrack
clock changes engine timing. Music continues under Pause; Setup intentionally changes the cue.

## ACCEPTANCE TESTS

- Empty, observed, studied, understood and mastered saves expose exactly their allowed information;
  temporary Inspect, unseen species and later boss moves cannot leak. Removed saved IDs are ignored.
- Research thresholds may change in a fixture; the next-level text follows the loaded config.
- Recorded battle results appear in the guide and survive the existing version-1 round trip.
  Unrecorded Practice does not gain points. Guide navigation leaves serialized progress identical.
- Keyboard/controller focus can reach every entry and Back. Both page and details scroll at
  100/150/200% and 1280×720; no footer is pushed outside the screen. Capture real screen fixtures.
- The 200% reaction footer shows all three bound reaction keys and the first-press rule.
- Music honors Music/Master mute and volume; same-cue request does not restart; rapid switching,
  absent cues, end scheduling, pause and restart leave at most two players, then one or zero.
- Future version/tone discovery, duplicate IDs, real decode/trim, source preservation, caching and
  swapped source hashes are exercised by Python tests; preparation is idempotent on current media.
- Import tests preserve external originals, move sidecars with inbox renames, reject duplicate
  formats, protect existing audio and verify archived replacement content. Lab controls exercise
  the real intense example and remain bounded/read-only at 100/150/200%.
- Same-song tone/dropdown changes preserve source time; rapid toggles do not accumulate the
  audio server's last-mix age. Real audio frames keep overlapping decks at corresponding positions.
  Test actual slider pointer/keyboard input, seeks during fades, trim offsets and shorter variants.
- Full script check, automated suite and seeded simulation smoke remain clean. Human READ/REACT,
  controller comfort and music audition remain open and are reported separately.

## KNOWN EDGE CASES

Existing saves may contain unknown content IDs: skip those entries without mutating the save.
Research sources describe what happened, not future rewards. A phase's opening move may be absent
from its action list; include it once at Mastered. No mastery points means an honest empty record.
Crossfading rapidly may replace the quieter outgoing stream; do not allocate a third player.
Audio-only information and soundtrack timing are forbidden. Filename grouping is authorized by
Adrian, but is not evidence of musical alignment.
Position preservation is implemented; musical/sample alignment remains content-dependent. If a
target cannot represent the source timestamp, clamp to its start/tail and retain normal end rotation.

## NON-GOALS

World/hub/expedition runtime, attrition, quests, crafting, loot tables, inventory management,
new enemies/weapons/encounters/statuses, new tutorial or analytics system, balance tuning,
simultaneous adaptive layers/ducking, beat synchronization without aligned content, new music
generation, save migration, committing or pushing.

Next gated stage: collect the existing M1.1 session pack and resolve its findings. Only after an
explicit go decision, compare the all-reset and potion-only expedition proposals, select carry
boundaries, then specify one bounded route with existing encounters and one visible world consequence.
