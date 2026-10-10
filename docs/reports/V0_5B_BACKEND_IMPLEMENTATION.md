# V0.5B — Forge and Stillroom backend

Claude · 10 October 2026 · uncommitted `dev` after `35c8763` · application 0.5.0 / save version 1
**Not committed or pushed. No version bump, no save-version bump, no combat-rule or balance change,
no area regeneration and no new screen.** This answers [the V0.5B specification](../briefs/V0_5B_BACKEND_HANDOFF.md)
inside the [continuation sequence](../briefs/V0_5_CONTINUATION_FOR_CLAUDE.md) and stops at the backend
seam. V0.5C was done in the same session at Adrian's request; it has its own
[report](V0_5C_BACKEND_IMPLEMENTATION.md).

The fitting kit and both Stillroom recipes can be bought with salvage at the preparation bench.
Merciful Grip or Hollow Echo can be fitted to Pilgrim's Edge (or neither), free of charge. The kit
refunds exactly. The two recipes add Clotting Salve and Focus Tincture to the campaign's two potion
slots. Everything reaches the next immutable encounter entry and real battles. **No screen presents
this yet:** the commands, readouts, tests and two demonstration fixtures exercise it; Codex owns the
station screens (§9).

## 0. Return package

| Brief item | Status |
|---|---|
| Production commands with successful and failing writers | `WorldSession.purchase/refund/fit/remove_fitting/prepare_potion` (§4), 14 production-session tests (§8) |
| Typed recipe/cost/modification definitions, saved unlocks and fitting, readouts | §2, §3, §5; `DATA_CONTRACTS.md` field reference + "V0.5B Forge and Stillroom" |
| Snapshot/retry immutability; real battle trait behavior; potion preparation into battle | §6, §8 |
| `docs/reports/V0_5B_BACKEND_IMPLEMENTATION.md` | This report |
| Updated `DATA_CONTRACTS.md` / `TESTING.md` | Done (save format, field reference, contracts, test guide) |
| Exact verification; API/fixture guide for Codex | §8, §9 |
| Isolated demo | `tools/demo_v05b.gd` (output in §8) |

Inherited evidence, kept separate: before any change in this session, the current tree's full suite
ran **371 passed, 0 failed, 5,295 assertions** headless (111.83 s) in an isolated QA home. That
matches the A follow-up's 371/0 count. All later numbers are new runs on new work.

## 1. What is connected for a player, and what is not

| Path | State |
|---|---|
| Buying, refunding, fitting, preparing potions | **API only.** The bench opens the station context (V0.5A) and the commands work through it, but no button calls them. |
| A fitting or a recipe potion in battle | **Connected** once set: the next `EncounterEntry` captures it and battle builds it. |
| Inventory "materials" note | Changed. The V0.5A line "Materials have no use in this build" would now be false. It is a provisional placeholder (§11). |
| Equipment preparation | Unchanged, except one new typed rejection: `DUPLICATE_TRAIT` (§5). |
| Character menu Skills | Lists an active fitting's passive. It reads the same campaign loadout as battle. |

Adrian cannot buy anything in today's build without a station screen.

## 2. Economy (shipped data, exactly as specified)

| Recipe (`id`) | Station | Cost | Mastery | Refund | Unlocks |
|---|---|---|---|---|---|
| Fitting kit (`forge.first_fitting`) | Forge | 2 Bog Iron | ≥ 1 saved point on any owned Pilgrim's Edge, Mire Maul or Reedbow | Exactly 2 Bog Iron; clears the fitting | One fitting on Pilgrim's Edge: Merciful Grip, Hollow Echo or none |
| Clotting Salve recipe (`stillroom.clotting_salve`) | Stillroom | 1 Bog Iron | — | None (permanent) | Clotting Salve as a campaign potion choice |
| Focus Tincture recipe (`stillroom.focus_tincture`) | Stillroom | 1 Storm Salt | — | None (permanent) | Focus Tincture as a campaign potion choice |

- **Totals.** All purchases come to 3 Bog Iron + 1 Storm Salt, against the route's 4 + 1.
- **Purchase order.**
  - Guard salvage alone (2 + 1) buys kit + tincture.
  - The patrol's 2 iron then funds the salve, leaving 1.
  - All six purchase orders end with everything owned (tested).
- **Stillroom vocabulary.**
  - Clotting Salve: Base "Prepared salve", Reagent Bog Iron.
  - Focus Tincture: Base "Clear tincture stock", Reagent Storm Salt.
  - No Catalyst.
  - Bases are reusable home supplies. They are not saved stacks or hidden costs.
- **Starter potions.** Mending Draught and Fen Water Flask stay free starters. They come from
  `GameDefaults.starter_loadout`.
- **No other changes.** No potion effect, charge, capacity or combat number changed. Practice and
  the Lab still audition every authored potion.

## 3. Architecture

```
data/crafting/*.tres (RecipeDefinition + MaterialCost) ─┐
data/modifications/*.tres (ModificationDefinition) ─────┴─ DefinitionRegistry .recipes .modifications
                                                            └─ CraftingRules.validate_catalog
CraftingRules (pure): availability · purchase/refund/fit/potion checks · purchase/refund/set_* ·
  capacity (kit owned + mastery met; derived, never saved) · active_modifications · duplicate_trait ·
  potion_unlocked · repair (reconcile) · readouts (CraftingReadout, RecipeReadout, FittingReadout,
  PotionSlotReadout)
PreparationRules: campaign_ids / battle_ids / campaign_loadout = saved loadout + resolved fittings;
  equip check gains DUPLICATE_TRAIT; repair_loadout → CraftingRules.repair
WorldSession: purchase · refund · fit · remove_fitting · prepare_potion · crafting() · last_crafting
  └─ _station_command: station + pending check → typed check → (no-op) → commit → publish once
       └─ EventBus.crafting_completed(CraftingResult) after adoption only
ProgressState: crafting_recipes, weapon_fittings (save `crafting` section, outside `world`)
EncounterEntry.capture(..., modifications) → PartyLoadout.modifications → UnitFactory adds the trait
```

- **Data.** Definitions are typed Resources. Prices, thresholds and choices are data; no code names them.
- **Pure rules.** `CraftingRules` takes the progress and registry it acts on. It names no autoload
  and no UI class.
- **No manager.** I added no economy manager or station service. `WorldSession` remains the only
  owner of writes. The bench's existing station context hosts both services.
- **Trait reuse.** The fittings reuse the authored traits by reference.
  `ModificationDefinition.resolved_trait()` returns the very `TraitDefinition` held by
  `merciful_iron.tres` or `hollow_reliquary.tres`.
  - No trait was copied, no shared weapon Resource was edited, and Pilgrim's Edge keeps
    `socket_count = 0`.
  - Neither item is granted.
  - **Mismatch check:** none found. Both triggers watch the reacting unit with relation OWNER
    (the trait's holder). They behave identically on the Hollow whether the trait comes from the
    original item or the fitting.

## 4. Commands, transactions and receipts

| Command | Effect (one write) |
|---|---|
| `purchase(recipe_id)` | Spends the whole price and records the unlock |
| `refund(recipe_id)` | Refundable only. Returns the exact price, clears the unlock and that weapon's fitting together |
| `fit(weapon_id, fitting_id)` / `remove_fitting(weapon_id)` | Free; the fitting stays installed when another weapon is equipped and applies whenever Pilgrim's Edge is equipped |
| `prepare_potion(slot_index, potion_id)` | Slot 0 or 1; a starter or an unlocked recipe potion, not already in the other slot |

**Common rules for every command:**
- **Context.** Every command needs the bench's station context and no pending encounter.
- **Write path.** Each runs through `commit()`: copy → change → write → adopt.
- **Receipts.** `last_crafting` holds the result, including `spent` / `refunded` receipt lines
  `{id, name, icon_path, count, total}`. They exist only after a successful write.
- **Publishing.** `EventBus.crafting_completed` fires once, after adoption.
- **Failed writes.** A failed write changes nothing (materials, recipes, fittings, loadout,
  receipts) and publishes nothing. Repeating the command is the retry, and it publishes once.
- **No-ops.** Re-choosing the installed fitting or the prepared potion is accepted
  (`changed = false`) and writes nothing.
  - V0.5A's equip still writes on a re-choice, which also charts the bench.

| Reason | Error | When |
|---|---|---|
| `NO_STATION`, `ENCOUNTER_PENDING` | `ERR_UNAVAILABLE` | No bench interaction open; an entry is pending or in battle |
| `ALREADY_OWNED` | `ERR_ALREADY_EXISTS` | Duplicate purchase: never spends again |
| `UNKNOWN_RECIPE`, `UNKNOWN_FITTING`, `UNKNOWN_POTION` | `ERR_INVALID_PARAMETER` | Not approved content |
| `INSUFFICIENT_MATERIALS`, `MASTERY_REQUIRED` | 〃 | Price or mastery not met |
| `RECIPE_NOT_OWNED`, `NOT_REFUNDABLE`, `REFUND_OVERFLOW` | 〃 | Refund of nothing (no credit); a Stillroom recipe; a stack would pass 999 (rejected whole, never saturated) |
| `WRONG_WEAPON`, `WEAPON_NOT_OWNED`, `NO_FITTING_CAPACITY` | 〃 | No kit serves the weapon or the fitting is not its choice; weapon not owned; kit not owned |
| `DUPLICATE_TRAIT`, `ACTION_LIMIT` | 〃 | The resulting loadout would carry the trait twice, or exceed eight actions |
| `POTION_LOCKED`, `DUPLICATE_POTION`, `INVALID_POTION_SLOT` | 〃 | Recipe not owned; already in the other slot; not slot 0/1 |
| `WRITE_FAILED` | writer's error | Valid; live state unchanged; station kept for Retry |

The zero-mastery reason reads: "Needs 1 weapon mastery point with Pilgrim's Edge, Mire Maul or
Reedbow. Use one of them in a battle that records progress." Route completion never needs the kit.

## 5. Fittings, capacity and duplicate traits

- **Capacity.** Capacity is derived, never saved: the kit owned and its mastery met. Purchase
  already requires the point, and mastery never decreases. So in practice only an edited save holds
  the kit without capacity. The readout then shows `MASTERY_REQUIRED`.
- **Active fittings.** A saved fitting takes effect only when three things hold:
  - its weapon is equipped;
  - the weapon has capacity;
  - the id is one of the kit's approved choices.

  Unknown or unoffered ids stay in the save, inert.
- **Duplicate traits** are judged on the loadout a command would produce for the next encounter,
  in both directions:
  - Fitting Hollow Echo while the Hollow Reliquary and Pilgrim's Edge are equipped →
    `CraftingResult.DUPLICATE_TRAIT`.
  - Equipping the reliquary, or re-equipping Pilgrim's Edge, while an Echo fitting would be
    active → the new `PreparationResult.Reason.DUPLICATE_TRAIT = 9` (append-only).

  Nothing is doubled, dropped or removed. With Mire Maul equipped the Echo fitting is inactive, so
  the reliquary is allowed. Then the sword cannot be re-equipped until one source goes.
- **Battle.** `PreparationRules.battle_ids()` is the saved loadout plus the resolved
  `"modifications"`. `EncounterEntry.capture()` records them, so a retry never reads live unlocks.
  `UnitFactory` adds each fitting's trait after the weapon's own, with the source
  "Pilgrim's Edge fitting". Pilgrim's Patience, the actions, damage, Stagger, resonance and stance
  are untouched; a fitting adds no action.
- **Real behavior (tests).**
  - Merciful Grip: Good window ×1.6, Perfect window ×1.5, Perfect multiplier 1.07 (1.15 without).
  - Every successful Hollow Parry triggers the fitting and restores exactly 8 HP.
  - Hollow Echo exposes each parried attacker's weak point.
  - Without a fitting neither happens.

## 6. Potions, save and compatibility

- **Potion slots.** Potions sit in the battle's Supplies slots, not the eight-action grid. So
  "full loadout within eight actions, including the two potion slots" means two things: the grid
  stays ≤ 8 and the potions stay within `MAX_POTION_SLOTS`. Both are checked; a potion never
  changes the action count.
- **Charges.** A recipe unlocks selection only. In battle the potion keeps its authored charges
  (tested: Focus Tincture ×1, used for +4 Focus).
- **Save.** The format change is the additive `"crafting": {"recipes": [...], "fittings": {weapon: fitting}}`.
  - It sits outside `world`: Reset journey keeps it, reload keeps it, New Game has none.
  - `from_dict` keeps string entries only.
  - Captured entries gain `loadout.modifications`; older entries have none.
  - Save version stays 1; no migration was needed.
- **Reconciliation** (world entry, never a deserializer; after the V0.5A equipment repair):
  - An approved prepared potion whose recipe is not owned stays prepared, and its recipe is
    recorded as unlocked with no material charge (as V0.5A grandfathers gear).
  - An unknown potion id becomes the first free starter not already prepared.
  - Entries beyond two are removed.
  - A fitting duplicating an equipped trait is removed; the gear is kept.
  - With nothing to repair it writes nothing.

## 7. Files

**Created:**
- `src/data/crafting/`: `material_cost.gd`, `recipe_definition.gd`, `modification_definition.gd`
- `src/progression/crafting_rules.gd`
- `src/progression/readouts/`: `crafting_result.gd`, `crafting_readout.gd`, `recipe_readout.gd`,
  `fitting_readout.gd`, `potion_slot_readout.gd`
- Data:
  - `data/crafting/forge_first_fitting.tres`, `stillroom_clotting_salve.tres`, `stillroom_focus_tincture.tres`
  - `data/modifications/merciful_grip_fitting.tres`, `hollow_echo_fitting.tres`
- Tests: `tests/unit/test_crafting_rules.gd`, `tests/world/test_world_crafting.gd`
- Tools: `tools/demo_v05b.gd`, `demo_v05b_runner.gd`
- Godot `.uid` files for each new script

**Modified:**
- `src/progression/progress_state.gd`: `crafting_recipes`, `weapon_fittings`,
  `has/add/remove_recipe`, parsing and the save section.
- `src/progression/preparation_rules.gd`:
  - `campaign_ids`, `battle_ids`, `campaign_loadout`, `held_materials`;
  - the duplicate-trait equip check;
  - campaign-loadout action counts;
  - crafting repair in `repair_loadout`.
- `src/progression/readouts/preparation_result.gd`: `DUPLICATE_TRAIT`.
- `src/progression/readouts/character_readout.gd`: uses the campaign loadout and lists an active
  fitting's passive. This is Codex's V0.5A file; it was a 10-line backend readout change.
- `src/data/encounters/party_loadout.gd`: `modifications`.
- `src/battle/rules/unit_factory.gd`: fitting traits, `fitting_source()`.
- `src/core/definition_registry.gd`: `recipes`, `modifications`, crafting catalog.
- `src/core/enum_text.gd`: `station`.
- `src/world/encounter_entry.gd`: captured `modifications`.
- `src/world/world_session.gd`: station commands, `crafting()`, `last_crafting`, capture.
- `src/world/world_copy.gd`: `CRAFT_*`, `PREP_DUPLICATE_TRAIT`, `MATERIALS_NOTE`.
- `src/autoload/event_bus.gd`: `crafting_completed`.
- Docs: `DATA_CONTRACTS.md`, `TESTING.md`, `briefs/CLAUDE_RETURN_QUEUE.md`.

## 8. Verification (exact runs, isolated `.godot/qa` homes, Godot 4.7.2)

| Check | Result |
|---|---|
| Baseline before any change (full suite, headless) | 371 passed, 0 failed, 5,295 assertions (111.83 s). Inherited tree, recorded first |
| Full suite, headless, final tree | **403 passed, 0 failed, 6,232 assertions** (112.12 s) |
| Full suite, hidden Compatibility window, Dummy audio, final tree | First run 402 passed, 1 failed (6,256 assertions); second complete run **403 passed, 0 failed, 6,256 assertions** (109.73 s). Details below the table |
| New suites (final focused runs) | `test_crafting_rules` 7/0 (150) · `test_world_crafting` 14/0 (561) · `test_exploration_rules` 6/0 (117) · `test_world_exploration` 5/0 (109). Also re-run: `test_world_preparation` 9/0, `test_world_rules` 9/0, `test_content` 8/0 |
| Scripts (`check_scripts.gd`) | 298 checked, 0 failed (274 + 24 new) |
| Content validation | `test_content` 8/0: the new data validates, including the crafting catalog and route budget |
| Determinism probe (scratch, both trees) | 120 battles, total `8c68fa1d…6e1952`, identical per battle to a fresh `35c8763` clone. Each encounter × the four shipped loadouts plus the sword with the Storm Salt Charm × seeds 11/222/3333 on Adventurer/Standard; hashes every event field and the input log. No battle without a fitting changed |
| Simulation smoke (`--encounter=all --exec=MIXED --runs=10 --seed=1`) | Identical to the clone except elapsed time |
| Mutation checks (scratch copy) | **42 of 42 caught**: 26 V0.5B (listed below) and 16 V0.5C ([C report](V0_5C_BACKEND_IMPLEMENTATION.md)) |
| Demos (`demo_v05b.gd`, `demo_v05c.gd`, fresh QA homes) | Both exit 0, no exit-time leak report |
| Material polish (`validate_material_polish.gd`) | 264 checks, 0 failures |
| Python (`unittest discover`) | 10 tests OK |
| Whitespace | `git diff --check` clean; new files are LF, with a final newline and no trailing whitespace |

**New tests.** The 32 new tests are `test_crafting_rules` 7, `test_world_crafting` 14,
`test_exploration_rules` 6 and `test_world_exploration` 5 (371 + 32 = 403).

**Expected diagnostics in every full run, and nothing new:**
- 4 invalid-save errors;
- 1 "rejected action (Needs 5 Focus)" warning;
- 5 world-session recovery warnings.

**The first rendered run's failure.**
- **Test:** `test_fifth_playtest::test_right_click_pins_and_fields_explain_without_replacing_the_card`.
- **Symptom:** while hovering Focus, the inspector card was 918 px tall (limit 720).
- **Re-runs:** that suite passed alone twice (5/0, 91 assertions), and the second complete rendered
  run passed.
- **Scope:** the test drives battle hover UI that this session did not touch. I treat it as an
  intermittent hidden-window pointer fixture; hidden-window runs share Adrian's desktop pointer
  and focus. It is reported, not fixed here.

Mutation checks ran on a scratch copy of the tree (never the repo). Each reverts one behavior, and
the relevant suite must fail without a parse error. **All 26 V0.5B mutations were caught:**

1. Purchase spends nothing.
2. Purchase ignores mastery.
3. Purchase ignores the price.
4. A duplicate purchase is allowed.
5. Refund keeps the fitting.
6. Refund saturates at the cap.
7. Stillroom recipes are refundable.
8. Refunding an unowned recipe credits materials.
9. A fitting is installed without capacity.
10. Fit ignores duplicate traits.
11. Fit ignores the action ceiling.
12. Equip ignores duplicate traits.
13. Locked potions are selectable.
14. Duplicate potions are allowed.
15. No station check.
16. Published before the write.
17. A failed write keeps a receipt.
18. No-ops write.
19. Capture drops fittings.
20. Battle ignores fittings.
21. Capacity without mastery.
22. Crafting is not saved.
23. No potion grandfathering.
24. No route budget check.
25. A duplicate fitting is not repaired.
26. Unoffered fittings are active.

Two of these (no-ops write; unoffered fittings active) first survived. I strengthened the tests,
and both were then caught.

Demo output, verbatim (public results only):

```
1. New game in throwaway slot 7. Recipes: []. Materials: none. Mastery: none.
2. Guard victory and bell committed. Held: 2 Bog Iron, 1 Storm Salt. Pilgrim's Edge mastery: 6.
3. Away from the bench: purchase → Unavailable (Use the Forge and Stillroom at the preparation bench.)
   At the bench (station: preparation_bench):
      Forge · Fitting kit · 2 Bog Iron (held 2) · available
      Stillroom · Clotting Salve recipe · 1 Bog Iron (held 2) · available
      Stillroom · Focus Tincture recipe · 1 Storm Salt (held 1) · available
      Pilgrim's Edge fitting: none (Buy the fitting kit at the Forge to fit this weapon.)
      Potion slot 1: Mending Draught
      Potion slot 2: Fen Water Flask
   purchase(forge.first_fitting) → OK: Spent 2 Bog Iron Held: 0 Bog Iron, 1 Storm Salt.
   purchase(stillroom.focus_tincture) → OK: Spent 1 Storm Salt Held: 0 Bog Iron, 0 Storm Salt.
   purchase(stillroom.clotting_salve) → Invalid parameter: Not enough materials. Held: 0 Bog Iron, 0 Storm Salt.
   fit(Pilgrim's Edge, Merciful Grip) → OK: Saved Held: 0 Bog Iron, 0 Storm Salt.
   refund(forge.first_fitting) → OK: Refunded 2 Bog Iron (fitting fitting.merciful_grip cleared) Held: 2 Bog Iron, 0 Storm Salt.
   purchase(forge.first_fitting) again → OK: Spent 2 Bog Iron Held: 0 Bog Iron, 0 Storm Salt.
   fit(Pilgrim's Edge, Merciful Grip) again → OK: Saved Held: 0 Bog Iron, 0 Storm Salt.
   prepare_potion(2, Focus Tincture) → OK: Saved Held: 0 Bog Iron, 0 Storm Salt.
   Bench closed (station: ''); refund now → Unavailable
4. Reloaded from disk. Recipes: [forge.first_fitting, stillroom.focus_tincture]. Fittings: { &"pilgrims_edge": &"fitting.merciful_grip" }. Potions: [&"mending_draught", &"focus_tincture"].
5. Next entry reedway_patrol#2 captures fittings ["fitting.merciful_grip"] and potions ["mending_draught", "focus_tincture"].
   The Hollow's traits: Pilgrim's Patience (Pilgrim's Edge), Merciful Grip (Pilgrim's Edge fitting), Steadfast (Pilgrim's Coat), Litany (Resonance: Litany), Bell Crow (Bell Crow)
   Potion slots: Mending Draught ×2 (authored 2), Focus Tincture ×1 (authored 1)
6. The Hollow Parried successfully: Pilgrim's Edge fitting fired, restoring 8 HP.
   Focus Tincture used: Focus 0 → 4; charges left 0.
7. Reset journey. Recipes: [forge.first_fitting, stillroom.focus_tincture]. Fittings: { &"pilgrims_edge": &"fitting.merciful_grip" }. Held: 0 Bog Iron, 0 Storm Salt.
Demo finished.
```

## 9. API and fixture guide for Codex

**Readouts.** From the world host use `host.session`; in tests use
`WorldKit.session()` + `enter_station(&"preparation_bench")`.

`session.crafting() -> CraftingReadout` (plain-data copies) holds:
- **Availability:** `available()`, `reason_text`.
- **`materials`:** held approved materials.
- **`recipes`:** `RecipeReadout`, Forge first.
  - Purchase facts: `costs[{id, name, icon_path, count, held, enough}]`, `can_purchase` /
    `purchase_reason_text`.
  - Refund facts: `refund[{… total}]`, `can_refund` / `refund_reason_text`.
  - Mastery facts: `mastery_required` / `mastery_current` / `mastery_weapons` / `mastery_met`.
  - Recipe text: `base_name`, `reagents`, `catalyst` ("" = none).
  - Results: kit `fittings[{id, name, description, source, trait{…}}]`, or `potion_*`.
- **`fittings`:** `FittingReadout` for Pilgrim's Edge.
  - State: `capacity`, `capacity_reason_text`, `installed_id/name`, `active`, `weapon_equipped`,
    `can_remove`, `base_traits`.
  - Choices: `options[{… installed, selectable, reason_text, actions}]`.
- **`potion_slots`:** two `PotionSlotReadout`s: `potion_id/name` and
  `options[{id, name, description, charges, source, recipe_id, unlocked, selected, selectable, reason_text}]`.
- **Action counts:** `protagonist_actions` / `companion_actions`.

Disable choices whose `selectable` / `can_*` is false. Do not compute affordability, mastery or
duplicates in widgets.

**Invoking commands.**
- Call `session.purchase(id)`, `refund(id)`, `fit(EDGE, id)`, `remove_fitting(EDGE)` and
  `prepare_potion(slot, id)` through the host's
  `_commit(write, then, rejected)`, as `_prepare` does.
  - Rejections return `ERR_INVALID_PARAMETER` / `ERR_ALREADY_EXISTS` / `ERR_UNAVAILABLE`.
  - To keep the station open on a rejection, pass a `rejected` callback that re-presents
    `session.crafting()` with `session.last_crafting.text()`.
  - Failures get the existing Retry card; Retry repeats the exact command.
- **Receipts.** `session.last_crafting.spent` / `.refunded` (and `.cleared_fitting`) after OK, or
  listen to `EventBus.crafting_completed`. Use them for "Spent 2 Bog Iron" or "Refunded 2 Bog Iron".
- **Equipment rejection.** `last_preparation` can now carry `DUPLICATE_TRAIT`, with text
  `WorldCopy.PREP_DUPLICATE_TRAIT`.
- **Copy.** All `CRAFT_*` lines are engineering placeholders; restyle freely.

**Fixtures.**
- `tests/world/test_world_crafting.gd`:
  - `_fund(iron, salt, mastery)` seeds a live save;
  - the over-limit test injects a synthetic two-action charm through `session.registry`;
  - `kit.writer.fail = true` injects a failed write.
- Demo: `python tools/qa_godot.py --headless --script res://tools/demo_v05b.gd`.

**Fixture-only today:** every V0.5B command and readout. **Connected:** battle capture, character
Skills, the inventory note.

## 10. Known limitations

- **No station UI.** Nothing is purchasable in play until Codex's screens land.
- **Downgrade.** An older build that rewrites a V0.5B save drops `crafting` (it does not know the
  key). The unlocks and fitting are then lost, with no refund. Downgrading builds is not supported.
- **Grandfathered potions.** A legacy prepared Clotting Salve or Focus Tincture unlocks its recipe
  for free. No production V0.4/V0.5A path prepared those potions; earlier dev tooling could have.
- **One introductory capacity.** One kit, one weapon, one fitting. No further tiers, sockets or
  prices are active (by specification).
- **Readout cost.** `crafting()` re-derives every option. That is cheap at this size, but rebuild
  the readout per refresh, not per frame.

## 11. For the Director

1. **Two of the same potion.** `prepare_potion` rejects a potion already in the other slot
   (`DUPLICATE_POTION`). The specification is silent. No shipped loadout doubles a potion, and
   doubling would undercut the choice. Rule if you prefer otherwise; it is one check.
2. **Duplicate-trait scope.** The check is judged on the resulting active loadout (an inactive
   fitting on an unequipped weapon does not count). The alternative would also block fitting Echo
   while holding the relic on another weapon. The chosen rule is the literal "simultaneous
   duplication".
3. **Inventory copy.** The A line "Materials have no use in this build" became false. The engineering
   placeholder is "Spend materials at the Forge and Stillroom, at the preparation bench in
   Gloamstead." Station names, reason lines and receipt wording are all placeholders.
4. **Observation for play, not a balance change.** Merciful Grip's ×1.5 Perfect window also feeds
   Pilgrim's Patience (Perfect hits turn 20% of Stagger into Focus). That is a plausible "comfort"
   synergy beyond the parry heal. Worth watching in Adrian's test. No number changed.
5. **Reset copy.** Reset journey keeps recipes and fittings, like salvage. The confirmation could
   name them; this is a copy decision.

## 12. For Adrian to check by hand (after Codex's screens)

- **Purchases and refund.**
  - A fresh save with only the guard win buys kit + tincture; the salve waits for the patrol.
  - Fit Merciful Grip and parry in the next fight: HP rises by 8.
  - Refund the kit: Bog Iron returns to 2 and the fitting is gone.
- **Relic conflict.** Owning the Hollow Reliquary (not obtainable in normal play yet) would show the
  duplicate-trait rejection.
- **Persistence.** Reset journey and reload keep everything.

Still open from earlier passes: the human playtest, controller and listening gates.

## 13. Future extension points

- **More fittings.** Add a `ModificationDefinition` and list it in a kit (data only).
- **More kits.** Add a `RecipeDefinition` per weapon; the catalog allows one kit per weapon.
- **Slot unlocks (6 → 8).** Would replace `PartyLoadout.MAX_ACTIONS` with a per-unit limit inside
  `PreparationRules.fits`; fittings already pass through it.
- **Catalysts.** Would be another `MaterialCost` role. A future bottle-count model would need a new
  saved count and an attrition decision (not V0.5).
