# V0.4 First Footsteps — third playtest engineering review

Claude · 9 October 2026 · uncommitted `dev` after `6d8401d` · application 0.3.0 / save version 1
**Not committed or pushed. No version bump, save-schema change, combat-rule change or area regeneration
(`build_world_areas.gd --force` was not run). Codex's presentation work is preserved.**

This review answers [the third continuation brief](../briefs/V0_4_THIRD_PLAYTEST_ENGINEERING.md) and the
still-open items of [the second](../briefs/V0_4_SECOND_PLAYTEST_ENGINEERING.md) (which folded in the
[first playtest brief](../briefs/V0_4_PLAYTEST_ENGINEERING.md)); it replaces the separate second-pass
review that brief asked for. Evidence: `docs/reports/v0_4_playtest_engineering/`.

## 1. Choosing another action during recipient review

`src/ui/battle/action_picker.gd`. During `Mode.TARGET`, choosing another **legal** row now replaces
the pending option:

- **Replacement needs a recipient.** It opens its own review: legal recipients are rebuilt, along
  with the preview, the dock readout, the stage brackets and the target prompt. The reviewed recipient
  is kept when it is still legal for the replacement (enemy → enemy). Otherwise the replacement's usual
  default applies (Mending Draught → Mara herself; Intercept → the Hollow, because Mara is not a legal
  Intercept recipient).
- **Replacement needs no recipient** (Guard, self, area, battlefield). Choosing it submits it, exactly
  as from the menu.
- **Unavailable rows and the pending action itself** change nothing. The refused click no longer
  leaves focus on that row (the old code did).
- **Hover, Details and modifiers** never replace the selection. Hovering a row only inspects it.
- **Keyboard and controller** keep the explicit Back route. Back returns to the list with the current
  (replacement) action focused. The footer now reads `… [Escape] Back to actions`, plus
  `· Click an action to switch` on keyboard/mouse; the controller footer names only its own route.
  The painted target-prompt frame is unchanged.

Nothing is spent before submission. The engine still receives exactly one `ActionChoice` per request,
and Focus and potion charges change only through that submission. Single-recipient review stays
explicit.

## 2. Reset journey

- **Menu.** The exploration menu (only reachable from exploration) gains **Reset journey** above
  *Save and return to title*. The title menu is untouched.
- **Confirmation card.** It uses the painted modal and buttons, with **Cancel** focused first (Back =
  Cancel) and **Reset journey**. Its copy states exactly what the implementation does:
  > Start this journey again from Gloamstead? Route discoveries, cleared encounters, the wayside bell
  > and the return gate will reset. Research, weapon mastery and equipment will be kept.

  (The brief's example omitted the gate; I added it because the latch flag resets. Copy is yours to
  reword.)
- **Write.** `WorldSession.reset_journey()` is one `commit()`: copy → change → atomic write → adopt on
  success. The candidate's `world` becomes `WorldState.fresh()`: the square, no discoveries, links,
  clears, flags or pending entry.
  - **Tokens carry over.** `entry_serial` and `last_applied_token` carry across the reset, so no
    completion token can repeat. Without that, the new journey's first guard victory would reuse an
    old token and be silently ignored. The mutation check below catches it.
  - **Everything else is kept**, byte-identical: loadout, bestiary, mastery, inventory and statistics.
    Settings live in their own file and are untouched. Schema stays at save 1.
- **Host.** It acts only if the confirmation is still the live modal and no battle exists, so a
  repeated press writes once. On success it rebuilds at `gloamstead/town_bell` with a fade, the quiet
  bell and unlit lamp, and re-armed triggers.
- **Failed write.** The live journey is unchanged and the existing *Retry save / Return to title* card
  appears.

## 3. Tree, root and prop collision

**The defect.** The Gloamstead willows' 54×24 rectangle missed the visible root flare, which spans
x −34…39 (probe queries at (40,−6), (44,−12) and (−40,−6) missed). New finding: all **15 Reedway
willows had no footprint at all**. They stand on shoreline water cells, but their trunks and roots
extend onto the walkable bank: a reachable feet box overlapped up to 142 opaque base pixels, so Hollow
could walk into the trunk.

**The fix.** Collision is authored geometry, never runtime alpha, and was applied by surgical
scene-text edits (no re-pack).

- **Shared willow footprint.** `scenes/world/footprints/willow_roots.tres` is a 13-point convex
  polygon traced from the art: the hull of the opaque pixels connected to the trunk in the 26 rows above
  the foot. Hanging canopy strands are excluded, so the canopy stays walk-behind. All 21 willows use it
  (6 in Gloamstead, 15 in the Reedway). Behind a trunk Hollow now stops at y = −26 and is drawn behind
  it by the Y-sort.
- **Wayside bell.** A root hull (x −46…45) replaces the 78×24 rectangle. Its left roots stuck 7 px
  past the old rectangle.
- **Listening stones.** A stone hull (x −34…32) replaces the 46×16 rectangle. The outer stones stuck
  out 8–11 px on each side.
- **Square lamp.** The base art sits left of the foot origin (x −20…1), but the 26×14 rectangle was
  centred on it. The old shape let Hollow walk 7 px into the plinth from the west and put a 12 px
  invisible wall under the lantern on the east. The rectangle is now re-centred on the plinth: 21×13
  at (−9.5, −7.5).
- **Return latch.** The gateposts had no collision once the gate opened. A new always-on `Posts` body
  is added: left post 16×11, right post 15×10. The 24 px passage between them keeps the short return
  open, and the closed barrier is unchanged.
- **Rechecked and left alone:**
  - The town bell footings are covered; only grass tufts extend 3–5 px past the shape.
  - The bench: the player only walks behind it.
  - The facades, whose shapes run about 8 px past the painted walls, matching the roof eaves.
  - Reed dressing, which you can walk through as vegetation.
  - Shores, boards, interaction radii, anchors, portals, and the outside route and latch.
- **Probe tool.** `tools/probe_willow_footprint.gd` now handles polygons and writes to `--out`; the
  second-pass JSON is left as recorded. All five probe queries now hit
  (`v0_4_playtest_engineering/willow_footprint_probe.json`).

**Movement evidence.** `tests/world/test_world_collision.gd` walks the real feet body at every prop
from 16 directions. The feet may touch at most 8 base pixels; a prop that stops them must leave no more
than 6 px of gap to its art; canopy ground stays walkable; anchors fit Hollow in both states. Native
before/after renders with debug shapes come from the new `tools/capture_collision.gd`. The walk's
rest point, before → after:

| Shot | Before | After |
|---|---|---|
| Gloamstead willow, from the east | x 35 (inside the roots) | x 47 (at the root edge) |
| Gloamstead willow, from the west | x −35 | x −42 |
| Gloamstead willow, from behind | y −24 | y −26 (hidden behind the trunk) |
| Reedway willow (Dress7_22), from the bank | x 21 (in the trunk) | x 47 |
| Wayside bell, from the west | x −47 | x −54 |
| Stones, from the west | x −31 | x −42 |
| Lamp, from the west | x −21 | x −28 |
| Lamp, from the east | x 21 | x 9 (no wall under the lantern) |
| Open latch, west post | x −19 (through the post) | x −36 |
| Open latch, between the posts | passes | passes |

## 4. Integration issues found and fixed

| # | Issue | Fix |
|---|---|---|
| 1 | **Keyboard and controller planning stranded after reading the log.** The log now takes focus when clicked (Codex, for scrolling). Closing it left focus nowhere, so Up/Down/Enter did nothing until the mouse or Pause was used. | `BattleScene._on_log_visibility()` returns focus to planning (or Pause/Result) when the log closes. Codex's click-to-scroll is kept. |
| 2 | **Reduce Motion changed in the world menu's Settings** did not reach NPC and encounter-group idles until the next area load. | The host also applies the motion setting on `settings_changed`. |
| 3 | **Victory return armed triggers at the wrong spot.** It armed portal and encounter triggers from the approach anchor, then moved Hollow back to the exact engagement spot. That is harmless with the current content but wrong in principle. | `_arm_triggers()` re-arms from where the feet actually stand. |
| 4 | **Eight-way facing had no hysteresis.** A controller stick held near a 22.5° sector edge flipped the art and restarted the walk cycle every frame (60 flips in 60 noisy frames). The old four-way code had hysteresis. | Hold the current facing within 7.5° past its sector edge. Keyboard directions, which are 45° apart, always turn. Codex's facing test still passes. |
| 5 | **Exit-time "4–9 ObjectDB instances leaked / 2–4 resources".** Verbose runs show only audio objects (battle-music Ogg decks, cue-voice WAV playbacks) still mixing when the process quits. No world/UI nodes, lambdas, readout providers or tweens are involved, so this is not a gameplay leak. | New `AudioManager.silence()` and `MusicMixer.cut()`. The test runner and capture tools silence audio and let the mixer drop playbacks before quitting. Focused suites now exit clean. A deliberately orphaned node is still reported, so real leaks stay visible. |

## 5. Second-brief checks (no further defects found)

- **Inspection dock.** The new `ui/test_inspection_dock_tour.gd` uses real pointer and wheel input:
  - Mending Draught → enemy → its intent → empty stage leaves no stale payload.
  - Intent markers equal the move's public recipients only and change no selection.
  - An overflowing card scrolls both ways from its source and inside the dock, with one pane per
    wheel event.

  Codex's tests for modifiers, Alt, wheel ownership, the description shown once, scope text and native
  tooltip suppression pass.
- **Reaction widget.** The diff is drawing-only (bitmap rings, medallions, needle). Windows still come
  from the grader's own test, with no new clock. All reaction and timing suites pass.
- **Crow and Hollow idles.**
  - The crow uses a private RNG, holds neutral under Reduce Motion and stops when the host covers the
    battle.
  - Like the existing unit breathing, cosmetic idles keep running under the battle pause overlay.
    Freezing them is a Director call.
  - The Hollow standing frames hold under Reduce Motion.
- **Audio.**
  - The three step cues are appended after the original 22 indices, and all 25 WAVs match
    `manifest.json` hashes.
  - Slider percentages are presentation only.
  - Footsteps are distance-based, silent outside Explore, and reset on placement and portals.
- **Transactions.** Victory return, failed-write Retry, duplicate completion (no double award), defeat
  retry, fresh session and old saves are covered by the existing world suites, which all pass.

## 6. Verification (fresh copy of the working tree, isolated QA homes, suite run alone)

| Check | Result |
|---|---|
| Cold `--import` | exit 0; no errors, warnings or safe-save line; no stray `.tmp` |
| `tools/check_scripts.gd` | **241 scripts, 0 failed** |
| Full Godot suite | **296 passed, 0 failed, 3,997 assertions** (69.25 s), exit 0, no exit-time leak warning |
| Diagnostics | only the documented ones: 4 invalid-save errors, the rejected-action warning, 5 `WorldSession` sanitize warnings, the QA-isolation guard line |
| Simulation smoke (all encounters, MIXED, 10 runs, seed 1) | identical to the `6d8401d` baseline (91 lines) |
| World art / material polish validators | **328 / 0** and **264 / 0** |
| Python tooling tests | **10 OK** |
| Tracked files after import, suite, sim and validators | unchanged |

Codex's baseline was 272 / 2,843 / 235 scripts. This pass adds 24 tests:

| Suite | Tests |
|---|---|
| `world/test_world_collision.gd` | 6 |
| `world/test_world_reset.gd` | 7 |
| `ui/test_target_switching.gd` | 6 |
| `ui/test_inspection_dock_tour.gd` | 2 |
| additions to `test_world_host` | 2 |
| additions to `test_world_rules` | 1 |

**Mutation checks** (scratch copies, never the repo) all failed as intended:

- Old scenes: 4 of the 6 collision tests fail.
- Old picker: 4 of the 5 switching tests fail.
- Without the log fix: the log-focus test fails.
- Reset: carrying no token counter fails 2 tests; a `new_game()`-style full reset fails 3; removing the
  live-card guard fails 1.
- Without the host and facing fixes: their new tests fail.

Commands: `docs/TESTING.md` ("V0.4 third playtest additions").

## 7. Native captures (1280×720, labelled fixtures, not play certification)

- Collision after: `v0_4_playtest_engineering/collision/` (`willow-east`, `willow-west`,
  `willow-behind`, `reedway-willow`, `wayside-bell-west`, `stones-west`, `lamp-west`, `lamp-east`,
  `latch-open-west-post`, `latch-open-through`).
- Before: the same names under `collision_before/`, rendered from a scratch tree with the pre-pass
  scenes.
- UI:
  - `target-review.png` (Spear Flurry, "Pick an enemy").
  - `target-switch.png` (then Mending Draught: "Pick an ally", Mara bracketed, new footer).
  - `menu.png` (seven buttons inside the frame).
  - `reset.png` (Cancel focused).
- Probe: `willow_footprint_probe.json`.

## 8. Notes for the Director (not changed)

1. **Open latch leaf.** The open-gate art sits over the right half of the boardwalk (x 0…12). Making
   it solid would leave a 15 px gap and block the short return, so Hollow walks through it. Suggest
   swinging the leaf beside the right post in the art.
2. **Reset card size.** It uses the default 880×460 frame and leaves empty space below the text.
3. **Copy for review:** the reset body (now names the return gate) and the target footer.
4. **Title load warning.** "Some content could not load" moved into the first title button's tooltip,
   which makes it easy to miss.
5. **Screenshot not in repo.** Adrian's willow screenshot isn't in the repository. This pass worked
   from the probe, the art and native captures.

## 9. Build for Adrian and open acceptance

**Build:** the current uncommitted `dev` working tree in `C:\Users\Adrian\Code\Games\hollow-choir`
(after `6d8401d`, application 0.3.0, save 1). Run the project, then Title → **Continue journey**.

**Back up your save first.** Reset journey intentionally overwrites the one save slot
(`%APPDATA%\Godot\app_userdata\Hollow Choir\saves\slot_0.json`); copy it before trying the reset.
Automated runs used only throwaway QA homes and slot 98.

**Please check by hand:**

- Walk into every willow from all sides in both areas, including the Reedway banks, and behind the
  trunks.
- Walk into the lamp from both sides, the wayside bell roots, the stones, and the open gateposts.
- In battle, switch actions by mouse during review and use the Back route on keyboard and on a
  controller.
- Open, click and close the battle log, then keep planning by keyboard.
- Try Reset journey: Cancel, confirm, and the result after reloading.
- With a controller, walk at shallow stick angles.

**Still open:** human collision feel, controller, display at 1440p (unqualified on this display),
listening and art acceptance. Automated sweeps prove geometry against the art, not how it feels. The
neighbour-aware terrain, blending and post-effect pipeline remains a separate follow-up. The 0.4.0 bump
awaits Adrian's walkthrough.

## Files changed in this pass

| Area | Files |
|---|---|
| Scenes | `scenes/world/areas/gloamstead.tscn`, `briarfen_reedway.tscn`; new `scenes/world/footprints/willow_roots.tres` |
| Battle | `scenes/battle/battle_scene.gd`, `src/ui/battle/action_picker.gd` |
| World | `src/world/world_host.gd`, `world_session.gd`, `world_copy.gd`, `world_player.gd` |
| Audio | `src/autoload/audio_manager.gd`, `src/audio/music_mixer.gd` |
| Test runner | `tests/run_tests.gd` |
| Capture and probe tools | `tools/capture_runner.gd`, `capture_battle.gd`, `capture_world.gd`, `capture_world_runner.gd`, `probe_willow_footprint.gd`; new `tools/capture_collision.gd` and `capture_collision_runner.gd` |
| Docs | `docs/TESTING.md`, `docs/DATA_CONTRACTS.md` |
| Tests | the new suites above (with generated `.uid` files) |
| Evidence | this report and `docs/reports/v0_4_playtest_engineering/` |
