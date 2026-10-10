# V0.5 playtest revision — backend contract and implementation

10 October 2026 · Claude (Backend, Systems and Architecture Lead) · shared uncommitted `dev` ·
application **0.5.0** / save version **1** (both unchanged).

**Status: IMPLEMENTED AND VERIFIED (engineering).** Every contract in §2 has landed, is wired through
the host and Codex's views, and is covered by tests (§7). Full headless and Compatibility/Dummy
suites pass with only the documented diagnostics, determinism and mutation checks pass (§9). Human
gates stay open (§10). Nothing is committed, pushed, version-bumped or regenerated. **The Godot
execution window is free** (§6).

After Codex's checkpoint Adrian let Claude finish remaining frontend work in Codex's absence. That
work (§6, §8) is limited to making Codex's delivered views and tests agree with the landed contracts,
removing overlap-era code and fixing regressions; no screen was redesigned.

**Follow-up (§11).** Adrian's eight review points before the V0.5 push (session logs, ring
centring in the Forge and on the map, a gate post drawn over Hollow, view shortcuts, the Stillroom
popup's card, Interact at a threat, sprint with stamina) are implemented and verified: 543 tests
pass headless and rendered, battle outcomes are unchanged, 14/14 follow-up mutations are caught.

Answers [the backend prompt](../briefs/V0_5_PLAYTEST_BACKEND_PROMPT.md) and
[the revision plan](V0_5_PLAYTEST_REVISION_PLAN.md). Earlier contracts stay valid unless this file
says otherwise: [V0.5 UI backend](V0_5_UI_BACKEND_IMPLEMENTATION.md), [data contracts](../DATA_CONTRACTS.md).

**Contract change rule.** Once Codex consumes a name below I do not change it silently: a change is
recorded in §8 with the consumer edit it needs.

## 0. Decisions for Adrian and the Director (please read first)

Each is implemented as the stated default and is cheap to change. None is a balance claim.

1. **Only a saved victory consumes supplies.** Uses are counted by the battle engine and deducted
   from stock inside the victory's own save, exactly once. Defeat → Retry, defeat → Return to
   Gloamstead, Leave battle and quitting mid-battle all discard the attempt and its uses, as they
   already discard everything else about it ("no fee", "no award"). The alternative (charge the
   last lost attempt on Return to Gloamstead) is one line; it would make Leave free and Home
   costly, so I did not pick it.
2. **Starter supplies are finite: 4 Mending Draught and 4 Fen Water Flask.** Each can be brewed
   again for 1 Bog Iron → 2 doses. The whole route currently grants 5 Bog Iron and 1 Storm Salt, so
   supplies are scarce by construction. No farm, merchant or refill is added.
3. **Fittings cost 2 Bog Iron each** (the old kit price, per fitting) behind the existing mastery
   gate. Owning both now costs 4, where the kit gave both for 2: an economy change, not a tuned one.
4. **Older fitting kits are grandfathered.** A save that owns the kit owns both fittings, keeps its
   installed fitting, and keeps its right to reclaim the kit for 2 Bog Iron. Nothing is refunded
   or cleared on load. Kits can no longer be bought.
5. **Party Break numbers are provisional** (§5): 40 Break each; an unreacted hit removes 8, a
   Brace 4, an Evade 0; a successful Parry removes 6 instead. Broken costs that unit's next
   activation, with no reaction and no cover while Broken. Party members do **not** take the
   enemies' ×1.5 Broken damage.
6. ~~Interact at a threat starts the countdown; it never launches at once.~~ **Superseded by Adrian
   (§11): Interact at a threat fights at once**; walking into reach still starts the countdown.
7. **New Journey's first write is an automatic save** (quiet icon); only Save, Save and return to
   title and Save and Quit are manual.
8. **A supply position can be re-chosen but not emptied** (unchanged from the current build).
9. **Measured consequence of party Break (balance flag, not a claim).** The balance simulation
   (8 encounters × 3 starter loadouts × 4 execution profiles × 100 runs, seed 1, Adventurer) is
   unchanged for Good, Mixed and Perfect execution (100 % wins, same rounds). For **Miss**
   execution (never a successful reaction) the mean win rate falls from 81.2 % to 67.9 %; the
   largest drops are Briarfen gauntlet with the sword (91 → 44 %) or bow (57 → 18 %) and the
   Thornhound pack with the hammer (84 → 24 %) or bow (87 → 36 %). Party Break makes not reacting
   costly, as intended, but the 40/8 values may be too harsh for players still learning timing.
10. **Tooltip dismissal is scoped to floating cards.** Adrian's request (a card leaves with its
   source unless pinned) now applies to every floating tooltip card. Codex's implementation had
   also removed the fixed battle dock's 0.14 s gap tolerance and its field help and in-dock scrolling,
   which the plan says to preserve; I restored those for docked inspectors only (§8). Please confirm.
11. **The pre-Loadout Character pages and the pre-revision Forge/Stillroom branch are removed.**
   Both were unreachable (the host always supplies the Loadout and stock readouts) and their help
   text described the retired model ("Recipes unlock choices permanently… Potions refill between
   encounters"). Renders of Loadout, Forge and Stillroom are byte-identical to Codex's final
   reviewed captures (§9).

## 1. Architecture

- **One write path.** Every new command is copy → check → change → atomic write → adopt →
  publish, through `WorldSession.commit()`. A rejection, no-op or failed write changes and
  announces nothing. Results are typed (`*Result`), readouts are plain-data copies (`*Readout`).
- **Supplies are a ledger, not a refill.** Saved stock counts doses (`inventory.consumables`).
  An encounter entry captures an immutable *allowance* per prepared position
  (`min(per-encounter cap, held)`). The battle starts with exactly that allowance; Retry rebuilds
  from the same entry. The engine reports uses in `BattleResult.item_uses`; the victory commit
  settles them. The UI never decrements anything.
- **Break is one meter engine with a per-side policy.** `StaggerRules` owns the meter, Broken and
  recovery for any unit that has a meter. Enemy-only consequences (weak point, growing cap, Focus
  reward, ×1.5 damage, `STAGGER_BREAK` triggers) are read from an explicit policy, never from
  `enemy_def()` on a party member. Party Break damage enters through one function per resolved
  enemy action and target.
- **Journal and countdown are derived, small and pure.** `QuestRules` derives the bell journey's
  stage from world truth inside every commit; `EncounterCountdown` is a pure state machine the
  host ticks. Neither writes on its own.
- **Events after adoption only.** Order for one successful write: `game_saved` (legacy) →
  `save_completed` → the command's own event (`crafting_completed`, `preparation_completed`,
  `familiar_changed`, `rewards_granted`, `quest_changed`).

## 2. Contracts

Field lists are exhaustive for new types and additive for existing ones. `[…]` is an `Array`,
`{…}` a `Dictionary` with exactly those keys. Ids are `StringName`.

### 2.1 Extra mouse buttons (I01)

`InputBindings` (`src/core/input_bindings.gd`):

| Member | Meaning |
|---|---|
| `CAPTURE_MOUSE_BUTTONS: Array[int]` | `[3, 8, 9]`: middle, X1, X2. Left, right and the wheel are never captured. |
| `capture_code(event) -> String` | The binding code a capture accepts for this event, or `""`. Accepts a fresh key press (no echo), a joypad button press, or a press of a capturable mouse button. The left click that opened the capture, every release, motion and the wheel return `""`. |
| `is_capture_cancel(event) -> bool` | Escape pressed. Check it before `capture_code`. |
| `rebound(codes, code) -> PackedStringArray` | The existing rule, extracted: replaces the first binding of the same kind (`key`, `joy`, `mouse`), otherwise inserts it first. |
| `conflicts(action, code) -> Array[StringName]` | Other actions in the same context (world, or battle and menus) already using `code`. Informational: capture is still allowed, as today. |
| `code_label(code)` | `mouse:3` → "Middle Mouse", `mouse:8` → "Mouse X1", `mouse:9` → "Mouse X2" (also left, right and wheel names). |
| `label` / `prompt` / `labels` / `key_label` | On keyboard and mouse: the first key; a mouse button only when the action has no key. `labels()` lists keys, then mouse buttons. |

Mouse bindings persist through the existing `bindings` section (`"mouse:8"`). A mouse button bound
to Confirm, Back or a direction also drives focused menus: `Settings` forwards it to the matching
`ui_*` action for the focused control (mouse codes are not copied into `ui_*` themselves, so a
click never fires two controls). Defaults, timing and fresh-press logic are unchanged.

**Codex (`settings_screen.gd`):** in `_input` while capturing, call `is_capture_cancel`, then
`capture_code`; pass the code to `Settings.set_binding(action, InputBindings.rebound(codes, code))`.
Update the instruction line to mention mouse buttons.

### 2.2 Movement into walls (E01)

`WorldPlayer.moving` is the fact presentation reads. No API change; the fix and its regression are
recorded in §7.

### 2.3 Encounter countdown (E02)

`EncounterCountdown` (`src/world/encounter_countdown.gd`, pure):
`enum State { IDLE = 0, COUNTING = 1, FROZEN = 2, CANCELLED = 3, EXPIRED = 4 }`, `DURATION := 3.0`.

`EncounterCountdownReadout` (`src/world/readouts/encounter_countdown_readout.gd`):

| Field | Meaning |
|---|---|
| `state` | `EncounterCountdown.State`. |
| `active: bool` | `COUNTING` or `FROZEN`: a threat owns the countdown. |
| `frozen: bool` | Held by a modal, pause, focus loss or a busy transition; resumes without resetting. |
| `threat_id` | The encounter landmark id that owns it (`&""` when none). |
| `threat_label: String` | Public threat category ("Patrol", "Guard"). Never a creature name. |
| `remaining`, `duration: float` | Seconds. `fraction()` = remaining / duration. |

`WorldHost`:
- `signal encounter_countdown_changed(readout: EncounterCountdownReadout)` on every state change
  (start, freeze, resume, cancel, expiry). `encounter_countdown() -> EncounterCountdownReadout`
  is current every physics frame for a smooth ring.
- If the HUD defines `present_countdown(readout)`, the host calls it on each change and each frame
  while active.

Rules: entering an armed threat's radius starts it. Movement stays live. Leaving the radius
cancels and disarms the threat until the player is 24 px beyond the radius (the existing rearm
distance). The nearest armed threat wins (ties by id) and stays the owner until it resolves.
Interact inside the radius fights at once through the same `engage(site)` (changed by Adrian, §11;
originally it only started the countdown). Any non-exploration mode freezes it. A cleared
site, a portal or an area load cancels it. Expiry calls the existing `engage(site)` once: capture →
save → launch. A failed entry write shows the existing Retry card; Retry repeats the same entry;
nothing launches twice. The countdown itself writes and grants nothing. `open_encounter_card`
stays as an unused, tested API; the host no longer opens it.

### 2.4 Quest journal (E03)

`QuestRules` (`src/world/quest_rules.gd`): `BELL := &"first_footsteps.wayside_bell"`,
`enum BellStage { FIND = 0, RESTORE = 1, RETURN = 2, COMPLETE = 3 }`.

`QuestReadout`: `id`, `title: String`, `objective: String` (current step; the completion line when
completed), `stage: int`, `stage_count: int`, `completed: bool`,
`steps: [{stage: int, text: String, done: bool, current: bool}]`.

`QuestJournalReadout`: `active: Array[QuestReadout]`, `completed: Array[QuestReadout]`, `quest(id)`.

`QuestChange`: `kind` (`enum Kind { ACQUIRED = 0, ADVANCED = 1, COMPLETED = 2, RESET = 3 }`),
`quest_id`, `title`, `objective`, `previous_stage` (−1 when acquired), `stage`.

- `WorldSession.quests() -> QuestJournalReadout`; `last_quest_changes: Array[QuestChange]`.
- `EventBus.quest_changed(change: QuestChange)`: once per adopted change, after the save events.
- Stage is saved in the existing `quests` section (`{"first_footsteps.wayside_bell": 0…3}`) and
  re-derived inside every commit: guard cleared → `RESTORE`; bell rung → `RETURN`; arriving in
  Gloamstead with the bell restored → `COMPLETE` (kept afterwards).
- **No replay.** Loading, opening the world and old-save reconciliation set the stage silently.
  Only a journey created this session announces `ACQUIRED`, once, at its first world entry. Reset
  journey returns the quest to `FIND` in the same write and publishes one `RESET`.
- No reward, flag or content is added. Text is `WorldCopy.QUEST_BELL_TITLE`, the HUD objective
  lines and `QUEST_BELL_COMPLETE`. `WorldJournalView.make(journal)` lays out the journal.

### 2.5 Ingredients and bag (L03, L04, A01)

- `MaterialDefinition`: `listed: bool = true` (shown in the catalog), `sort_order: int = 0`.
- `ingredients: [{id, name, description, icon_path, count: int (0 or more), held: bool}]` on
  `InventoryReadout`, `CraftingReadout` and `LoadoutReadout`: every listed approved material,
  ordered by `sort_order` then id, zero counts included. Unknown saved ids never appear.
  `materials` (held only) stays for older callers.
- `InventoryReadout.EQUIPMENT_CELLS := 20`; `equipment_capacity` stays 10 or 15 from claimed
  rewards. Cells at or beyond the capacity are locked; `cells_locked_text` gives the reason.

### 2.6 Unified Loadout (L02, L06–L09)

`WorldSession.loadout() -> LoadoutReadout` (`src/progression/readouts/loadout_readout.gd`):

| Field | Meaning |
|---|---|
| `reason`, `reason_text` | `PreparationResult.Reason`; `ENCOUNTER_PENDING` when field commands are rejected. |
| `gear: Array[EquipmentSlotReadout]` | Weapon, garb, charm, relic, in that order. |
| `core: [action fact]` | The supplemental Core/stance group. |
| `familiar: FamiliarReadout` | §2.7. |
| `supplies: Array[PotionSlotReadout]` | `SUPPLY_POSITIONS` (4) entries; two usable. §2.8. |
| `positions: [{index, locked, reason, reason_text, action_id, source_id}]` | 8 entries; 6 usable. |
| `capacity`, `positions_total` | 6, 8. |
| `arranged`, `unarranged: Array[StringName]` | Battle order; granted but unplaced. |
| `passives: [{id, name, description, details, source_id, source_name, kind}]` | Active passives. `kind`: `&"gear"`, `&"fitting"`, `&"resonance"`, `&"familiar"`. |
| `mastery: [{id, name, icon_path, points}]` | Weapon mastery facts. Never selectable. |
| `ingredients` | §2.5. |
| `equipment_capacity`, `equipment_cells` | 10 or 15; 20. |

`EquipmentSlotReadout` gains `source_id` (`&"weapon"`, `&"garb"`, `&"charm"`, `&"relic"`),
`icon_path`, `strip_cells := 3` and `actions: [action fact]` (at most three). Each `options` entry
gains `icon_path` (already present) and `combat.kept`.

**Action fact:** `{id, name, description, details, category: String, category_id: int,
focus_cost: int, timing: String, source_id, origin: StringName, origin_name: String,
arranged: bool, position: int (−1 when unplaced), selectable: bool, reason: CombatResult.Reason,
reason_text}`. `origin`: `&"basic"`, `&"technique"`, `&"stance"`, `&"innate"`, `&"granted"`,
`&"inspect"`.

Source rules (truthful, never truncated or invented):
- **Weapon strip:** basic attack, then techniques (first three). Further techniques go to `core`.
- **Garb, charm, relic strips:** the item's `granted_actions` (first three; the rest to `core`).
  Current armor grants none, so these strips are empty.
- **Core group** (`source_id = &"core"`): the weapon's stance (`origin = &"stance"`,
  `origin_name` = the weapon), the Hollow's innate Spark and Kindle (`&"innate"`, "The Hollow"),
  Inspect (`&"inspect"`), then any overflow. It is not limited to three.
- Every granted action appears exactly once across the strips and `core`.

Commands are the existing ones: `equip`, `unequip`, `arrange_action`, `swap_actions`,
`move_action`. `PreparationResult` gains `actions_kept: [{id, name, position}]`,
`arrangement_before` and `arrangement_after: Array[StringName]`. Use these for highlights;
`summary()` remains only for the old card.

View: `WorldCharacterView.present(inventory, loadout)` builds the Loadout (`WorldLoadoutView`) and
Inventory tabs; the host passes adopted results to `present_preparation` / `present_combat`.

### 2.7 Familiar and passive (L08)

- `FamiliarDefinition`: `passives: Array[TraitDefinition]` (at most `MAX_PASSIVES := 3`). Empty
  means the legacy single choice `trait_def`. `passive_choices()`, `default_passive()`.
  Bell Crow and Cinder Pup each have one choice today; none is invented.
- Save: `loadout.familiar_passive` (trait id; absent or invalid = the familiar's default).
- `FamiliarReadout` (`src/progression/readouts/familiar_readout.gd`): `reason`, `reason_text`,
  `familiar_id`, `name`, `description`, `playstyle`, `portrait_path`, `passive_id`,
  `passive_cells := 3`, `choices: [{id, name, description, playstyle, portrait_path, selected,
  selectable, reason, reason_text}]` (owned familiars only), `passives: [{id, name, description,
  details, selected, selectable, reason, reason_text}]`.
- `FamiliarResult` (`.../familiar_result.gd`): `command` (`CHOOSE_FAMILIAR = 0`,
  `CHOOSE_PASSIVE = 1`), `reason` (`OK = 0`, `ENCOUNTER_PENDING = 1`, `UNKNOWN_FAMILIAR = 2`,
  `NOT_OWNED = 3`, `UNKNOWN_PASSIVE = 4`, `WRITE_FAILED = 5`), `error`, `reason_text`,
  `familiar_id`, `passive_id`, `previous_familiar_id`, `previous_passive_id`, `changed`.
- `WorldSession.choose_familiar(familiar_id)`, `choose_familiar_passive(passive_id)`,
  `last_familiar`, `familiar()`. Field commands, one atomic write each. Choosing a familiar sets
  its default passive in the same write. `EventBus.familiar_changed(result)` after adoption.
- The entry snapshot captures both ids; `PartyLoadout.familiar_passive` carries the chosen trait
  and `BattleState.familiar_trait` exposes it. **Codex:** `familiar_card.gd` should read
  `state.familiar_trait` instead of `familiar.trait_def` (identical today).
- A familiar still has no turn, target or HP.

### 2.8 Finite supplies (A04–A07, L02)

Data:
- `PotionDefinition`: `charges` is the **per-encounter cap for one position** (unchanged
  values); new `starter_stock: int = 0`, optional `icon: Texture2D`, `MAX_STOCK := 99`.
- `RecipeDefinition`: `yield_count: int = 1` (doses per brew, `POTION` only).
- New recipes `stillroom.mending_draught` and `stillroom.fen_water_flask`.

Readouts:
- `PotionSlotReadout` gains `locked`, `state` (`enum State { EMPTY = 0, PREPARED = 1,
  DEPLETED = 2, LOCKED = 3 }`), `reason`, `reason_text`, `icon_path`, `description`, `held`,
  `cap`, `usable` (`min(cap, held)`: what the next battle starts with), `inspection:
  {title, category, description, icon_path, facts: PackedStringArray, details: PackedStringArray}`
  and `choices` (owned stock or already prepared here; the popup list). `options` stays complete
  and each entry gains `held`, `cap`, `usable`, `icon_path`.
- `CraftingReadout` gains `supplies: Array[PotionSlotReadout]` (4, with locks),
  `stock: [{id, name, description, icon_path, held, cap, usable, prepared_slot (−1 = unprepared),
  recipe_id}]` (every potion held or prepared) and `SUPPLY_POSITIONS := 4`. `potion_slots` (the
  two usable) stays.
- `RecipeReadout` gains `yield_count`, `repeatable`, `retired`, `potion_icon_path`, `potion_held`,
  `potion_cap`, `potion_total_after`, `can_brew`, `brew_reason`, `brew_reason_text`. For a potion
  recipe `can_purchase` mirrors `can_brew`.

Commands:
- `WorldSession.brew(recipe_id) -> Error`: Stillroom only. Checks, in order: station, encounter,
  recipe, mastery, materials, overflow. Spends the cost and adds `yield_count` doses in one write.
  Repeatable. Never prepares or equips anything. `last_crafting`: `command = BREW`, `spent`,
  `produced: [{id, name, icon_path, count, total}]`.
- `prepare_potion(slot, potion_id)`: unchanged signature; now needs at least one held dose
  (`NO_STOCK`). Re-choosing the prepared potion is still a no-op. A prepared potion that runs out
  stays prepared at zero (`DEPLETED`) until brewed again or replaced.
- `purchase(recipe_id)` remains for older callers and dispatches by kind: a potion recipe
  brews, a fitting recipe crafts, a legacy kit is rejected (`RECIPE_RETIRED`).

`CraftingResult` additions: `Command.BREW = 4`, `Command.CRAFT = 5`; `Reason.STOCK_OVERFLOW = 22`,
`NO_STOCK = 23`, `RECIPE_RETIRED = 24`, `FITTING_NOT_OWNED = 25`, `INVALID_SOCKET = 26`,
`LOCKED_SOCKET = 27`, `NOT_BREWABLE = 28`; `produced`, `socket`. `POTION_LOCKED` is no longer
returned.

Battle: `PartyLoadout.potion_charges: Array[int]` (parallel to `potions`; empty = authored
charges, as Practice, the Lab and static loadouts use). `EncounterEntry.loadout.potion_charges`
holds the allowance. `BattleResult.item_uses: Dictionary[StringName, int]`.
`WorldSession.last_consumed: [{id, name, icon_path, count, total}]` after a victory.

Outcomes: §4. Migration: §3.

### 2.9 Direct-crafted fittings (A09, A10)

Data: `RecipeDefinition.Kind.FITTING = 2` (one fitting for one weapon; permanent). New recipes
`forge.merciful_grip` and `forge.hollow_echo`. `forge.first_fitting` (`FITTING_KIT`) stays as
legacy data.

- `WorldSession.craft_fitting(fitting_id) -> Error`: Forge only. `command = CRAFT`,
  `modification_id`, `recipe_id`, `spent`. Rejections: `UNKNOWN_FITTING`, `WEAPON_NOT_OWNED`,
  `ALREADY_OWNED`, `MASTERY_REQUIRED`, `INSUFFICIENT_MATERIALS`.
- `fit(weapon_id, fitting_id, socket := 0)` and `remove_fitting(weapon_id, socket := 0)`: Forge
  only, free, owned fittings only (`FITTING_NOT_OWNED`); `INVALID_SOCKET` outside 0–2,
  `LOCKED_SOCKET` for 1–2. Existing duplicate-trait, action-limit and no-op behaviour is kept.
- `FittingReadout` gains `sockets: [{index, locked, reason, reason_text, fitting_id,
  fitting_name}]` (3; one usable), `socket_capacity := 1`, and per option: `owned`,
  `owned_source` (`&"crafted"`, `&"legacy_kit"`, `&""`), `recipe_id`, `costs: [{id, name,
  icon_path, count, held, enough}]`, `mastery_required`, `mastery_current`, `mastery_met`,
  `can_craft`, `craft_reason`, `craft_reason_text`, `can_fit`, `can_remove`,
  `action` (`&"craft"`, `&"fit"`, `&"remove"` or `&"none"`: the one primary command).
  `legacy_kit: {id, owned, can_refund, refund_reason, refund_reason_text, refund: […]}`.
- `capacity`, `kit_id`, `kit_owned` stay for older callers. `capacity` is now true for any
  fitting-capable weapon; ownership is per option.

### 2.10 Party Break (C04)

Engine facts (`BattleUnit`): `stagger` / `max_stagger` are the Break meter of **any** unit that has
one; `has_break_meter()`, `is_broken()`, `can_react()`.

Events (existing types; the subject may now be a party member):

| Event | Party use |
|---|---|
| `STAGGER_DAMAGE` | `subject` = defender, `other` = attacker, `amount`, `amount2` = remaining. `FLAG_REACTION_COST` (1024) marks a Parry's cost. At most one per defender per resolved enemy action. |
| `BROKEN` | `subject` = party member, `other` = attacker. |
| `TURN_SKIPPED` | The lost activation. |
| `RECOVERED` | End of the lost activation; the meter is full again (`max` unchanged). |

Order for one enemy action, per target in target order: `REACTION_RESULT` → Parry rewards
(attacker `STAGGER_DAMAGE`, `FOCUS_CHANGED`) → reaction triggers → `DAMAGE` → on-hit triggers →
party `STAGGER_DAMAGE` → `BROKEN` → the action's per-target effects.

Policy:
- **Amount.** Successful Parry: `party_break_parry_cost`, once per defending unit per resolved
  reaction (an area attack charges each parrying unit once, never per hit). Otherwise, for a
  damaging action: the action's Break damage (`EnemyActionDefinition.party_break`, default
  `party_break_hit`) × Brace 0.5 on a successful Brace, × Evade 0.0 on a successful Evade, × 1.0
  for no or a failed reaction. A non-damaging action deals none.
- **Not Break sources:** damage over time, triggered or effect damage, authored `STAGGER_DAMAGE`
  and `RESTORE_STAGGER` effects (still enemy-only), party ambush.
- **Lethal hit:** a defeated unit takes no Break and is not Broken.
- **Intercept:** the interceptor is the target and takes the Break. A Broken interceptor does not
  cover (the existing rule for any Broken interceptor).
- **Broken:** loses its next activation, then recovers. No reaction while Broken: it is left out
  of the reaction request, and when every party target is Broken no window opens. It takes no
  further Break while Broken.
- **Independent:** each unit has its own meter; simultaneous breaks resolve in target order.
- **Not inherited:** no weak point, no growing cap, no Focus for the breaker, no ×1.5 Broken
  damage, no `STAGGER_BREAK` trigger. Enemy Break is unchanged.

Preview and presentation facts:
- `ReactionSpec`: `break_unreacted`, `break_brace`, `break_evade`, `break_parry_cost: float`.
- `IntentPreview`: `break_unreacted`, `break_braced: Dictionary[int, float]` (target uid →
  amount), `break_parry_cost: float`.
- `PresentationLedger.UnitDisplay`: `stagger`, `max_stagger`, `broken` are now filled for party
  members too, advanced by the same events; new `has_break: bool`.
- `UnitReadout`: `has_break`, `break_current`, `break_max` (both sides). `resource` /
  `max_resource` keep their meaning (enemy Break, party Focus).
- `BattleMetrics`: `party_breaks` counted apart from enemy `breaks`.

### 2.11 Save origin, operation facts, sounds (N01, S02, S03)

- `SaveFact` (`src/save/save_fact.gd`): `slot: int`, `origin` (`enum Origin { AUTOMATIC = 0,
  MANUAL = 1 }`). `EventBus.save_completed(fact: SaveFact)`: once per successful write, after
  adoption. `MANUAL` = Save, Save and return to title, Save and Quit. Everything else, New Journey
  and Practice recording included, is `AUTOMATIC`. `game_saved(slot, ok)` is still emitted for
  older listeners. `JourneyNotices` listens to `save_completed` only, so one write shows one
  indication: a manual save's card or the quiet automatic icon.
- Operation facts, each once after adoption, none for a rejection, no-op or failed write:
  - `EventBus.crafting_completed(result: CraftingResult)`: Brew, Craft, Fit, Remove, prepared
    supply, legacy refund.
  - `EventBus.preparation_completed(result: PreparationResult)`: equip and unequip.
  - `EventBus.familiar_changed(result: FamiliarResult)`.
- `AudioManager.Cue` appended (existing indices unchanged): `UI_EQUIP`, `UI_UNEQUIP`,
  `CRAFT_SMITH`, `CRAFT_BREW`, `PURCHASE`. Files: `assets/audio/sfx/ui_equip.wav`,
  `ui_unequip.wav`, `craft_smith.wav`, `craft_brew.wav`, `purchase.wav`. A missing file is a
  silent no-op, as now.
- `AudioManager.operation_cue(result) -> int`: the cue for a changed result, or −1. Equip, fit,
  prepared supply and familiar choices → `UI_EQUIP`; unequip and remove → `UI_UNEQUIP`; Brew →
  `CRAFT_BREW`; Craft → `CRAFT_SMITH`; refund → `PURCHASE`.
- `OperationFeedback` (installed once by `JourneyNotices`) is the one owner of these sounds; the
  host plays none. The arrangement has no operation event, so `WorldCharacterView.present_combat`
  confirms a changed arrangement with `UI_CONFIRM`.

### 2.12 Victory learnings (C05)

`LearningReadout` (`src/progression/readouts/learning_readout.gd`): `enemy_id`, `name`,
`icon: Texture2D`, `icon_path`, `previous_tier`, `new_tier` (`Enums.ResearchLevel`),
`previous_tier_name`, `new_tier_name`.

`WorldSession.last_learnings: Array[LearningReadout]`: set by a successful `commit_victory`, one
entry per enemy whose tier rose, in enemy-id order. The old tier is read before adoption; a failed
write adopts nothing, so Retry reports the same old tier. A repeated token reports none.
`last_receipts` is unchanged. The host passes both to the victory view (§6).

## 3. Save format and migration

All additive to save version 1; no migration step in `SaveMigrator`; older builds ignore the keys.

| Key | Meaning |
|---|---|
| `inventory.consumables` | potion id → held doses, 1–99. Was an empty placeholder. |
| `loadout.familiar_passive` | Selected familiar passive (trait id). |
| `quests` | quest id → stage. Was an empty placeholder. |
| `migrations` | Applied one-time content migrations, e.g. `["supplies.finite_stock.v1"]`. |
| `crafting.recipes` | Now also holds crafted fitting recipes (`forge.merciful_grip`, …). |
| `world.pending_entry.loadout` | Gains `potion_charges` and `familiar_passive`. |

- **Supplies migration** (`supplies.finite_stock.v1`), once, inside world-entry reconciliation:
  each starter potion gains its `starter_stock`; each potion whose recipe the save owned, or that
  was prepared without one, gains one `yield_count`. The marker is written in the same write.
  A save with the marker never receives it again, whatever its stock. A fresh journey is created
  with its starter batch and the marker already set. Reset journey touches neither.
- **Fittings.** No migration write. Ownership is `crafting.recipes` has the fitting's recipe, or
  the save owns a legacy kit that offered it. The installed fitting is untouched. The kit's
  refund stays a deliberate Forge command: it returns 2 Bog Iron once, removes the kit and with
  it the grandfathered ownership and the installed fitting, exactly as before. Fittings the
  player crafted separately are unaffected. Nothing is refunded on load.
- **Old pending entries** have no allowance. They are discarded at world entry by the existing
  recovery (back to the approach, no award), so they never settle anything.
- **Sanitation.** Stock keeps whole numbers 1–99 for string ids; unknown potion ids stay inert.
  A familiar or passive that is unknown or not owned is repaired to an owned default at world
  entry. A quest stage is re-derived, never trusted.

## 4. Supply outcomes

| Event | Stock | Battle allowance |
|---|---|---|
| Entry (countdown expiry) | Unchanged | Captured: `min(cap, held)` per prepared position |
| Entry write fails → Retry | Unchanged | Captured by the retried entry |
| Victory, saved | Reduced by actual uses, once | — |
| Victory write fails → Retry save | Reduced once, when the write succeeds | — |
| Same victory committed twice | Second is a no-op | — |
| Defeat → Retry | Unchanged | The same captured allowance again |
| Defeat → Return to Gloamstead | Unchanged | Discarded |
| Leave battle | Unchanged | Discarded |
| Quit or crash mid-battle → reload | Unchanged | Discarded with the pending entry |
| Old pending entry (pre-revision) | Unchanged | Discarded at world entry |
| Brew | + `yield_count`; rejected whole above 99 | — |
| Reset journey | Unchanged | — |
| Practice, Lab, static loadouts | Never read or changed | Authored charges, as before |

A use can never exceed the captured allowance, and settlement never takes stock below zero.

## 5. Provisional values

All are data; none is tuned.

| Value | Where | Now |
|---|---|---|
| Party Break maximum | `BalanceConfig.party_max_break` | 40 |
| Break from an unreacted or failed-reaction hit | `party_break_hit` | 8 |
| Successful Brace | `party_break_brace_multiplier` | × 0.5 (4) |
| Successful Evade | `party_break_evade_multiplier` | × 0.0 |
| Failed reaction | `party_break_failed_multiplier` | × 1.0 |
| Successful Parry cost | `party_break_parry_cost` | 6 |
| Activations lost when Broken | `party_break_turns` | 1 |
| Per-attack override | `EnemyActionDefinition.party_break` | −1 (use the default) on every action |
| Countdown | `EncounterCountdown.DURATION` | 3.0 s; rearm 24 px |
| Starter stock | `PotionDefinition.starter_stock` | Mending Draught 4, Fen Water Flask 4 |
| Per-encounter cap | `PotionDefinition.charges` | Mending 2, Flask 2, Salve 1, Tincture 1 (unchanged) |
| Brew | `RecipeDefinition.costs` / `yield_count` | Mending: 1 Bog Iron → 2. Flask: 1 Bog Iron → 2. Salve: 1 Bog Iron → 2. Tincture: 1 Storm Salt → 2 |
| Fitting | `forge.merciful_grip`, `forge.hollow_echo` | 2 Bog Iron each, 1 mastery point (Pilgrim's Edge, Mire Maul or Reedbow) |
| Stock ceiling | `PotionDefinition.MAX_STOCK` | 99 |
| Capacities (unchanged) | rules | 6 of 8 positions, 2 of 4 supplies, 1 of 3 sockets, 10 or 15 of 20 bag cells |

Route budget today: 5 Bog Iron (patrol 2, guard 2, iron seam 1) and 1 Storm Salt (guard). The
catalog check changes from "all recipes together fit the budget" to "each recipe alone is
affordable from the budget", because brewing is repeatable.

## 6. Ownership, integration and the Godot window

**Parallel phase.** I owned backend, data, save, rules and tests, and routed exclusively through
`src/world/world_host.gd`, `scenes/battle/battle_scene.gd`, `src/autoload/audio_manager.gd`,
`src/ui/battle/presentation/presentation_ledger.gd` and `.../unit_readout.gd`. Codex built every view
against §2 and recorded its work in [the Director report](V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md).

**After Codex's checkpoint (10 October, evening).** Codex returned the Godot window and stopped at
its usage limit. Adrian then let me implement remaining frontend work following Codex's existing
practice. Every request in the earlier version of this section is delivered (Codex: settings
capture, `save_completed` notices, `OperationFeedback`, familiar trait, `WorldCopy` lines, party
Break bars, Break log/playback for party subjects). I changed these Codex-owned files, each for a
reason listed in §8: `hover_inspector.gd`, `owned_choice_popup.gd`, `world_character_view.gd`,
`world_crafting_view.gd`, `world_loadout_view.gd`, `world_journal_view.gd`, `world_reward_view.gd`,
`threat_countdown_view.gd`, `exploration_hud.gd`, `journey_notices.gd`, `operation_feedback.gd`,
`world_modal.gd`, `battle_log_formatter.gd`, `world_copy.gd`, `capture_playtest_revision_runner.gd`,
`capture_world_runner.gd`, `validate_material_polish.gd`, and the Director tests
`test_world_v05_integration`, `test_world_character_menu`, `test_world_ui_prototype`,
`test_playtest_revision`, `test_icon_ui` and `test_v02_ui` (adapted to the landed views and to
Adrian's tooltip rule, §8.5 and §9; every read-only, write-count and rejection check kept). I did not edit the Decision Log, GDD, testing
index or return queue.

**Host wiring (final).** The host calls the views directly; there are no `has_method`/`has_signal`
probes left.

| View | The host calls | The host listens for |
|---|---|---|
| Character | `present(inventory, loadout)`, `select_tab`, `present_preparation` / `present_combat` with the adopted result | `equip_requested`, `unequip_requested`, `potion_requested`, `combat_requested`, `familiar_requested`, `familiar_passive_requested`, `journal_requested`, `field_guide_requested` |
| Station | `present(crafting, service, selection, notice, inventory)`, then `present_operation(result)` after an adopted command | `command_requested(command, id, slot)`: `brew`, `craft`, `fit`, `remove`, `potion`, `refund` (`purchase` still routed for older callers) |
| HUD | `present_countdown(readout)` | `journal_requested` (plus map, menu, character) |
| Victory | `WorldRewardView.make(receipts)`, `present_learnings(learnings)`; no prose | — |
| Journal | `WorldJournalView.make(session.quests())` in a modal of kind `journal` | — |

**Godot window: free.** My last engine process (the final Compatibility/Dummy suite) has exited.
No QA run is active. A windowed Godot editor (PID 4516, started 18:13 with no arguments, probably
Adrian's) was open throughout; I left it alone. A windowed editor re-saves `project.godot` on exit,
so check `git diff project.godot` before committing.

## 7. Progress

| Area | Contract | Code | Tests |
|---|---|---|---|
| Mouse bindings (I01) | published | landed; Settings capture wired | `test_mouse_bindings` |
| Wall movement (E01) | published | landed (`WorldPlayer.walked`) | `test_world_revision_host` (taps, slide, footsteps) |
| Save origin, operation facts, cues (N01, S02, S03) | published | landed; one presentation owner each | `test_world_revision_session`, `test_world_save_events`, `test_playtest_revision` |
| Ingredient catalog, bag cells (L03, L04, A01) | published | landed | `test_loadout_rules`, `test_world_salvage_host`, `test_world_character_menu` |
| Encounter countdown (E02) | published | landed; host and HUD wired | `test_encounter_countdown`, `test_world_revision_host` |
| Quest journal (E03) | published | landed; Journal from menu, HUD and Character | `test_world_revision_session`, `test_world_revision_host` |
| Loadout sources, reconciliation facts (L02, L06–L09) | published | landed; unified view | `test_loadout_rules`, `test_world_combat_arrangement`, `test_world_ui_prototype` |
| Familiar and passive (L08) | published | landed; captured in entries | `test_world_revision_session` |
| Finite supplies (A04–A07) | published | landed | `test_supply_rules`, `test_world_supplies`, `test_world_crafting` |
| Fittings (A09, A10) | published | landed | `test_crafting_rules`, `test_world_crafting`, `test_world_revision_session` |
| Party Break (C04) | published | landed; ledger, readout, bars, log | `test_party_break` (rules, replay, ledger and readout), determinism probe |
| Victory learnings (C05) | published | landed; victory view | `test_world_revision_session`, `test_world_revision_host` |
| Host routing | published | landed (§6) | world suites above |

## 8. Contract changes after publication

None changes saved data or a rule. Consumer edits are already made.

1. **`WorldCharacterView.present(inventory, loadout)`** replaces `present(inventory, character,
   preparation, crafting, combat)` + `present_loadout(loadout)`. The pre-Loadout Equipment and Combat
   pages, the hidden `Tab_combat` and their fields are gone (unreachable: the host always supplied
   the Loadout). Updated: host, `capture_playtest_revision_runner.gd`, two Codex tests.
2. **`WorldCraftingView`** keeps only the stock-contract branch (`present` → the live layout). The
   pre-revision Forge graph, potion slots, recipe catalog and their "Purchase/Unlocked" actions are
   gone (unreachable: every `CraftingReadout` carries `stock`). `_revision` merged into the typed
   `_readout`. Updated: `capture_world_runner.gd`'s `forge-fitted`, `forge-refund`, `forge-receipt`
   and `stillroom-potion` states now use crafted ownership, the grandfathered kit, a first Craft and
   brewed stock.
3. **Wording.** Rules read `WorldCopy` constants directly; the overlap lookup `WorldText.line` is
   unused. Added `JOURNAL_TITLE`, `BAG_LOCKED_CELL`, `SUPPLY_LOCKED_POSITION`, `SUPPLY_LOCKED_TITLE`,
   `SUPPLY_EMPTY_TITLE`, `SUPPLY_EMPTY_TEXT`, `SUPPLY_FACT_HELD`, `SUPPLY_FACT_USABLE` with the text
   players already saw. Removed lines that described the retired model or the removed pages:
   `VICTORY_BODY` (and `WorldModal`'s filter for it), `CRAFT_ALREADY_OWNED`, `CRAFT_NOT_REFUNDABLE`,
   `COMBAT_UNPLACED_LIST`, `COMBAT_PLACE_HINT`.
4. **Typed hooks:** `present_countdown(EncounterCountdownReadout)`, `present_operation(CraftingResult)`,
   `present_learnings(Array[LearningReadout])`, `WorldJournalView.make(QuestJournalReadout)`,
   `WorldLoadoutView.present(LoadoutReadout)`, `ThreatCountdownView.present(...)`,
   `JourneyNotices._save_completed(SaveFact)`, `ExplorationHUD._quest_changed(QuestChange)`.
   `JourneyNotices` no longer falls back to `game_saved`; `OperationFeedback` and the HUD connect
   their events directly.
5. **`HoverInspector`:** a floating card dismisses as soon as its source is left (unless pinned);
   a docked inspector keeps `EXIT_GRACE = 0.14` s and its self-hover behaviour (field help, wheel
   inside the dock, same subject). See §0.10.
6. **`EncounterEntry.from_dict`** restores the allowance (`potion_charges`) to whole numbers, as it
   already did for research: a pending entry read back from a save file equals the captured one
   (JSON has no integers). This closed the `test_world_session` round-trip failure.
7. **Fixes in Codex's views:** `OwnedChoicePopup._layout` returns when the popup left the tree (a
   choice made in the frame it opened replaced the view and logged `get_viewport_rect` errors);
   the battle log says "Break -6 for the Parry" for a reaction cost.
8. **Host:** equipment, unequip and supply commands reopen the Loadout on the selected combat
   position instead of position 1.
9. **`validate_material_polish.gd`** accepts the six continuous slider/scrollbar strips as SVG
   (Codex's final checkpoint replaced their PNGs); all other material bitmaps must still be PNG.

## 9. Verification

All runs: `python tools/qa_godot.py --godot C:\Users\Adrian\Code\Games\Godot_v4.7.2-stable_win64_console.exe
--home .godot/qa-playtest-revision/<run> …`, one engine process at a time, each in its own home.
Python: `C:\Users\Adrian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`.

**Starting point (this session).** Codex's last full Compatibility run (18:07) had 8 failures in my
suites (see [failure inventory](v0_5_playtest_revision/FAILURE_INVENTORY.md)). Root causes and fixes:
a unit test mutating the shared sword/charm definitions through a shallow `Resource.duplicate()`
(the Earthsplitter contamination; the fixture now copies the arrays); stale expectations of the old
Character, ingredient and notice nodes (rewritten against the Loadout, `IngredientStrip` quantity
labels and the save-origin icon/card, keeping every write-count, rejection and read-only check); a
one-time supply-migration write in a fixture that recorded no journal stage; the JSON
float round trip (§8.6); the wall-tap and countdown host tests (physics-space setup and the
running owner's rearm order). My first full run then exposed **5 regressions from Codex's final
follow-up** (tooltip dismissal reaching the battle dock, §0.10; the restored circular Anvil's extra
children in a socket count); all fixed.

| Check | Command | Result |
|---|---|---|
| Fresh import | `--headless --import` | clean |
| All scripts | `--headless --script res://tools/check_scripts.gd` | **350 checked, 0 failed** |
| Tool entry points | every `extends SceneTree` tool with `--headless --check-only` | **21 / 21 clean** |
| Full suite, headless | `--headless --audio-driver Dummy --script res://tests/run_tests.gd` | **527 passed, 0 failed, 10,309 assertions** (139 s) |
| Full suite, rendered | `--hidden --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/run_tests.gd` | **527 passed, 0 failed, 10,333 assertions** (137 s) |
| Diagnostics, both suites | — | exactly the documented 9 invalid-save errors and 6 warnings (5 `WorldSession` sanitation, 1 `Needs 5 Focus`) |
| World art | `--script res://tools/validate_world_art.gd` | **376 checks, 0 failures** |
| Material polish | `--script res://tools/validate_material_polish.gd` | **264 checks, 0 failures** (6 before §8.9) |
| Python | `python -m unittest discover -s tests -p "test_*.py"` | **10 tests OK** |

The last stable full result before this revision was 450 tests / 7,248 assertions headless
([V0.5 UI backend](V0_5_UI_BACKEND_IMPLEMENTATION.md)). The 16:42 log in
`.godot/qa-playtest-revision/baseline-headless.log` was captured while Codex's files were mid-edit
(parse errors), so it is not a baseline.

**Determinism and unrelated drift.** A scratch probe plays every shipped encounter × 6 production
loadouts (sword, hammer, bow, sword + Storm Salt Charm, sword + coat + Bell Crow, hammer + leathers
+ Cinder Pup) × seeds 11, 222, 3333 = 144 battles with the party autopilot and simulated execution,
hashing every event field, the input log and the outcome (`WorldKit.fingerprint`).

| Tree | Party Break | Total hash |
|---|---|---|
| Current, run 1 | on | `9235dfd9de57a9fe…` |
| Current, run 2 | on | `9235dfd9de57a9fe…` (identical) |
| Current | off (`party_max_break = 0`) | `d8946e570f002d4c…` |
| `35c8763` clone, fresh import | (absent) | `d8946e570f002d4c…` (identical, line by line) |

So the revision is deterministic, and with party Break switched off every battle is identical to the
committed baseline: the only change to battle outcomes is the authorized mechanic. With it on, 136
of 144 event streams change (each enemy hit now emits a party Break event). Seeded replay is
covered by `test_party_break::test_party_break_is_deterministic_and_replays_exactly`.

**Simulation.** `--script res://tools/simulate.gd -- --encounter=all --exec=MISS,GOOD,PERFECT,MIXED
--difficulty=ADVENTURER --runs=100 --seed=1` on the current tree and the `35c8763` clone: 96 batches,
no script errors. Good, Mixed and Perfect: identical win rates (100 %), rounds and damage within
0.6. Miss: 81.2 % → 67.9 % (see §0.9).

**Mutation check.** A scratch copy of the tree (never the shared checkout), freshly imported; each
mutation reverts one behaviour and must fail a named suite without a parse error. **28 / 28
caught**: settle twice; settle beyond the captured allowance; migration ignoring its marker;
allowance ignoring held stock; victory settling nothing; brew spending nothing; brew overflow;
preparing without stock; fitting an unowned fitting; a locked socket accepting a fitting; Parry
costing nothing; Brace mitigating nothing; a Broken party member reacting; Broken party taking the
enemy vulnerability; leaving the reach not cancelling; a freeze resetting the countdown; no rearm
hysteresis; familiar ownership unchecked; a manual save reported as automatic; world entry
replaying quest notices; learnings without a tier increase; wall taps reading as walking; a left
click captured as a binding; a saved allowance keeping JSON floats; the battle dock dismissing on
self-hover; the ledger's recovery leaving the bar empty; a party member without a presented bar;
the readout showing the maximum as current Break. The learnings mutation first **survived**: the
test only covered a victory with no research. It now also covers research that raises no tier (an
enemy already at Mastered). The last three needed a test that did not exist:
`test_party_break::test_presentation_follows_each_party_bar_from_the_events` now replays a real
party Break through `PresentationLedger` and `UnitReadout`.

**Rendered checks.** `capture_playtest_revision.gd` states `loadout`, `forge` and `stillroom` are
byte-identical to Codex's reviewed `followup_*.png` after the cleanup; `inventory` was reviewed by
eye. `capture_world.gd` states `forge-receipt`, `forge-refund`, `forge-fitted` and
`stillroom-potion` run through the real host without errors (receipt: 2 Bog Iron spent, "Crafted"
→ Fit; refund: both fittings grandfathered, installed fitting kept, "Reclaim old kit" offered).
Outputs are in `.godot/qa-playtest-revision/` (not evidence for the repo).

## 10. Return

**Capacities (unchanged by this revision):** 6 of 8 combat positions, 2 of 4 supply positions, 1 of
3 fitting sockets, 10 (15 after the bell reward) of 20 bag cells, 3 action icons per gear source,
1 of up to 3 familiar passives, 99 doses per potion. All are derived, none saved (§3).

**Policies:** migration, refund and consumption are §3 and §4; provisional values §5. Practice, the
Lab and static loadouts never read or change stock (authored charges).

**Remaining work.**
- `src/world/world_text.gd` (+ `.uid`) is unused. Deleting it was blocked by the session's
  permission guard; please delete both files (they are untracked and new in this revision).
- `WorldHost.open_encounter_card`, `WorldEncounterView` and `WorldRules.encounter_card` are unused
  by the game since the countdown replaced the card; tests and `capture_world_runner.gd` still use
  them. Keep or remove is the Director's call.
- `WorldCopy.STONES`, `MAP_LEGEND`, `MAP_EMPTY`, `REWARD_SAVED` were already unused at `35c8763`.
- Codex-owned docs not touched: Decision Log entries for §0 (finite supplies, kit grandfathering,
  party Break, countdown, save origins, tooltip scope), the testing index (the new revision suites
  and this report's commands) and the return queue.

**Integration edits for Codex:** none required. Please review §0.9–§0.11 and §8 (they changed your
files) and re-render anything you want to keep as evidence.

**Human gates (open):** mouse/keyboard/controller feel (extra mouse buttons, wall taps, countdown
fairness), tooltip readability and the dock/floating split, selection clarity, SFX mix and
repetition, title motion, the finite-supply economy, fitting prices and party Break balance, and
the full earlier playtest checklist. V2/V0.6 is not started and is not complete.

## 11. Follow-up: Adrian's review before the V0.5 push (10 October, evening)

Adrian reviewed the integrated build and asked for eight changes before pushing V0.5. Each was
traced to its cause first; all are implemented, tested, mutation-checked and rendered.

### 11.1 What changed and why

1. **Session logs for crashes and bug reports.** Godot already wrote a log per desktop session
   (`user://logs/godot.log`, earlier sessions kept with a timestamp), but the game printed nothing
   into it: Adrian's log from 19:37 that day ends in an engine crash (signal 11) with only an
   unsymbolised native backtrace, so nothing says what the game was doing. Now `project.godot` keeps
   file logging on for every platform at `user://logs/hollow_choir.log` and flushes every print
   (`application/run/flush_stdout_on_print`); Godot's default of 5 kept sessions stays, so a crashed
   session's log survives the restart. The new `SessionLog` autoload writes a header (version, save
   format, debug/release, Godot, OS, locale, adapter and API, renderer, screen and window, start time,
   user arguments), one `[T+mm:ss.mmm] category: text` line per notable event (scene changes, area
   loads with position, opened views and screens, engagements, battle start with encounter, seed and
   difficulty, battle result with rounds and input count, saves with origin, failed writes with the
   error, loads, quest stages) and `session: ended normally` on a clean exit, so a log without that
   line ended in a crash or a kill. The test runner sets `SessionLog.quiet`. Settings → Gameplay →
   **Open log folder**; README "Logs and bug reports".
2. **Forge sockets not centred on the wheel** and 4. **map circles off-centre.** One cause: the ring
   art. `tools/prepare_material_polish.gd` cropped `ring.png` and `ring_open.png` from
   `sources/reactions.png` with squares that sat up-left of the art (true bounds x 28–317 and 345–635,
   y 34–323), so both 128 px textures were about 6 × 8 px off-centre and had lost their right and
   bottom ornaments. Every user draws them centred on a rect: the Forge wheel looked shifted down-right
   of the sword and sockets, and each map ring down-right of its dark disc and label. The socket and
   sword geometry was already symmetric. The crops are now `Rect2i(25, 31, 295, 295)` and
   `Rect2i(343, 31, 295, 295)`, centred on the art, and only these two textures were re-exported with
   the tool's own crop and nearest-neighbour resize. **Side effect:** the battle's shrinking timing ring
   and impact ring use the same textures and are now centred on their target as well.
3. **A gate post drawn in front of Hollow.** Gloamstead's `DepthSorted/ReedGate` held its two 22 × 56
   posts as one sort unit at y 868, in the middle of the south post and 68 px below the north post's
   base, so standing in the gate opening drew Hollow behind the north post. The gate node now y-sorts
   its posts one by one, each with its origin at its base (4 px above the art's bottom edge, as other
   props) and the art offset upward: nothing moves on screen. An audit of every depth-sorted prop in both
   areas found parts far above their sort point only in the town bell, the wayside bell and the square
   lamp; physics probes show the walkable spots there are behind those objects, where they should draw
   over Hollow (their parts are slices of one object standing on one base line). Nothing else changed.
5. **Shortcuts.** `WORLD_LOADOUT` (L), `WORLD_INVENTORY` (I), `WORLD_JOURNAL` (J) and
   `WORLD_FIELD_GUIDE` (F), keyboard only, because the pad's face buttons belong to menus (Y is
   Details). The map's M joined the same scheme (`WorldHost.SHORTCUTS`, `toggle_view`,
   `shortcut_view`): a key opens its view from exploration and closes it when it is on screen through
   the view's own Back (a view opened from the pause menu returns there); another shortcut key switches
   views (Loadout ↔ Inventory only changes the Character tab). Stations and their Character card,
   dialogue, the pause menu, reward and save-failure cards, battles and transitions ignore them.
   `FieldGuide.close()`. The toolbelt tooltips read "[L] Loadout" and "[J] Journal", the pause menu's
   help card lists sprint and the shortcuts from the live bindings, and Settings lists all five for
   rebinding (rows come from `InputBindings.DEFAULTS`).
6. **Stillroom: a choice's card behind the popup.** The card for a hovered choice was placed 12 px
   right of the row, which is still inside the popup's frame and scrollbar, and both are top-level, so
   their z-index is absolute: the card (90) drew under the popup (120) wherever they overlapped (more
   so with a scrollbar or larger text). `HoverInspector` now places a card whose source sits inside a
   control marked with the `tooltip_anchor` meta beside that whole control, level with the row;
   `OwnedChoicePopup` sets the meta and raises its own card to z 130.
7. **E at a threat no longer fought.** Interact called `EncounterCountdown.request()`, which did
   nothing while a countdown ran and otherwise only restarted it. Interact now calls `engage(site)` at
   once: the same single entry write and launch, a running countdown dropped first, no second battle,
   Retry on a failed write. The prompt reads "Engage the patrol" (`WorldCopy.PROMPT_ENGAGE` replaces
   `PROMPT_APPROACH`). `request()` was removed (no caller). Supersedes §0.6 and the §2.3 rule.
8. **Sprint with a stamina meter.** `WORLD_SPRINT`: hold Shift (pad: left-stick press). `Stamina`
   (pure): five seconds of sprint from full (`DRAIN_SECONDS`); whenever Hollow is not sprinting it
   refills at a rate that takes five seconds from empty (`RECOVER_SECONDS`), so half a meter refills
   in 2.5 s; emptying it leaves Hollow exhausted until the input is released, so a held key never
   flickers between paces. `WorldPlayer.step(direction, delta, sprint)` moves at
   `SPRINT_MULTIPLIER` 1.6 × `SPEED` and plays the walk cycle 1.45 × faster; only travel actually
   achieved at sprint speed spends stamina (pushing into a fence spends nothing); menus freeze it
   (the host only steps while exploring); `place()` resets it. `StaminaMeter` draws a 22 × 3 px bar
   just under the feet, above the depth layers: shown while not full, faded out once full, dimmed while
   exhausted, instant under Reduce Motion. Nothing is saved. `WorldHost.sprint_held()` reads the input
   through the held-input gate (`scripted_sprint` in tests). Sprinting makes the move-away countdown
   easier to escape; movement stays live by design.

### 11.2 Contract changes

Removed: `EncounterCountdown.request()`, `WorldCopy.PROMPT_APPROACH` (now `PROMPT_ENGAGE`).
Changed: `WorldPlayer.step(direction, delta, sprint := false)`. Added: `InputBindings.WORLD_SPRINT`,
`WORLD_LOADOUT`, `WORLD_INVENTORY`, `WORLD_JOURNAL`, `WORLD_FIELD_GUIDE`; `Stamina`; `StaminaMeter`;
`WorldPlayer.stamina`, `SPRINT_MULTIPLIER`, `SPRINT_ANIMATION`; `WorldHost.SHORTCUTS`,
`toggle_view()`, `shortcut_view()`, `sprint_held()`, `scripted_sprint`; `FieldGuide.close()`;
`SessionLog` (`event()`, `folder()`, `quiet`); `WorldCopy.CONTROLS_NOTE`; the `tooltip_anchor`
meta. `docs/DATA_CONTRACTS.md` has the details.

Files: `project.godot`, `README.md`, `docs/DATA_CONTRACTS.md`, this report;
`assets/art/global/ui/material_v02/textures/ring.png`, `ring_open.png`;
`scenes/world/areas/gloamstead.tscn` (the gate only); `scenes/battle/battle_scene.gd`,
`scenes/main/field_guide.gd`, `scenes/main/settings_screen.gd`; `src/autoload/scene_router.gd`,
`session_log.gd` (new); `src/core/input_bindings.gd`; `src/world/world_host.gd`, `world_player.gd`,
`world_rules.gd`, `world_copy.gd`, `encounter_countdown.gd`, `stamina.gd` and `stamina_meter.gd`
(new); `src/ui/battle/hover_inspector.gd`, `src/ui/world/owned_choice_popup.gd`,
`exploration_hud.gd`; `tools/prepare_material_polish.gd`; tests `tests/run_tests.gd`,
`tests/unit/test_stamina.gd` (new), `test_encounter_countdown.gd`,
`tests/world/test_world_followup.gd` (new), `test_world_revision_host.gd`, `test_world_host.gd`,
`tests/ui/test_playtest_followup.gd` (new).

### 11.3 Verification (final tree)

| Check | Result |
|---|---|
| Fresh import; all scripts; tool entry points (`--check-only`) | clean; **355 / 0**; **21 / 21** |
| Full suite, headless | **543 passed, 0 failed, 10,607 assertions** (148 s) |
| Full suite, Compatibility/Dummy | **543 passed, 0 failed, 10,631 assertions** (147 s) |
| Diagnostics | identical in both suites: the documented 9 invalid-save errors and 6 warnings |
| World art · material polish · Python | **376 / 0** · **264 / 0** · **10 OK** |
| Determinism probe (144 battles) | party Break on `9235dfd9…`, off `d8946e57…`: both line-for-line identical to the runs before the follow-up and to `35c8763`; no battle outcome changed |
| Follow-up mutations (scratch copy) | **14 / 14 caught**: Interact waiting again, sprint no faster, pushing a wall spending, arriving keeping a used meter, no exhaustion latch, refill ignoring what was used, a full meter staying on screen, sprint ignoring the held-input gate, a shortcut never closing its view, shortcuts taking over a station's card, a choice card anchored to its row, a choice card under its popup, the gate sorting as one again, breadcrumbs ignoring quiet |

New suites: `test_stamina` (4 tests: five seconds of sprint, proportional refill, the exhaustion
latch, only achieved travel spends), `test_world_followup` (7: speed, spending, freezing and refill
through the real host, exhaustion, a fence, the held-input gate, shortcuts open/switch/close without
writes, contexts that ignore them with a real key through the modal's own toggle, the gate posts),
`test_playtest_followup` (4: ring art centred and complete — fails on the old textures — the Forge
sockets symmetric on the wheel, a choice card beside and above its popup, the log settings,
breadcrumb format, quiet and the Settings button). `test_world_revision_host` gained
`test_interact_at_a_threat_fights_at_once_and_only_once`.

Rendered (scratch, 1280 × 720): the Reed gate before/after with Hollow in the opening, the Stillroom
popup card before/after, the Forge wheel and the Reedway map after, the meter while sprinting and
while exhausted. A probe run's real `hollow_choir.log` shows the header, an area breadcrumb and
`session: ended normally`.

### 11.4 For the Director and Adrian

- **Other crops in the same sheet look off too** (content centre vs crop centre in source pixels,
  measured with art touching the crop edge): needle (+43.5, +18.5), impact (+25.5, +42), brace (+9, 0),
  evade (+8, 0), parry (+5, +15.5), reaction_selected (−4, +16), timing_track (+1.5, +17.5),
  timing_fill (+6.5, +15.5), cursor (+8.5, +6), broken (+6.5, 0), broken_plaque (+3.5, +21),
  target_rim (+11.5, +15), scroll_corner (+11.5, +14), hollow_head (+7, 0). Some pieces may be
  asymmetric on purpose; these are battle and map art, so I changed none of them. Each needs a
  per-piece look and the same re-crop where it is wrong.
- **Decision Log** entries are due for: Interact fights at once (supersedes the §0.6 rule); sprint
  values (×1.6, five seconds, proportional refill, exhaustion until release); keyboard-only view
  shortcuts; the log's location and retention. The testing index should list the three new suites.
- **Human gates:** sprint speed and stamina durations, the meter's readability, the shortcuts'
  feel, the popup card's placement, the gate from every side, and the battle rings now centred on
  their targets.
- **The 19:37 crash** cannot be diagnosed from its log (a native fault without symbols or game
  context). If it happens again, the new breadcrumbs will show what led up to it.

**Godot window: free.** No engine process is running.
