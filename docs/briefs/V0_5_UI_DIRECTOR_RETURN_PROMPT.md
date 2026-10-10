# V0.5 UI backend — Return prompt for the Creative & Frontend Director

10 October 2026 · from Claude (Lead Architecture, Systems & Backend) · shared uncommitted `dev`
tree · application 0.5.0 / save version 1 (both unchanged)

---

You are continuing Hollow Choir as Creative & Frontend Director. Claude has completed your V0.5 UI
backend handoff (`docs/briefs/V0_5_UI_BACKEND_HANDOFF.md`), final verification included. All six
items are now real transactions:
- New Journey;
- a hardened Continue;
- one owner for the save event;
- field Equipment and supplies;
- typed Forge and Stillroom services;
- the saved Combat arrangement: six usable positions of eight.

Check `git status` first and preserve all uncommitted work. Do not reset, commit, push, change
versions or regenerate authored areas.

## Where to find what changed

1. **`docs/reports/V0_5_UI_BACKEND_IMPLEMENTATION.md`**, the main entry point:
   - §0: decisions for you and Adrian. Read this first.
   - §1: what changed, item by item.
   - §2: every created and modified file, including the functional edits in your files.
   - §3: save impact. Save version 1 stays compatible.
   - §4: **your API guide** for the title, Equipment, Combat, the stations and copy.
   - §5: verification, and the four fixes made during it.
   - §6: screenshots. §7: limitations. §8: open human gates.
2. **`docs/DATA_CONTRACTS.md`**, section "V0.5 UI backend". It covers save slots, New Journey, save
   events, field commands, station services and the Combat arrangement. Older sections that made the
   bench the equipment context now carry "superseded" notes.
3. **`docs/TESTING.md`**, section "V0.5 UI backend (Claude, 10 October)". It lists the new suites,
   capture states and demos, the tool compile check and the rule for walking the player in tests.
   §2 lists the diagnostics a passing run is expected to print.
4. **Screenshots** in `docs/reports/v0_5_ui_backend/`: the title's saves, the slot step, the Replace
   card, Combat, the Magic filter, field Equipment, the Forge and the Stillroom. They are fixtures,
   not a human playthrough.
5. **`docs/briefs/CLAUDE_RETURN_QUEUE.md`**: the top entry is the short summary.

## Your files that Claude changed

Only functional changes. Your layouts and node names are kept.

- `scenes/main/main_menu.gd`:
  - the New Journey listener, connected in `_ready`;
  - the explicit slot step;
  - the Replace card, with Cancel focused;
  - typed save summaries;
  - handling of a save that changed after the list was built;
  - the `enter_world` and `journey_writer` test seams.

  Your `{difficulty, preset_id}` emit is unchanged.
- `src/world/world_host.gd`:
  - each station's service comes from its landmark;
  - Character field, potion and combat commands;
  - all seven `push_notice("Game Saved")` calls are removed: `WorldSession.commit()` now emits
    `EventBus.game_saved` once, after the new state is adopted;
  - the notice layer hides while a battle owns the screen;
  - a difficulty change in Settings becomes the journey's;
  - the `quit_game` and `leave_to_title` test seams.
- `src/ui/world/world_character_view.gd`: the saved `CombatReadout` replaces `_preview`. Selecting a
  position, then a candidate, sends PUT. The help and label copy now say the arrangement is real.
- `src/ui/battle/presentation/item_inspection_readout.gd`: the sentence about stations.
- `tests/world/test_world_ui_prototype.gd`:
  - the old preview and `NO_STATION` assertions now match the real transactions;
  - one line was added to the station walk, `await tree.physics_frame`. Without it the walk
    distance depended on frame time and the test failed intermittently (report §5, item 2).
- `tests/world/test_world_v05_integration.gd`: each station opens from its own landmark.
- `tools/capture_runner.gd` gains the `title-slot` and `title-replace` states.
- `tools/capture_world_runner.gd`: each station state opens from its own landmark.

## Integration seams (details in report §4)

- **Title.**
  - `JourneyRules.setup(...)` returns difficulties, presets (with icons and facts), slots and the
    suggested slot.
  - After your `{difficulty, preset_id}` emit, the listener runs the slot step. With your own slot
    UI, emit `{…, slot, replace}` and read the reason from `GameState.last_journey.text()`.
  - Continue reads `SaveManager.journeys()`.
- **Equipment.**
  - Each option's `selectable` and `reason_text` follow the field rules.
  - `option.combat.removed` and `option.combat.added` preview how the Combat arrangement changes.
  - After a command, the host shows `session.last_preparation.summary()`.
- **Combat.**
  - `session.combat()` drives the view.
  - Place an action with `combat_requested.emit(&"put", position, action_id, -1)`.
  - `(&"swap", first, &"", second)` and `(&"move", position, action_id, -1)` are ready for drag and
    drop.
  - The status line is `session.last_combat.text()`.
- **Stations.**
  - `CraftingReadout.service` names the open station.
  - Each recipe's `purchase_reason_text` names the station that does its work.
  - The display counts are published, so nothing needs to be hard-coded: `FITTING_SOCKETS`,
    `POTION_POSITIONS`, `fitting_capacity`, `potion_capacity` and `locked_reason_text`.

## Your tasks

1. Restyle the slot step and the Replace card. They are functional engineering UI built from your
   style components; the final look and copy are yours.
2. Replace the placeholder copy in `WorldCopy`:
   - `JOURNEY_*`, `SAVE_SLOT_*` and `COMBAT_*`;
   - `CRAFT_WRONG_STATION_*`, `PREP_SAVED` and `PREP_UNCHANGED`;
   - the re-pointed `REWARD_*_NEXT` and `MATERIALS_NOTE`.
3. A layout call: at a station, a save card covers the bottom-right Close button for about 3.4
   seconds. The card ignores the pointer, so Close still works, but it is hidden.
4. Optional: drag and drop in Combat, using SWAP and MOVE above.
5. Optional: retire `WorldHost.open_bench` and `WorldPreparationView`. Players can no longer reach
   them, but tests and one capture still use them.
6. Optional: clear the editor warnings in your files. A warnings scan against `35c8763` found:
   - `world_crafting_view.gd:31`: the loop variable `material` shadows `CanvasItem.material`;
   - `world_map_view.gd:48/67/85`: `scale` shadows `Control.scale`;
   - `world_preparation_view.gd:103/140`: `first` is used before it is assigned.
7. When you change presentation, update the assertions in `test_world_ui_prototype`,
   `test_world_v05_integration` and `test_world_combat_arrangement` instead of removing coverage.
   Run the full suite alone through `tools/qa_godot.py`, both headless and Compatibility/Dummy.

## Decisions to rule on (report §0; the Decision Log is yours)

1. **Difficulty is per journey (amends D-009).** New Journey records it and encounter entries
   capture it. Settings can still change it at any time, and the journey follows. Please log the
   amendment.
2. **Kindle starts unplaced.** Every starter grants seven actions for six positions. The default
   arrangement is the first six, Actions then Magic. Confirm, or name another action to leave out.
3. **Older saves default to Adventurer.** They have no recorded difficulty.
4. **Freed positions refill in grid order** after a gear change. There is no per-weapon memory.
5. **Re-choosing the equipped item writes nothing.** V0.5A wrote a save.
6. **Notices hide while a battle owns the screen.** The encounter entry saves just before the
   battle launches, and its card would otherwise cover the battle's action dock. Cards created
   during the battle still expire on their usual timer.

A tooling note, not a decision: `validate_material_polish.gd` still checks the Hollow's `v04`
frames, while the game shows `v05`. It passes, so it can wait.

## Verification (final tree)

- **Suites:** headless 450 passed, 0 failed (7,248 assertions). Compatibility/Dummy 450 passed,
  0 failed (7,272).
- **Compile checks:** all 315 scripts compile. All 20 tool entry points compile before autoloads.
- **Unchanged combat:** 120 battles and the simulation smoke are identical to `35c8763`.
- **Validators:** material polish 264/0. World art 376/0; its stale `v03` check was fixed separately.
- **Python, demos and mutations:** 10 Python tests pass, demos A, B and C finish, and 28 of 28
  mutation checks are caught.

Human, controller, art and listening gates remain **open**.

## Please return

- A Director acceptance note under `docs/reports/` that rules on decisions 1–6, with Decision Log
  entries.
- Your presentation report with rendered evidence after the restyle.
- Then the integrated V0.5 build goes to Adrian for the full human test (report §8 lists it).
