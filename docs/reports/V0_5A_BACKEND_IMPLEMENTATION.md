# V0.5A — Salvage and Preparation backend

Claude · 9 October 2026 · uncommitted `dev` after `35c8763` · application 0.3.0 / save version 1
**Not committed or pushed. No version bump, no save-version bump, no combat-rule or balance change,
no area regeneration and no UI redesign.** This answers [the V0.5A brief](../briefs/V0_5A_BACKEND_HANDOFF.md)
within [the roadmap](../design/V05_BACKEND_ROADMAP.md)'s stage 1 and stops there.

Existing world accomplishments now grant deterministic, persistent rewards exactly once, inside
the same save write as the accomplishment. An owned item can be equipped through validated,
station-only backend commands, and it reaches the next immutable encounter snapshot. Typed reward,
inventory and preparation readouts are ready for Codex to present. **This is backend work, not an
accepted gameplay loop:** no screen yet lets a player see materials or equip the charm (§1).

## 0. Return package

| Brief item | Status |
|---|---|
| 1. `V0_4_FIFTH_PLAYTEST_ENGINEERING_REVIEW.md` | Already written in the previous session and committed in `35c8763`. Not modified. Its headless result reproduced exactly before any V0.5A change: **328 passed, 0 failed, 4,482 assertions**, with the same expected diagnostics. |
| 2. This report | Behavior, files and contracts, reward quantities, save and reset compatibility, lifecycle integration, verification and limitations. |
| 3. API/fixture guide for Codex | §8. |
| 4. `DATA_CONTRACTS.md`, testing and return-queue notes | Updated: save format, field reference, a new "V0.5A salvage and preparation" section, `TESTING.md` V0.5A section, and the top of `CLAUDE_RETURN_QUEUE.md`. The GDD is untouched, and no human gate is marked passed. |

## 1. What is connected for a player, and what is not

| Path | State |
|---|---|
| First committed patrol or guard victory → salvage; ringing the bell → Storm Salt Charm | **Connected** (production `WorldHost` → `WorldSession`). Each victory card and the rung bell's dialogue shows one provisional plain line, e.g. "Received: 2 Bog Iron, 1 Storm Salt". |
| Older save → catch-up rewards and loadout repair at world entry | **Connected** (`WorldHost._ready`), using the existing save-failure card (Retry save / Return to title). |
| Bench → preparation station context | **Connected**. Opening the bench opens the context; closing it, or any return to exploration, ends it. The bench's weapon buttons now go through the ownership-checked command and list every owned weapon. |
| See materials or inventory; equip or remove the charm, garb or relic | **Not connected.** Only the API (`WorldSession.preparation()`, `inventory()`, `equip()`, `unequip()`) and the tests and demo fixture use it. The current bench shows weapons only. |
| Salvage preview on the encounter card | Data only (`EncounterCardReadout.rewards`); not rendered and not in `plain_text()`. |

So a player earns the charm in today's build but cannot equip it until Codex adds a station
screen. Adrian's human test ("does the new option suggest a useful next outing?") has not started.

## 2. Reward table (shipped data, provisional quantities)

| Source | Claim id | Reward | Data |
|---|---|---|---|
| First committed `reedway_patrol` victory | `first_footsteps.patrol` | 2 Bog Iron (`bog_iron`) | `data/rewards/first_footsteps_patrol.tres` |
| First committed `bell_guard` victory | `first_footsteps.guard` | 2 Bog Iron + 1 Storm Salt (`storm_salt`) | `data/rewards/first_footsteps_guard.tres` |
| Ringing the wayside bell (`WORLD_FLAG wayside_bell_restored`) | `first_footsteps.restoration` | the existing `storm_salt_charm` (Charm, Grounding trait unchanged) | `data/rewards/first_footsteps_restoration.tres` |

One save can hold at most 4 Bog Iron, 1 Storm Salt and the charm. The public labels ("Patrol
salvage", "Bell approach salvage", "Wayside bell") and both material descriptions are provisional
copy. The materials are site salvage: no drop table, no random roll, no new enemy behavior, no
choice, purchase or crafting. Claiming stays separate from discovery: standing at the bell,
examining it or winning the guard fight does not grant the restoration reward.

## 3. Architecture

```
data/materials/*.tres ─┐                         ┌─ RewardRules (pure): rewards_for, accomplished,
data/rewards/*.tres ───┴─ DefinitionRegistry ────┤    catch_up, grant, previews, validate_catalog
                          .materials .rewards    └─ PreparationRules (pure): availability, check,
                                                      apply, owned_items, action_counts/fits,
WorldHost (lifecycle) ── WorldSession (transactions)   repair_loadout, readout, inventory
  _reconcile at entry      commit(): copy → change → write → adopt
  bench ↔ station          commit_victory / restore_bell / open_latch  (+ reward grants)
  receipt lines            reconcile · enter/leave_station · equip / unequip / choose_weapon
                           last_receipts · last_repairs · last_preparation
                               │ after a successful write only
                               └─ EventBus.rewards_granted(RewardReadout)
ProgressState: reward_claims (save `rewards.claims`), materials, owned_equipment, type-safe from_dict
UnitFactory.protagonist_actions / companion_actions: one action list for battle and preparation
PartyLoadout.MAX_ACTIONS = 8  (ActionMenu.CAPACITY now uses it)
```

- **Definitions** (`src/data/items/material_definition.gd`, `src/data/progression/reward_definition.gd`,
  `reward_item.gd`) are typed Resources indexed by `DefinitionRegistry`. `RewardRules.validate_catalog`
  joins its validation: duplicate claim ids, the claim id format, empty or null items, kinds, counts
  (materials 1–99, equipment exactly 1), registered references (not copies), sources (an encounter
  landmark or a world flag), and each material's authored total ≤ 999.
- **Rules are pure.** Both rule classes take the progress and registry they act on. Neither names
  an autoload or a UI class. The action ceiling comes from `PartyLoadout.MAX_ACTIONS` and the same
  `UnitFactory` list the engine uses, never from `ActionMenu`.
- **One transaction per accomplishment.** A reward is applied to the `commit()` candidate in the
  same mutator as the clear or flag. No grant is ever a second write.
- **No new manager.** `WorldSession` remains the only owner of world writes. I added no inventory
  or reward service.

## 4. Transactions, receipts and compatibility

- **Exactly once.** The claim id decides eligibility, so the encounter token alone is not enough.
  A duplicate victory token is still a no-op (`ERR_ALREADY_EXISTS`, no receipt). A failed write
  changes nothing (live progress, claims, inventory, world and loadout) and emits nothing. Retry
  grants once. Receipts (`last_receipts`, `EventBus.rewards_granted`) exist only after adoption.
- **Reset journey** keeps `rewards.claims` and the inventory, because both live outside `world`.
  Clearing a site or ringing the bell again after a reset commits normally (research, mastery,
  statistics) but grants no salvage. New Game starts with no claims.
- **No salvage from the other paths:** defeat, Leave battle, an interrupted entry (`open()` recovery
  is unchanged), Practice (`record_progress = false`; Practice may still use unowned gear) and the
  recording Lab (`GameState.record_battle` keeps its research/mastery behavior and grants nothing).
- **Older save-version-1 slots.** A missing `rewards` section means nothing is claimed yet. At
  world entry, `WorldSession.reconcile()` runs one atomic commit. It grants the rewards the journey
  still proves: a cleared site or a set flag without its claim. Discoveries, statistics and pending
  entries prove nothing, and an accomplishment erased by an earlier Reset journey is not inferred.
  The same commit repairs the loadout (below). With nothing to do it writes nothing, so a second
  call is a no-op. It never runs inside a deserializer.
- **Loadout repair** (also in `reconcile`):

| Saved loadout | Result |
|---|---|
| Approved gear in its own slot but not listed as owned | Kept equipped; added to owned |
| Unknown or wrong-slot armor id | Slot emptied |
| Unknown or wrong-slot weapon id | The starter loadout's weapon (if owned), else the first owned weapon |
| Unknown or wrong-slot id | Never added to owned |

  `last_repairs` lists the repairs written.
- **Malformed data.** `ProgressState.from_dict()` type-checks the `loadout`, `inventory` and
  `rewards` sections:
  - Claims and equipment keep only strings (equipment de-duplicated, claims sorted).
  - Material counts must be whole numbers ≥ 1; values above 999 are capped. Zero, negative,
    fractional, boolean, NaN and non-numeric counts are dropped.
  - A wrong-typed section or slot falls back to its default. A wrong-typed equipment or potion list
    keeps the starter list.
  - Well-formed unknown ids are preserved but never shown, equipped or granted. An unknown claim
    blocks only a reward that does not exist.
- **Save format:** additive `"rewards": {"claims": [...]}`; `inventory.materials` and
  `inventory.equipment` now carry real data. Save version stays 1 and no migration step was
  needed. See the downgrade note in §9.

## 5. Preparation

`equip(slot, item_id)`, `unequip(slot)` and `choose_weapon(id)` (the bench's V0.4 call, now
`equip(WEAPON, id)`):

| Reason | Error | When |
|---|---|---|
| `NO_STATION` | `ERR_UNAVAILABLE` | No bench interaction is open. A saved anchor or a hidden button is not the bench. |
| `ENCOUNTER_PENDING` | `ERR_UNAVAILABLE` | An entry is pending or in battle. `enter_station` is refused too. |
| `UNKNOWN_ITEM`, `NOT_OWNED`, `WRONG_SLOT` | `ERR_INVALID_PARAMETER` | Not approved content, not owned, or the wrong slot. |
| `REQUIRED_SLOT` | `ERR_INVALID_PARAMETER` | `unequip(WEAPON)`; garb, charm and relic can be emptied. |
| `ACTION_LIMIT` | `ERR_INVALID_PARAMETER` | The whole new loadout would exceed 8 actions for a party member. Nothing is truncated, and the stance and Inspect are never dropped. |
| `WRITE_FAILED` | writer's error | Valid, but the write failed. The live state is unchanged and the station stays open for Retry. |

A successful change writes once, applies to the next `EncounterEntry`, and charts the bench (as V0.4
did). Re-choosing the equipped item is accepted (`changed = false`). A captured entry and its retry
never change. Every shipped weapon and armor combination fits (the Hollow has at most 7 actions;
no shipped armor grants an action). No action was added for the eighth slot. Practice, the Lab and
`PartyLoadout.from_ids` stay ownership-free.

The station context lives only in the session and is never saved. The bench opens it, and it
ends on bench Leave, on any host return to exploration, battle or transition, and in
`begin_entry()` and `reset_journey()`. A save-failure card over the bench keeps it, so Retry works.

## 6. Files

**Created:**
- `src/data/items/material_definition.gd`
- `src/data/progression/reward_definition.gd`, `reward_item.gd`
- `src/progression/reward_rules.gd`, `preparation_rules.gd`
- `src/progression/readouts/`: `reward_readout.gd`, `inventory_readout.gd`, `preparation_readout.gd`,
  `equipment_slot_readout.gd`, `preparation_result.gd`
- Data: `data/materials/bog_iron.tres`, `storm_salt.tres`; `data/rewards/first_footsteps_{patrol,guard,restoration}.tres`
- Tests: `tests/unit/test_reward_rules.gd`, `tests/world/test_world_rewards.gd`,
  `test_world_preparation.gd`, `test_world_salvage_host.gd`
- Tools: `tools/demo_v05a.gd`, `demo_v05a_runner.gd`
- Godot `.uid` files for each new script. `tests/unit/test_app_icon.gd.uid` also appeared on
  import; it was missing from `35c8763`.

**Modified:**
- `src/progression/progress_state.gd`: `reward_claims`, `has_claim`/`add_claim`/`material_count`/`loadout_ids`, type-safe parsing.
- `src/core/definition_registry.gd`: `materials` and `rewards` collections, catalog validation.
- `src/world/world_session.gd`: grants inside victory, bell and latch commits; `reconcile`; station context; preparation commands; readout accessors.
- `src/world/world_rules.gd`: `bench_weapons` lists every owned weapon; the encounter card carries reward previews; `STARTER_LOADOUTS` removed.
- `src/world/world_host.gd`: lifecycle adapters only — `_reconcile` at entry, the bench opens and ends the station context, `_set_mode` ends it, receipt lines on the victory card and rung-bell dialogue, `open_dialogue(landmark, note = "")`.
- `src/world/world_copy.gd`: provisional receipt, eligibility and rejection copy.
- `src/world/readouts/encounter_card_readout.gd`: `rewards`.
- `src/battle/rules/unit_factory.gd`: `protagonist_actions` and `companion_actions`, shared with preparation. Battle output is identical (§7).
- `src/data/encounters/party_loadout.gd`: `MAX_ACTIONS = 8`.
- `src/ui/battle/action_menu.gd`: `CAPACITY := PartyLoadout.MAX_ACTIONS`. The value is unchanged; it was a one-line UI edit so there is a single source of truth.
- `src/autoload/event_bus.gd`: `rewards_granted`.
- `src/core/enum_text.gd`: `equip_slot`, `resonance`.
- Tests: `test_world_session.gd` and `test_world_reset.gd` now open the station before `choose_weapon`, which is the new contract; the bench test also covers a non-starter owned weapon. `test_action_capacity.gd` uses the rule constant and checks the shared list against battle.
- Docs: `DATA_CONTRACTS.md`, `TESTING.md`, `briefs/CLAUDE_RETURN_QUEUE.md`.

**Public API changes:**
- `WorldRules.STARTER_LOADOUTS` was removed.
- `choose_weapon` now needs the station context (`ERR_UNAVAILABLE` without it).
- `WorldHost.open_dialogue` gained an optional `note`.
- Everything else is additive.

## 7. Verification (exact runs, isolated `.godot/qa/*` homes, Godot 4.7.2)

| Check | Result |
|---|---|
| Baseline before any change (full suite, headless) | 328 passed, 0 failed, 4,482 assertions (109.5 s) |
| Full suite, headless, final tree | **358 passed, 0 failed, 5,091 assertions** (110.3 s): 328 + 30 new tests. Expected diagnostics only: 4 invalid-save errors, 1 "rejected action (Needs 5 Focus)" warning, 5 world-session recovery warnings; nothing new. |
| Full suite, hidden native Compatibility window, final tree | **358 passed, 0 failed, 5,115 assertions** (107.9 s), same expected diagnostics. Wall-clock widget fixtures loop over what is on screen, so assertion totals differ slightly between runs. |
| New suites | `test_reward_rules` 5/0 · `test_world_rewards` 11/0 · `test_world_preparation` 9/0 · `test_world_salvage_host` 4/0 (plus updated `test_world_session` 15/0, `test_world_reset` 7/0, `test_action_capacity` 3/0) |
| Scripts (`check_scripts.gd`) | 266 checked, 0 failed (250 + 16 new) |
| Content validation | Part of the suite (`test_content`, 8/0): new data validates |
| Determinism probe (scratch): 8 encounters × 5 loadouts (the shipped four + starter sword with the charm) × 3 seeds, every event field + input log | 120 battles, total `0052c5b6…d95d89`, identical per battle to a fresh `35c8763` clone |
| Simulation smoke (`--encounter=all --exec=MIXED --runs=10 --seed=1`) | Identical to the `35c8763` clone except elapsed time; no errors |
| Mutation checks (scratch copy, never the repo) | **25 of 25 caught** (list below) |
| Demo fixture (`tools/demo_v05a.gd`, fresh QA home) | Ran end to end, exit 0, no exit-time leak report (output below) |
| Material polish (`validate_material_polish.gd`) | 264 checks, 0 failures |
| Python (`unittest discover`) | 10 tests OK |
| Whitespace | `git diff --check` clean; new files are LF with a final newline and no trailing whitespace |

The 25 mutations (each reverts one behavior; every one fails at least one of the new tests):
1. A victory grant applied before the write.
2. Grants ignoring claims.
3. A discovered site counted as an accomplishment.
4. Reset clearing claims.
5. No station check.
6. No ownership check.
7. No action ceiling.
8. Receipts emitted on a failed write.
9. Untrusted material counts.
10. Unknown armor grandfathered.
11. The host keeping the station open.
12. The host not reconciling.
13. Examining the bell granting the charm.
14. A retry rebuilding the live loadout.
15. `begin_entry` keeping the station.
16. No saturation.
17. Duplicated equipment.
18. No catalog total check.
19. No catalog source check.
20. The action count missing granted actions.
21. Reconciliation writing when idle.
22. A failed equip changing the live loadout.
23. Claims not saved.
24. The bell granting nothing.
25. The bench limited to starters again.

Demo output, verbatim (public results only):

```
1. New game in throwaway slot 7. Claims: []. Materials: none.
   Guard attempt 1: Victory in 4 rounds.
2. Guard victory committed. Receipts: Bell approach salvage → 2 Bog Iron, 1 Storm Salt
   Repeating the same result: no-op, 0 receipts.
3. Wayside bell restored. Receipts: Wayside bell → Storm Salt Charm
4. Reloaded from disk. Claims: [first_footsteps.guard, first_footsteps.restoration].
   Inventory:
      Bog Iron ×2
      Storm Salt ×1
      Pilgrim's Edge · Weapon (equipped)
      Mire Maul · Weapon
      Reedbow · Weapon
      Pilgrim's Coat · Garb (equipped)
      Storm Salt Charm · Charm
5. Away from the bench: equip → Unavailable (Change equipment at the preparation bench.)
   At the bench (station: preparation_bench). Charm slot before: equipped ''; owned choices: Storm Salt Charm
   equip(CHARM, storm_salt_charm) → OK. Charm slot now: equipped 'Storm Salt Charm'; owned choices: Storm Salt Charm [equipped]
   Bench closed (station: ''); unequip now → Unavailable
6. Reloaded; next entry reedway_patrol#2 captures charm 'storm_salt_charm'.
   The Hollow's traits: Pilgrim's Patience (Pilgrim's Edge), Steadfast (Pilgrim's Coat), Grounding (Storm Salt Charm), Litany (Resonance: Litany), Bell Crow (Bell Crow)
7. Fen Water Flask (Wet) then Spark (Shock) at the first enemy: Grounding fired 1 time(s), 16.8 Stagger; the target Broke.

Demo finished.
```

The Wet → Shock check uses the real engine and the authored trait, and changes no balance. In the
captured Fen Patrol battle, the flask's Wet alone never triggers Grounding. Spark's Shock on the
Wet target triggers it once, for its authored 12 Stagger raised by Shock to 16.8. That exactly
accounts for the Stagger difference from the same captured battle without the charm.

## 8. API and fixture guide for Codex

**Getting readouts.** From the world host use `host.session`; in tests use `WorldKit.session()`.
- `session.preparation() -> PreparationReadout`: `available()`, `reason_text`, action counts and
  `slots` (one `EquipmentSlotReadout` per slot; options carry `selectable`, `reason_text`, `equipped`,
  `traits`, `grants`, `actions`).
- `session.inventory() -> InventoryReadout`: materials with a positive count, plus owned equipment.
- `session.reward_previews(RewardDefinition.Source.SITE_VICTORY, site_id)`, or
  `WorldRules.encounter_card(site, progress).rewards`, for a site's salvage: `status_text()`,
  `summary()`, `items`.
- All readouts are plain-data copies. `icon_path` is a resource path (empty today; neither the
  materials nor the armor have icons yet).

**Invoking preparation.**
- `open_bench(landmark)` already calls `session.enter_station(landmark.id)`. Keep that call if you
  rebuild the bench, and keep `session.leave_station()` when it closes; `_set_mode` also ends the
  context.
- Call commands through the host's `_commit(func() -> Error: return session.equip(slot, id), then)`,
  as the weapon buttons do. A write failure then shows the save-failure card and Retry repeats the
  command.
- A rejection returns `ERR_INVALID_PARAMETER` or `ERR_UNAVAILABLE`, which `_commit` currently
  treats as close-the-modal. To keep the station open on a rejection, read
  `session.last_preparation.text()` instead.
- Disabling options whose `selectable` is false avoids rejections in normal play.

**Presenting rewards.**
- Listen to `EventBus.rewards_granted(receipt)`, or read `session.last_receipts` right after a
  successful `commit_victory`, `restore_bell` or `reconcile`. Both appear only after the save
  succeeded.
- `WorldHost._received_lines()` produces today's provisional lines; replace them freely.
- Catch-up at world entry produces receipts but no visible notice yet.

**Retrying failures.** Every session command returns `Error` and leaves state untouched on failure,
so calling it again is the retry. World entry uses `WorldHost._reconcile()` with the existing card.

**Testing against isolated data.**
- Use `WorldKit.isolate()`, its `MemoryWriter` (`fail = true` injects a failed write) and
  `kit.session()`, then `session.enter_station(&"preparation_bench")`.
- To exercise the action-limit rejection, inject a registry with a synthetic charm
  (`session.registry = …`), as `test_an_over_limit_loadout_is_rejected_whole` does.
- Run everything through `python tools/qa_godot.py …`. The demo is
  `python tools/qa_godot.py --headless --script res://tools/demo_v05a.gd`.

**Fixture-only vs connected.**
- Fixture-only today (no UI caller): `equip`/`unequip` for garb, charm and relic, `preparation()`,
  `inventory()`, `reward_previews()`, `EncounterCardReadout.rewards`, `rewards_granted` listeners.
- Connected: reward grants, reconciliation, the station context, `choose_weapon`, and the receipt
  lines.

## 9. Known limitations

- **No equip or inventory UI.** The charm is earned but not equippable in play, and no screen shows
  materials (Codex).
- **Downgrade.** An older build that rewrites a V0.5A save drops the unknown `rewards` key. Reopening
  that save here would re-grant the catch-up for accomplishments still in its journey, which can
  duplicate materials. Downgrading builds is not supported.
- **Save-editing.** An edited claim list can block a reward (claims are trusted once well-formed),
  and valid equipped gear in an edited loadout is grandfathered as owned. No production path
  creates either.
- **Partial hardening.** `ProgressState.from_dict` now hardens only the sections V0.5A reads
  (loadout, inventory, rewards). Other placeholder sections (companions, quests, regions, home
  upgrades) still trust their types, as before.
- **Equip writes on a no-op.** Re-choosing the equipped item still writes (V0.4 behavior; it also
  charts the bench).
- **Latch rewards.** `open_latch` grants `WORLD_FLAG return_latch_open` rewards, though none are
  authored. A latch reward added later works without code.
- **Dead code.** `GameState.store_loadout` still has no callers (pre-existing; untouched).

## 10. For the Director

1. **Reset journey copy.** `WorldCopy.RESET_BODY` says research, mastery and equipment are kept.
   Salvage and reward claims are kept too, and a repeated site or bell grants nothing again. The
   card should probably say so; this is a copy decision.
2. **Provisional copy.** The material descriptions, reward labels and the `WorldCopy`
   receipt/eligibility/rejection lines are engineering placeholders. Replace any of them freely.
3. **Salvage on the encounter card.** Whether to show "first clear" salvage before a fight is
   presentation; the data is ready.
4. **Observation for play, not a balance change.** In the demo's Fen Patrol battle, Fen Water
   Flask then Spark with the charm equipped added 16.8 Stagger and Broke the first enemy (the
   Bogshell) on the Hollow's second turn. That is a strong, readable two-turn setup from the
   existing trait and potion. Worth watching in Adrian's playtest.
5. **V0.5B prerequisites (from the roadmap):** recipe prices, mastery thresholds, modification
   choices and refunds need a small specification before spending exists. Materials currently have
   no use.

## 11. For Adrian to check by hand

- On a V0.4 save that already rang the bell, Continue journey: nothing should interrupt the walk,
  and the save now owns the Storm Salt Charm and the guard salvage. There is no visible notice yet.
- A fresh guard victory shows "Received: 2 Bog Iron, 1 Storm Salt" once; ringing the bell shows
  "Received: Storm Salt Charm"; after Reset journey, neither appears again.
- The bench still lists the three starter weapons in the same order.

Still open from earlier passes: the human playtest, controller and listening gates.

## 12. Future extension points

- `RewardDefinition.Source` is an append-only enum; a new source kind needs one branch in
  `RewardRules.accomplished` and a grant call in the command that commits it.
- Materials are ready to be spent: an atomic spend belongs in a `WorldSession` commit, like
  equipping.
- Slot unlocks (6 → 7 → 8) would replace `PartyLoadout.MAX_ACTIONS` with a per-unit limit inside
  `PreparationRules.fits`.
- Weapon modifications would extend `EncounterEntry`'s captured loadout ids and `PartyLoadout.from_ids`.
