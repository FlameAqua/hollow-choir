# V0.4 First Footsteps — engineering review

Claude (lead gameplay/backend engineer) · 9 October 2026 · working tree on `dev` after `6d8401d`
**Not committed or pushed.** Application version stays **0.3.0**; save version stays **1**.

The journey is playable end to end from the title: **Continue journey** → Gloamstead square →
Bellkeeper / preparation bench → reed gate → Briarfen Reedway → fork / outside loop → optional
`fen_patrol` → `rot_grove` at the bell approach → ring the wayside bell → open the return latch from
its far side → home to a raised bell, lit lamp and the Bellkeeper's acknowledgement. Map, paused
world menu (Field Guide / Settings / Save / Save and return to title) and every battle boundary are
wired to one transactional save path. Presentation is **functional plain UI over candidate art**;
Director integration and all human acceptance gates remain open (see the end of this report).

## Architecture summary

| Layer | Files | Responsibility |
|---|---|---|
| Definitions | `src/world/{world,area,landmark,portal}_definition.gd`, `world_path.gd`, `data/world/first_footsteps.tres` | Stable IDs, public labels/descriptions, kinds, radii, safe anchors, encounter references, map polylines, paired portals. Loaded into `DefinitionRegistry.world` and validated with content. Runtime never reads `docs/`. |
| State | `src/world/world_state.gd`, `encounter_entry.gd` | Optional `world` save section; immutable captured entry; `sanitize()` against approved content. |
| Transactions | `src/world/world_session.gd` | Every safe boundary goes through `commit(mutator)`: copy progress → change copy → atomic write via injectable writer → adopt only on `OK`. |
| Rules | `src/world/world_rules.gd`, `world_copy.gd`, `readouts/*` | Pure derivation of objective, eligibility, dialogue, encounter card, bench weapons, discovered map. No quest stage. |
| Runtime | `src/world/world_host.gd`, `world_player.gd`, `world_area.gd`, `world_point.gd`, `world_portal.gd`, `world_state_view.gd`, `scenes/world/world_host.tscn`, `scenes/world/areas/*.tscn` | Input modes, area loading, feet movement, camera, portals, interaction routing, battle seam, modal presentation. |
| Plain UI | `src/ui/world/world_modal.gd`, `world_map_view.gd` | Dialogue / encounter card / bench / map / menu / notices; Director replaces. Existing `ExplorationHUD` + `ExplorationReadout` are reused unchanged. |
| Tools | `tools/build_world_areas.gd`, `tools/capture_world.gd` (+ runner) | One-shot area bootstrap (refuses to overwrite without `--force`); native world captures. |

**Reused unchanged:** BattleEngine, BattleSetup, PartyAutopilot/simulation, BattleScene's embedded
host mode, ProgressState fields, SaveManager atomic writes, SaveMigrator, InputBindings install/rebind,
ExplorationHUD/Readout, Field Guide and Settings screens, AudioManager (silence = empty cue).

## Public interfaces

- `WorldSession` — `open()`, `commit(mutator) -> Error`, `arrive(area, anchor)`, `save()`,
  `complete_interaction(area, landmark)`, `restore_bell(area)`, `open_latch(area, link)`,
  `choose_weapon(id)`, `begin_entry(site, approach) -> EncounterEntry`, `commit_victory(entry, result)`,
  `leave_entry(entry)`, `return_home(entry)`; `last_error`; `writer: Callable(ProgressState) -> Error`.
- `EncounterEntry` — `capture(...)`, `from_dict`/`to_dict`, getters returning copies,
  `build_setup(registry, library) -> BattleSetup` (fresh objects each call).
- `WorldState` — `fresh(def)`, `from_dict`/`to_dict`, `sanitize(def) -> PackedStringArray`, `flag()`,
  `is_cleared()`, `discover()`, `add_link()`.
- `WorldRules` — `objective`, `interaction_label`, `dialogue`, `encounter_card`, `bench_weapons`,
  `map_readout`, `on_far_side`, `can_ring_bell`.
- `WorldHost` — `load_area`, `interact`, `open_map`/`open_menu`/`open_bench`/`open_dialogue`/
  `open_encounter_card`, `engage`, `launch_battle`, `take_portal`, `readout()`, `map_readout()`;
  signals `area_loaded`, `mode_changed`, `modal_opened`.
- Additive hooks on existing code (defaults preserve old behaviour):
  `BattleScene.host_result` / `leave_text`; `FieldGuide`/`SettingsScreen.embedded` + `closed`;
  `SaveManager.write_progress(slot, progress)`; `PartyLoadout.from_ids(registry, ids)` (GameState's
  loadout builder now delegates to it); `DefinitionRegistry.world`; `SceneRouter.WORLD`;
  seven `InputBindings.WORLD_*` actions plus an `axis:<n>:<±1>` binding code.

## Battle and persistence seam (the chosen adapter)

1. **Engage** → `begin_entry` captures token `site#serial`, area, approach anchor, a seed from the
   world's *own* RNG, loadout IDs, bestiary levels, difficulty, assist and both assist overrides, and
   writes it as `pending_entry` with the approach as resume anchor **before** any battle exists.
   A pending entry blocks every further entry; `engage` ignores repeat calls while a battle is up.
2. The host embeds `BattleScene` with `embedded = true`, `host_result = true`,
   `record_progress = false`. The scene therefore never calls `GameState.record_battle`, never shows
   its own result panel and never claims recorded progress; it announces the outcome and emits
   `finished`. All research/presentation/timing code paths are the existing ones. Each fight starts
   from a fresh setup: full HP, configured starting Focus, fresh potion capacities (control C).
3. **Victory** → `commit_victory` applies the existing `ProgressState.apply_battle_result`, marks the
   site cleared, clears the pending entry, stores `last_applied_token` and sets the approach anchor in
   **one** write. Research-level announcements and the victory card follow only a successful write.
   Same token again → `ERR_ALREADY_EXISTS`, nothing written or awarded.
4. **Failed write** → nothing is adopted; a non-dismissable card offers *Retry save* / *Return to
   title*; the world stays frozen. On title return the disk still holds the pending entry, so the next
   run resumes at the approach with the encounter available.
5. **Defeat** → no research, mastery, stats or route progress. *Retry encounter* rebuilds the battle
   from the same entry (same seed, loadout, knowledge, settings; no write). *Return to Gloamstead*
   closes the entry and resumes at the square, keeping every committed victory, discovery and flag.
6. **Pause → Leave battle** (`setup_requested` in host mode) → closes the entry at the approach with
   no award. Quitting the app mid-battle reaches the same state on the next `open()`.

The standalone BattleScene Retry (seed + 1) and the Sandbox are untouched.

## Save impact

Additive optional `world` section; **no version bump**. Rationale: no existing field changes
meaning, missing section = default square, wrong types fall back to defaults, flags require a JSON
`true`, IDs are filtered against `data/world`. Older builds ignore the key (they would drop it on
their own next save — downgrade is not a supported path). Old V0.3 slots keep research, mastery,
loadout and stats (tested). The format is documented in `docs/DATA_CONTRACTS.md` §6.

## Map construction

`tools/build_world_areas.gd` bootstrapped both scenes once from the runtime definition; they are now
ordinary editable scenes. Layers: `Ground` (Director terrain atlas, 32 px), `GroundDetail` (empty,
for dressing), `LowDecoration`, `DepthSorted` (shared Y-sort: Hollow, Bellkeeper, groups, props,
facade walls), `Overhead` (detached roofs), `WorldLighting` (static dusk CanvasModulate),
`WorldEffects` (empty), `Collision` (separate painted TileMapLayer with physics, hidden at runtime;
`--world-collision` shows it), `Interactions` (WorldPoint per landmark), `Anchors` (Marker2D per safe
anchor), `Portals` (WorldPortal trigger rectangles). Footprints are small StaticBody2D boxes at the
foot (bell 54×20, bench 38×14, facades module width + 8 × 56, groups 32×10); glow, roofs and sprite
alpha never collide. Hollow uses a 10×6 feet box. Bell/lamp/latch/groups switch through
`WorldStateView` nodes bound to one typed condition each.

Gloamstead: water ring boundary, reed fence at x = 66 with a two-tile gate (rows 25–26), a fen
corridor east to the trigger (x 71–73), paths per layout widths, paved square (r 5.5) around the bell.
Reedway: water everywhere except the authored paths (main paths = peat bank with a one-tile central
boardwalk; outside loop/overlook = peat), landmark pads, an entry corridor south to its trigger and a
one-tile latch barrier across the short return at row 63.

## Changes from the contract and decisions taken (please review)

1. **Anchor positions differ from landmark tiles where needed:** reed gate arrival at tile (63,26)
   inside the fence; Reedway entry trigger at the south edge below (22,76); encounter approaches
   ~7 tiles before each group (patrol (27,47.5), guard (52.5,26.2)); wayside bell anchor one tile
   south of the bell; latch anchor at (65,61) on the far side. Tests require every anchor to sit
   outside triggers, walls and engage radii, and within reach of its own interaction.
2. **Encounter card trigger:** the card opens on entering the radius (rule 2) and re-arms only after
   leaving radius + 24 px; Confirm reopens it deliberately. The **guard sits on the junction where the
   main path, outside loop and far-side path meet**, so reaching the far side passes its radius once
   (Leave costs nothing). Proposal if unwanted: move `GuardGroup` + its point to ≈(62,22) on the bell
   steps.
3. **Groups do not block passage** (32×10 footprints) — matches "blocks only bell interaction" and
   keeps the far-side latch independent of the guard.
4. **Defeat records nothing**, including `battles_lost` (no failed-attempt record of any kind).
   Victory still increments `battles_won` through the existing rule.
5. **Menu:** separate *Save* and *Save and return to title*; title return saves first and offers the
   failure card if that write fails.
6. **Explicit save keeps the last committed safe anchor** instead of picking the nearest one, so a
   save near the closed latch can never resume on its far side. Discoveries/walked links enter live
   state immediately and persist with the next safe boundary.
7. **Every completed interaction is a save boundary**, including closing the Bellkeeper's lines or
   the bench; cheap, and it keeps discoveries safe.
8. **Town bell offers no interaction** (no approved copy); the bell is a visible consequence only.
9. **Threat categories** are "Patrol" and "Guard"; creature names appear only at Observed or better.
10. **Bench** shows family, damage type, description and actions from the shared definitions (no
    numbers). Choices persist as `loadout_weapon` and feed the next entry snapshot.
11. **Camera:** 2× zoom, clamped to area bounds, offset 24 world px upward so Hollow clears the HUD
    header. No pixel snapping yet (possible sub-pixel shimmer — evaluate in the human pass).
12. **Theme fix:** Controls under a CanvasLayer do not inherit the window theme; the host assigns the
    game theme to the HUD, modal and embedded-battle roots (regression-tested).
13. **Version:** left at 0.3.0. Recommend the 0.4.0 bump once Director integration and the human
    walk-through accept the loop — Adrian's call.

## Verification (actual results)

Baseline before any change (current tree, isolated home): **213 passed / 0 failed / 1,721 assertions**.

Final checks ran on a **fresh copy of the working tree** (no `.godot`, cold import, isolated homes):

| Check | Result |
|---|---|
| Cold `--import` | clean (no errors) |
| `tools/check_scripts.gd` | **223 scripts, 0 failed** |
| Full Godot suite, run alone | **252 passed, 0 failed, 2,506 assertions** (56.3 s), exit 0 |
| Diagnostics | the 4 documented invalid-save errors, the documented rejected-action warning, plus intended `WorldSession` sanitise warnings from the invalid-anchor test; nothing else |
| Simulation smoke (`--encounter=all --exec=MIXED --runs=10 --seed=1`) | exit 0, 0 errors; output **identical** to a clean clone of `6d8401d` (91 lines) |
| Python (`unittest`, music prep/import) | **9 tests OK** |
| `tools/validate_world_art.gd` | **204 checks, 0 failures** |

New suites (39 tests): `tests/world/test_world_session.gd` (15), `test_world_rules.gd` (8),
`test_world_host.gd` (16), helper `tests/fixtures/world_kit.gd`. They cover the handoff list:
portals cannot bounce (and unarmed triggers wait for exit), Cancel cannot launch, an entry launches
once, duplicate victory cannot award twice, a failed save publishes nothing and retries, defeat/retry
reuses the exact entry (identical battle fingerprint), quitting during battle restores the approach,
clear flags survive reload, the far-side latch works independently of the bell, completing before
dialogue works, old slots keep real progress, unknown map facts stay hidden (text/name/tooltip scan),
modal input cannot move, held inputs need release, focus loss pauses, Field Guide/Settings return to
the paused world, and the world entry's battle fingerprint equals a directly built setup's.

## Native captures (fixed 1280×720 layout)

All in [`v0_4_engineering/`](v0_4_engineering/), produced with `tools/capture_world.gd`
(`--hidden --rendering-method gl_compatibility --audio-driver Dummy`). They are **capture fixtures**:
the runner seeds an in-memory world state, places Hollow and opens modals directly.

| Capture | Shows |
|---|---|
| [town.png](v0_4_engineering/town.png) | Gloamstead square, quiet bell, unlit lamp, HUD objective |
| [town-restored.png](v0_4_engineering/town-restored.png) | answering bell, lit lamp + warm light, "The town bell answers again." |
| [dialogue.png](v0_4_engineering/dialogue.png) | Bellkeeper (before), one speaker, two paragraphs, Close |
| [bench.png](v0_4_engineering/bench.png) | three owned starter weapons, resource rule, shared action text |
| [route.png](v0_4_engineering/route.png) | Reedway fork, boardwalk on walkable bank |
| [patrol.png](v0_4_engineering/patrol.png) | stationary patrol group on the main boards |
| [encounter.png](v0_4_engineering/encounter.png) | card: Patrol · 3 unknown creatures · Flooded Ground · reset rule · Engage/Leave |
| [map.png](v0_4_engineering/map.png) | discovered landmarks and walked links only, player marker, descriptions |
| [menu.png](v0_4_engineering/menu.png) | paused world menu and save explanation |
| [latch.png](v0_4_engineering/latch.png) | far side of the closed latch with the "Open the return gate" prompt |
| [collision.png](v0_4_engineering/collision.png) | graybox evidence at the reed gate (debug collision draw, feet box) |
| [battle.png](v0_4_engineering/battle.png) | unchanged presenter embedded by the world host |

## Art status (blockout vs candidate vs finished)

- **Blockout/graybox (backend):** collision layer and its generated hatch tile, footprints, portal
  rectangles, path/pad geometry, plain modal/map UI, engineering copy (prompt verbs, map
  descriptions, latch far/open lines, save/defeat/victory text, menu note).
- **Candidate art (Director pack v01, generated, not artist-cleaned):** terrain atlas, Hollow
  walk/idle, Bellkeeper idle, both group idles, props, facade walls/roofs. Attached as delivered.
- **Finished:** none of the world art is claimed final. Existing combat art is unchanged.

Art notes from integration: the reed-gate source is a north–south gateway but the exit crosses the
fence east–west, so its posts read across the path; packed-path tiles show strong vertical banding at
2×; the generated bell/lamp pairs differ slightly beyond the changed component; willow canopies
touch their cell edge. Reduced motion holds NPC/group idles on frame 0; walking always animates.

## Remaining Director integration

1. Replace the plain modals/map with final UI using the typed readouts (`WorldDialogueReadout`,
   `EncounterCardReadout`, `WorldMapReadout`, `ExplorationReadout`); finalize engineering copy.
2. Dress `GroundDetail`/banks/roof joins; tune facade footprints, sightlines, the guard position
   (decision 2), camera framing and pixel snapping; retarget the reed gate art.
3. Update the Field Guide empty state, which still tells players to use Sandbox → Lab to record
   progress (the world now records victories).
4. Decide the 0.4.0 bump after review; optional exploration music cue (`AreaDefinition.music_cue`).

## Human acceptance — still open

Walk the route without coaching (find the bypass, identify the home change and the return shortcut);
keyboard **and controller** traversal, remapped prompts and focus-loss behaviour; quit/reload at each
boundary on a real profile copy; legibility of the plain UI at supported presets; the M1.1 combat
clarity, controller and listening sessions. Automated evidence does not fill these observations.
The synchronized-audio pilot was not started (separate authorization, not a dependency).

## Future extension points

New areas join through `AreaDefinition` + `PortalDefinition` + an area scene with the same layer
names; new interactions add a `LandmarkDefinition.Kind` and one `WorldRules` branch; new world flags
extend `WorldDefinition.flags` and `WorldState` explicitly (no expression strings); exploration music
uses `music_cue`; `WorldSession.writer` lets future slot pickers or cloud saves reuse the transaction.
