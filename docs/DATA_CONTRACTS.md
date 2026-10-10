# Data Contracts

Owner: Claude (data structures). Audience: designers authoring content, and the Director reviewing
what a mechanic can express. Every number and every piece of content in Milestone 1 lives in
`data/**/*.tres` Resources; code only interprets them.

## 1. Ground rules

- **Definitions are immutable at runtime.** A `*Definition` Resource is never written to during
  play. Battle state lives in runtime objects (`BattleUnit`, `StatusInstance`, `TraitInstance`,
  `BuffInstance`, `EnemyIntent`, …) that point at definitions.
- **Ids are `StringName`s on the Resource** (`id = &"pilgrims_edge"`), unique per collection. Code
  never names content ids; defaults that would otherwise be ids live in `data/config/defaults.tres`
  (`GameDefaults`).
- **Closed sets are enums with explicit values, append-only** (DECISION_LOG D-005). Never reorder or
  reuse a value: `.tres` files and saves store the integer.
- **Discovery is by folder scan** (D-012). Drop a `.tres` anywhere under `data/`; `DefinitionRegistry`
  indexes it by type and id, `validate()` reports problems, and the test suite fails on any problem
  (`tests/content/test_content.gd`). Every definition has a `validate()`.
- **Union Resources.** `EffectDefinition` and `ConditionDefinition` are one Resource type with a `type`
  field; the inspector only shows the fields that type uses (tables below), and `validate()` rejects
  missing ones.

```
data/
  config/        BalanceConfig (balance.tres), ResearchConfig, GameDefaults (defaults.tres)
  difficulty/    TacticalDifficultyProfile ×3        assist/      ExecutionAssistProfile ×4
  simulation/    ExecutionSkillProfile ×4 (MISS/GOOD/PERFECT/MIXED)
  statuses/      StatusDefinition (Burn, Wet, Shock, Bleed)
  conditions/    BattlefieldConditionDefinition (Flooded Ground, Spore Fog)
  roles/         EnemyRoleDefinition ×6 (role-default AI considerations)
  buffs/         BuffDefinition (stances, marks, empowerments)
  actions/       ActionDefinition / EnemyActionDefinition (common, sword, hammer, bow, magic, companion)
  weapons/ armor/ resonances/ familiars/ potions/ characters/ enemies/
  encounters/    EncounterDefinition           loadouts/    PartyLoadout
  world/         WorldDefinition (V0.4 journey)
  materials/     MaterialDefinition (V0.5A salvage)   rewards/   RewardDefinition (V0.5A claims)
  crafting/      RecipeDefinition (V0.5B Forge/Stillroom)
  modifications/ ModificationDefinition (V0.5B weapon fittings)
```

## 2. The rules vocabulary (Traits)

Weapon identities, armor rules, resonance pairs, companion passives, familiars, status behaviour,
battlefield conditions, buffs and species mechanics are all **Traits** (D-004):

```
TraitDefinition
├── modifiers: ModifierDefinition[]          "while present, change a number"
│     stat, operation (ADD | MULTIPLY), value, conditions[]
└── triggers: TriggeredEffectDefinition[]    "when X happens to a unit related to me, if Z, do W"
      trigger, watch (ACTOR | TARGET | NONE), relation, conditions[], effects[],
      chance, max_per_round, max_per_battle, announce
```

**Modifier queries.** `value = (base + Σ ADD) × Π MULTIPLY`, using only modifiers whose conditions pass
for that query's actor/target (e.g. attacker/defender for damage). Stats: `MAX_HP FORCE GUARD TEMPO
MAX_FOCUS DAMAGE_DEALT DAMAGE_TAKEN STAGGER_DEALT STAGGER_TAKEN HEALING_DEALT HEALING_TAKEN FOCUS_GAIN
GOOD_WINDOW PERFECT_WINDOW COMMAND_SPEED PERFECT_MULTIPLIER MISS_MULTIPLIER BRACE_WINDOW EVADE_WINDOW
PARRY_WINDOW BRACE_REDUCTION STATUS_DURATION_DEALT STATUS_DURATION_TAKEN STATUS_STACKS_DEALT PARRY_STAGGER
WEAK_POINT_MULTIPLIER`.

**Trait owners.** Weapon/armor/resonance/familiar traits are owned by the protagonist; a companion
passive by the companion; a status trait by its bearer; a buff by the buffed unit; an enemy trait by
the enemy; a battlefield condition has **no owner** (use relation `ANY`).

### Trigger roles

| Trigger | ACTOR | TARGET |
|---|---|---|
| `BATTLE_START`, `ROUND_START`, `ROUND_END` | — | — |
| `TURN_START`, `TURN_END` | unit whose activation begins/ends | — |
| `ACTION_RESOLVED` | user | primary target |
| `HIT_LANDED` | attacker | defender (once per target hit) |
| `DAMAGE_TAKEN` | attacker (may be none) | damaged unit |
| `REACTION` | attacker | reacting unit |
| `STATUS_APPLIED` | source (may be none) | bearer |
| `STATUS_REMOVED` | — | former bearer |
| `STAGGER_BREAK` | breaker | broken unit |
| `WEAKPOINT_EXPOSED` | cause | exposed unit |
| `ITEM_USED` | user | item target |
| `HEALED` | healer | healed unit |
| `UNIT_DEFEATED` | killer (may be none) | defeated unit |

`watch` picks the role whose relation to the trait owner is checked: `OWNER`, `OWNER_ALLY` (incl.
owner), `OWNER_ALLY_OTHER`, `OWNER_ENEMY`, `ANY`. Trigger recursion is limited by
`BalanceConfig.max_trigger_depth`; effects caused by a chain carry the CHAIN flag (`FROM_CHAIN`).

### Effects (`EffectDefinition.type` → fields used)

| Type | Fields | Notes |
|---|---|---|
| `DAMAGE` | target, amount, scaling, damage_type | grade-scaled inside actions |
| `HEAL` | target, amount, scaling | grade-scaled inside actions |
| `GAIN_FOCUS` / `LOSE_FOCUS` | target, amount, scaling | |
| `STAGGER_DAMAGE` | target, amount, scaling | grade-scaled inside actions |
| `APPLY_STATUS` | target, amount (stacks), status, duration (0 = status default) | |
| `REMOVE_STATUS` | target, status | |
| `EXTEND_STATUS` | target, amount, status | turns or charges by the status' duration mode |
| `GRANT_BUFF` / `REMOVE_BUFF` | target, buff | re-granting refreshes, never stacks |
| `EXPOSE_WEAK_POINT` | target, duration | |
| `DELAY_TURN` | target | pending activation moves to the end of the round |
| `INTERCEPT` | target | owner covers the target until the owner's next turn |
| `CHAIN_STATUS` | target, amount, status, duration, filter_status | spreads to units having `filter_status`; flagged CHAIN |
| `CLEANSE` | target | removes every status |
| `RESTORE_STAGGER` | target, amount, scaling | |
| `ADD_CONDITION` / `REMOVE_CONDITION` | battlefield_condition | |

Every effect also has `conditions[]` (all must pass when it resolves) and `chance` (battle RNG).
Recipients (`target`): `OWNER ACTOR TARGET OWNER_ALLIES OWNER_ALLIES_OTHER OWNER_ENEMIES
TARGET_ALLIES_OTHER ALL NONE`. Inside an action, OWNER = ACTOR = the user and TARGET = each target.
Amount scaling: `FLAT`, `EVENT_AMOUNT` (× the event's damage/heal), `EVENT_STAGGER`, `EVENT_OVERHEAL`,
`RECIPIENT_MAX_HP`, `OWNER_FORCE` (× (1 + Force/100)), `RECIPIENT_STACKS` (× stacks of `status`).

### Conditions (`ConditionDefinition.type` → fields used)

| Type | Fields | Type | Fields |
|---|---|---|---|
| `ALWAYS` | — | `HP_BELOW` / `HP_ABOVE` | on, threshold |
| `GRADE_AT_LEAST` / `GRADE_IS` | grade | `IS_BROKEN` | on |
| `REACTION_SUCCEEDED/ATTEMPTED/FAILED` | reaction | `WEAK_POINT_EXPOSED` | on |
| `HAS_STATUS` | on, status | `IS_CHANNELING` | on |
| `EVENT_STATUS_IS` | status | `BATTLEFIELD_HAS` | battlefield_condition |
| `ACTION_CATEGORY_IS` | category | `FROM_CHAIN` | — |
| `ACTION_HAS_TAG` | tag | `HAS_BUFF` | on, buff |
| `WEAPON_FAMILY_IS` | on, family | `ROUND_AT_LEAST` | round_number |
| `DAMAGE_TYPE_IS` | damage_type | `IS_OWNER` | on |
| `IS_WEAKNESS_HIT` | — | `SIDE_IS` | on, side |

`on` = `OWNER | ACTOR | TARGET`; every condition has `negate`.

### Worked example — "Brace generates Focus" (an armor rule)

```
TraitDefinition  id=&"steady_heart"  description="A successful Brace grants 1 Focus."
└── triggers[0]: TriggeredEffectDefinition
      trigger = REACTION, watch = TARGET, relation = OWNER
      conditions = [ConditionDefinition type=REACTION_SUCCEEDED reaction=BRACE]
      effects    = [EffectDefinition type=GAIN_FOCUS target=OWNER amount=1]
      max_per_round = 1
```

## 3. Enemy AI data

An `EnemyActionDefinition` (extends `ActionDefinition`) carries the GDD contract: `base_priority`,
`focus_cost` (= resource_cost), `cooldown`, `target_rule`, `use_conditions`, `role_tags`,
`synergy_setup` / `synergy_payoff`, `can_brace / can_evade / can_parry`, `channel_turns`,
`intent_category`, `telegraph_text` (required) and `telegraph_detail` (revealed at UNDERSTOOD).

Score = `base_priority × Π considerations × difficulty rules × noise`. A consideration multiplies by
`weight` when its test holds, else by `else_weight`, and only at or above its `min_difficulty` — so the
same data makes Tactician enemies **smarter**, never statistically inflated. `EnemyRoleDefinition`
supplies default considerations merged into every action expressing that role (filtered by
`applies_to` intent categories). Each consideration's `reason` text feeds the intent's "Why" line.

## 4. How to add content

| To add… | Do this | Code needed |
|---|---|---|
| A weapon | New `WeaponDefinition` (family, damage type, base power keeping the family spread ≤ 25%, basic attack, techniques, identity traits) | No |
| A weapon technique | New `ActionDefinition` with a `command` (one of the four command types) | No |
| An enemy | New `EnemyDefinition` (role, stats, Stagger, affinities, actions with telegraphs and reaction flags) | No |
| A boss phase | `BossPhaseDefinition` in the enemy's `phases` (descending `hp_threshold`) | No |
| A battlefield condition | `BattlefieldConditionDefinition` with an always-visible `description` and traits (relation `ANY`) | No |
| A familiar | `FamiliarDefinition` whose trait triggers on GDD events (relation relative to the protagonist) | No |
| A potion | `PotionDefinition` + an `ITEM` category `ActionDefinition` | No |
| An encounter | `EncounterDefinition` (1–4 enemies, ≤1 major + ≤1 minor condition) — appears in the sandbox automatically | No |
| A salvage material | `MaterialDefinition` in `data/materials/` (id, public name and description, optional icon) | No |
| A campaign reward | `RewardDefinition` in `data/rewards/`: a stable dotted claim id, a public label, a source (`SITE_VICTORY` + encounter landmark id, or `WORLD_FLAG` + world flag) and `RewardItem`s (material × 1–99, or one weapon/armor). Granted once per save by the command that commits the source; see "V0.5A salvage and preparation" | No (a new source *kind* needs code) |
| A new *kind* of effect / condition / trigger / modifier stat | Append the enum value, add the `match` branch and a test | Yes (small) |
| A new status (Chill, Blight) | `StatusDefinition` using the reserved enum value; tick/strenuous/interaction fields + traits | Only if the behaviour is new |

## 5. Runtime contracts

- **Input:** `BattleSetup` = `PartyLoadout` + enemies + conditions + advantage + `CombatLibrary`
  (balance, research, statuses, roles, resonances) + `TacticalDifficultyProfile` +
  `ExecutionAssistProfile` (already resolved with the player's overrides) + bestiary levels + `seed`.
- **Requests:** `ActionSelectRequest` (options with legality + reason + valid targets) →
  `submit_action(ActionChoice)`; `CommandRequest` (final `CommandSpec`) →
  `submit_command_result(grade)`; `ReactionRequest` (final `ReactionSpec`, every target) →
  `submit_reaction(ReactionResult)`. One reaction applies to every target of the action (D-008).
- **Events:** `BattleEvent` records (type, subject/other uids, amounts, status, grade, reaction, flags,
  action, text). Field usage per type is documented on the enum in
  `src/battle/runtime/battle_event.gd`. Presentation, metrics and the log only ever read events.
- **Presentation state (D-013):** the engine resolves a whole batch before it is shown, so while a
  batch plays every widget reads `PresentationLedger` (per-unit HP/Stagger/Focus/effects/cover/
  Broken/weak point/life, round, familiar readiness, announced battlefield conditions and the last
  stable next-round forecast), advanced by each event as it plays. Live engine state is read only at
  stable points (battle start, batch end, a pending request); a mid-batch event may refresh only what
  it names and only while the engine still holds that same state (e.g. INSPECTED re-reads that
  enemy's intent in the displayed round).
- **Output:** `BattleResult` = outcome, rounds, seed, research awards (enemy id → sources), weapon uses
  and Perfects (mastery), defeated enemy ids, and the input log (seed + inputs reproduce the battle).

V0.2 presentation adapters: `IntentReadout.target_names: Dictionary[int, String]` captures public
target identities with the displayed intent. ActionMenu previews delegate target policy to
ActionPicker. Inspector providers receive source-local pointer event coordinates. Keyboard target
review supplies its selected UnitView when no GUI control has focus. These are transient UI data,
not persisted battle state. See [the interaction contract](design/V02_UI_INTERACTION.md).
The [follow-up](design/V02_UI_FOLLOWUP.md) adds transient `UnitReadout`: public identity, role,
displayed HP/break/Focus/life/effects, filtered knowledge/affinity categories, notes and the
already-displayed intent reference. Mutable facts come from PresentationLedger; new research
queries are omitted outside stable planning. UnitView body providers exclude individual field
hit regions. InspectionContent reports its 82% transformed height to ScrollContainer. ConditionArt
reads announced condition IDs for decoration only. None of these data are saved or interpreted
as gameplay rules. Explicit target review is required even for one legal single-target recipient.
Third playtest: choosing another legal action or item during recipient review replaces the pending
option inside ActionPicker (recipients and preview rebuilt; the reviewed recipient kept when still
legal). A replacement without a recipient submits as from the menu. Unavailable rows, the pending
action itself, hovering and Details change nothing. The engine still receives exactly one
`ActionChoice` per request; nothing is spent before it.

## 6. Save and settings formats

**Save slot** (`user://saves/slot_N.json`, atomic temp-file + rename, D-011):

```json
{ "save_version": 1, "game_version": "0.3.0", "saved_at_unix": 1767225600, "slot": 0,
  "data": { "loadout": {"weapon", "garb", "charm", "relic", "companion", "familiar", "familiar_passive",
                        "potions"},
            "bestiary": {"points": {id: n}, "sources": {id: [source…]}},
            "weapon_mastery": {id: n},
            "inventory": {"equipment", "materials", "consumables", "quest_items"},
            "companions": {}, "familiars": [], "quests": {},
            "regions": {"pressure": {}, "events": {}}, "world_choices": {}, "home_upgrades": {},
            "stats": {"battles_won", "battles_lost"},
            "world": {"area", "anchor", "discovered": [id], "links": [id], "cleared": [id],
                      "flags": {"wayside_bell_restored": bool, "return_latch_open": bool},
                      "pending_entry": {…} | null, "last_applied_token", "entry_serial",
                      "gathered": [id], "found": [id], "solved": [id], "rune_input": {puzzle: [rune id…]}},
            "rewards": {"claims": [claim id…]},
            "crafting": {"recipes": [recipe id…], "fittings": {weapon id: fitting id}},
            "campaign": {"difficulty": 0|1|2, "starter": preset weapon id | ""},
            "combat": {"actions": [action id…]},
            "migrations": [migration id…] } }
```

**Playtest revision keys** (additive to save version 1; no `SaveMigrator` step, the application
stays 0.5.0). Four keys change meaning or are new; everything else is untouched.
- `inventory.consumables` (existed, always empty until now) is the finite supply stock: potion id →
  held doses, whole numbers 1–`PotionDefinition.MAX_STOCK` (99). `from_dict` drops zero, negative,
  fractional, boolean and non-numeric values and caps at 99; unknown potion ids are kept and inert.
- `migrations` (new, top level) lists one-time content migrations already applied to the save,
  unique and sorted; `from_dict` keeps strings only and a wrong-typed value is an empty list. Today
  it can hold `supplies.finite_stock.v1`. It lives outside `world`, so Reset journey keeps it.
- `quests` (existed, always empty until now) holds `first_footsteps.wayside_bell` → stage 0–3
  (`QuestRules.BellStage`). The stage is re-derived from `world` inside every write, so a saved value
  that disagrees with the world is corrected by the next write and is never trusted by a readout.
- `loadout.familiar_passive` (new) is the selected passive (trait id) of the travelling familiar;
  `""` or an id the familiar does not offer means its default passive.
- A captured `pending_entry.loadout` gains `"potion_charges": [n…]` (the supply allowance, one whole
  number per saved potion id: `min(per-encounter cap, held)` at capture) and `"familiar_passive"`.
  An entry captured before the revision has neither: it keeps the authored charges and settles no
  stock when it is won, and it uses the familiar's default passive.
- `crafting.recipes` keeps its shape. It now records crafted fittings (`Kind.FITTING` recipe ids) and
  an older save's fitting kit; potion recipe ids from older saves stay in the list, inert.

**Supply migration** (`SupplyRules.migrate`, applied by `WorldSession.reconcile()` at world entry and
when a journey is created; never by `from_dict`). A save without the `supplies.finite_stock.v1`
marker receives, in one write together with the marker: `starter_stock` doses of every potion that
authors it (Mending Draught 4, Fen Water Flask 4), and one brew's yield (2) of every other potion it
had access to under the old model (its Stillroom recipe id is in `crafting.recipes`, or the potion
is prepared in `loadout.potions`). Grants add to whatever the save already holds and cap at 99. The
marker is what prevents a second grant: a save whose stock later runs to zero is not topped up
again. A failed write changes nothing and the next world entry retries. An older build that
rewrites the save drops `migrations` (it does not know the key) but keeps `inventory.consumables`;
reopening it here would grant the starting stock once more on top. Downgrading is not supported.

**V0.5 UI campaign and combat sections** (optional, additive to save version 1; no migration step;
save version 1 stays compatible both ways for these keys). `campaign.difficulty` is the journey's
Tactical Difficulty (`Enums.TacticalDifficulty`) chosen at New Journey; absent or not a whole number
in range = `ADVENTURER` (1), the Settings default. `campaign.starter` records the New Journey preset
(a weapon id; `""` for older saves); it is informational, the saved loadout is the truth.
`combat.actions` is the Hollow's arranged action ids in combat-position order; absent or empty =
never arranged, so `CombatRules` derives the default (the first six granted actions: Actions in grid
order, then Magic). `from_dict` keeps unique non-empty strings; `CombatRules` keeps only actions the
equipped gear grants, within the unlocked capacity. A captured `EncounterEntry` stores the journey's
difficulty (no longer the Settings value at capture) and `loadout.actions` (the arrangement in battle
order); an entry captured before this pass has no `actions` and keeps every granted action, exactly
as it was captured. World entry (`WorldSession.reconcile`) rewrites an explicit arrangement only
when it is invalid for the gear or larger than the capacity (`CombatRules.repair`, one repair line).
`ProgressState.from_dict()` is now type-safe for every section: a wrong-typed section or field of a
valid-JSON save loads as its default (bestiary, mastery, companions, familiars, quests, regions,
choices, home upgrades, stats, entry serial, pending entry) instead of stopping the load.

**V0.5B crafting section** (optional, additive to save version 1; no migration step).
`crafting.recipes` lists the owned `RecipeDefinition` ids (unique, sorted): unlocks, never counts.
`crafting.fittings` maps a weapon id to its installed `ModificationDefinition` id. Both live outside
`world`, so Reset journey keeps them; a save without the section has none, and New Game starts
empty. `ProgressState.from_dict()` keeps string entries only (a non-list or non-dictionary falls
back to empty). Unknown recipe or fitting ids stay in the save and are inert: a fitting takes
effect only when `CraftingRules` finds its weapon's kit owned, the kit's mastery met and the id among
the kit's approved choices. Capacity is derived from the kit and saved weapon mastery; nothing else
is saved. A captured `EncounterEntry.loadout` gains `"modifications": [fitting id…]` (the fittings
resolved for its weapon at capture), so a retry never reads live unlocks; older entries without the
key have none. *(Superseded by the playtest revision: a fitting is owned per fitting, a potion
recipe is no longer an unlock, and an older save's prepared potion is grandfathered as stock by the
supply migration instead of as an unlocked recipe. See "Playtest revision keys" above.)*

**V0.5C exploration state** (inside the optional `world` section, additive; older saves have none).
`gathered` lists gathered GATHERING landmark ids; Reset journey keeps it (a node yields once per
save and never regrows). `found` (found SECRET landmark ids), `solved` (puzzle ids) and `rune_input`
(each unsolved puzzle's current attempt: rune landmark ids in strike order) are journey state and
reset. `WorldState.sanitize()` keeps only ids the world defines, and only a valid partial attempt of
a puzzle's own runes (shorter than its solution, never for a solved puzzle). Their rewards are
ordinary reward claims, so repeating a puzzle or secret after a reset grants nothing.

**V0.5A rewards section and inventory** (optional, additive to save version 1; no migration step).
`rewards.claims` lists the claimed `RewardDefinition` ids, unique and sorted. It lives outside
`world`, so Reset journey keeps it; a save without it (every V0.4 slot) has claimed nothing yet.
`inventory.materials` now holds real salvage (material id → whole count, 1–999) and
`inventory.equipment` real ownership. `ProgressState.from_dict()` never trusts these types: claims
and equipment keep string entries only (equipment de-duplicated, claims sorted); material counts
keep whole numbers ≥ 1, capped at `MaterialDefinition.MAX_COUNT` (999), and drop zero, negative,
fractional, boolean, NaN and non-numeric values; a wrong-typed `loadout`, `inventory` or `rewards`
section or loadout slot falls back to its default (a wrong-typed equipment or potion list keeps the
starter list). Unknown ids that are well-formed strings are kept: an unknown claim can only block
a grant that does not exist, and an unknown material or equipment id is never shown or equipped.
Deserializing never grants, repairs or writes anything; `WorldSession.reconcile()` does that at
world entry (see "V0.5A salvage and preparation"). An older build that rewrites a V0.5A save drops
`rewards` (it does not know the key); reopening that save here would re-grant the catch-up for
accomplishments still in its journey. Downgrading is not supported.

**V0.4 world section** (optional, additive to save version 1). A save without it (every V0.3 slot)
starts at `gloamstead/town_bell` with research, mastery, loadout and stats untouched; no migration
step is needed because no existing field changes meaning. Older builds ignore the key. On entry
`WorldState.sanitize()` validates every ID against `data/world/first_footsteps.tres`: an unknown
area/anchor recovers to the square, unknown landmark/link/site IDs are dropped, flags count only as
JSON `true`, and an incomplete or unapproved `pending_entry` is discarded. `pending_entry` is one
`EncounterEntry` = {token, site, encounter, area, approach_anchor, seed, loadout ids, research
levels, difficulty, assist, auto_brace, reaction_pause}; it is written before a world battle starts
and, if found on the next run, becomes the approach anchor with the encounter still available.
`last_applied_token` makes a repeated victory commit a no-op. Exploration writes happen only at
safe boundaries (area arrival, completed interaction, encounter entry, result commit, explicit save)
through `WorldSession.commit()`: copy → change → atomic write → adopt only on success.
**Reset journey** (third playtest, Menu → Reset journey, confirmed with Cancel as the default) is one
such commit: the candidate's `world` section becomes `WorldState.fresh()` (start area/anchor; no
discoveries, links, cleared sites, flags or pending entry) while `entry_serial` and
`last_applied_token` carry over, so completion tokens never repeat across a reset. Every other
section (loadout, bestiary, mastery, inventory, V0.5A reward claims, stats…) and the separate
settings file are kept, so a site cleared or a bell rung again after a reset grants no reward twice.
A failed write leaves the live journey unchanged. No format change; save version stays 1.

All references are content ids (strings); no node or Resource is serialized. Sections for later
milestones exist now (empty) so their arrival does not need a migration. To change the format: bump
`SaveMigrator.CURRENT_VERSION` and add one `_to_N` step; never edit a released step.
`game_version` is informational (`application/config/version`); only `save_version` drives migration,
so an application version bump never requires a save-version bump.

**Settings** (`user://settings.cfg`, global, not per slot, D-009; V0.5 UI: Tactical Difficulty is
also saved per journey in `campaign.difficulty`. Loading or starting a journey shows its difficulty
in Settings; changing it in Settings during the journey changes the journey at once, in the live
state, saved by the next commit; execution assist and every other setting stay per player): sections `gameplay`
(tactical_difficulty, execution_assist, auto_brace, reaction_pause), `display` (window_mode,
window_resolution (`Vector2i`, one of 1280×720 / 1366×768 / 1600×900 / 1920×1080 / 2560×1440),
screen_shake, reduce_flashing, reduce_motion, show_damage_numbers, advanced_tooltips, combat_speed,
auto_advance_text, subtitles), `audio` (master/music/sfx volume) and `bindings` (action → codes such as
`"key:Space"`, `"joy:0"`; missing actions use the defaults in `InputBindings.DEFAULTS`).
The CombatSandbox remembers its own form in `user://sandbox.cfg`.
The game uses one fixed 1280×720 canvas with 22 px body text; supported outputs scale it uniformly.
Window resizing and the independent font preference are retired. Old `display/text_scale` values
are ignored and removed on subsequent settings writes. See [fixed display policy](design/DISPLAY_PRESETS.md).
Absent/invalid window resolution falls back to 1280×720. GUI input mirrors replace their native
defaults. Enter/gamepad A confirm by default, Space/Z remain command inputs; saved explicit rebinds
remain authoritative. No progress-save format or migration changes are required.

**World definitions** (`data/world/*.tres`, loaded into `DefinitionRegistry.world`):
`WorldDefinition` {tile_size, start_area, start_anchor, areas, portals, flags} → `AreaDefinition`
{id, display_name, scene_path, size_tiles, default_anchor, extra_anchors, landmarks, paths,
music_cue (empty = intentional silence)} → `LandmarkDefinition` {id, public display_name, kind
(HOME/DIALOGUE/PREPARATION/PORTAL/LANDMARK/ENCOUNTER/RESTORATION/SHORTCUT/DISCOVERY, and V0.5C
GATHERING/SECRET/RUNE), planning
tile, public description, interact_radius, safe_anchor, encounter + threat_label + optional
(ENCOUNTER), far_side (SHORTCUT), discover_radius, service (V0.5 UI: PREPARATION only, `FORGE` = 1 or
`STILLROOM` = 2; every other kind `NONE`)} and `WorldPath` {id, tile points, width_tiles,
requires_flag}. `preparation_bench` (displayed "Forge") is the anvil (`FORGE`); `stillroom_table` is
the Stillroom (`STILLROOM`); both ids are stable. `PortalDefinition` pairs {from_area, from_landmark} with {to_area, arrival_anchor}.
V0.5C: `WorldDefinition` also holds `gathering: Array[GatheringDefinition]`, `secrets:
Array[SecretDefinition]` and `puzzles: Array[RuneSequenceDefinition]` (field reference below); each
GATHERING/SECRET/RUNE landmark has exactly one definition (`ExplorationRules.validate`).
Geometry lives in the area scene: `Interactions/<landmark id>` (WorldPoint), `Anchors/<anchor id>`
(Marker2D), `Portals/<landmark id>` (WorldPortal trigger rectangle), the painted `Collision`
TileMapLayer and `Solids`/footprint StaticBody2Ds on physics layer 2. Prop footprints are authored ground
shapes traced from the visible base (trunk and root flare, footings, plinths, posts), never
runtime sprite alpha; all willows share `scenes/world/footprints/willow_roots.tres`. Canopy and
other overhanging art stays walk-behind through the Y-sorted `DepthSorted` layer. `WorldStateView` nodes show
art and enable collision from one typed condition (a flag or a cleared site; V0.5C: `GATHERED` node,
`FOUND` secret, `SOLVED` puzzle, `RUNE_LIT` rune in the current attempt); they never write state.

## 7. Field reference

Generated from the Resource scripts in `src/data/` (field comments are the source of truth).

### BalanceConfig
`src/data/config/balance_config.gd`

Every global combat number in one designer-editable place. Damage previews, the live battle and the simulator all read from here, so a tuning change is reflected everywhere at once.

| Field | Type | Default | Notes |
|---|---|---|---|
| **Execution grades** | | | |
| `miss_multiplier` | `float` | `0.85` |  |
| `good_multiplier` | `float` | `1.0` |  |
| `perfect_multiplier` | `float` | `1.15` |  |
| `focus_on_good` | `int` | `1` | Focus for GOOD / PERFECT on actions flagged generates_focus (basic attacks). |
| `focus_on_perfect` | `int` | `2` |  |
| `focus_on_perfect_other` | `int` | `1` | Focus for PERFECT on other actions that have a command (techniques, magic). |
| **Damage** | | | |
| `guard_constant` | `float` | `100.0` | Final = raw * guard_constant / (guard_constant + Guard). |
| `damage_variance` | `float` | `0.05` | +/- fraction rolled on the battle RNG. Previews show the full range. |
| `weakness_multiplier` | `float` | `1.3` |  |
| `resistance_multiplier` | `float` | `0.7` |  |
| `weakness_focus` | `int` | `1` |  |
| `weakness_stagger_multiplier` | `float` | `1.5` |  |
| `broken_damage_taken_multiplier` | `float` | `1.5` |  |
| `weak_point_damage_multiplier` | `float` | `1.25` | Any hit against an exposed weak point. |
| `weak_point_precision_multiplier` | `float` | `1.4` | Extra multiplier for PRECISION-tagged hits against an exposed weak point (bows). |
| `weak_point_stagger_multiplier` | `float` | `1.5` |  |
| `interrupt_stagger_multiplier` | `float` | `1.75` | INTERRUPT-tagged hits against a channeling target. |
| `minimum_damage` | `int` | `1` |  |
| **Reactions** | | | |
| `brace_window_ms` | `float` | `520.0` | Total window widths (ms) at STANDARD assist. |
| `evade_window_ms` | `float` | `280.0` |  |
| `parry_window_ms` | `float` | `150.0` |  |
| `brace_damage_multiplier` | `float` | `0.6` |  |
| `evade_success_multiplier` | `float` | `0.0` |  |
| `evade_fail_multiplier` | `float` | `1.15` |  |
| `parry_success_multiplier` | `float` | `0.0` |  |
| `parry_fail_multiplier` | `float` | `1.3` |  |
| `parry_stagger` | `float` | `18.0` |  |
| `parry_focus` | `int` | `2` |  |
| **Focus** | | | |
| `party_starting_focus` | `int` | `2` |  |
| `enemy_starting_focus` | `int` | `0` |  |
| `enemy_focus_per_turn` | `int` | `1` |  |
| `break_focus` | `int` | `2` | To the unit whose hit breaks an enemy. |
| `interrupt_focus` | `int` | `1` | Additional Focus when the break cancels a channel (an interrupt). |
| **Stagger** | | | |
| `ambush_stagger_fraction` | `float` | `0.25` | Party ambush: every enemy starts with this fraction of its Stagger already removed. |
| **Party Break** (playtest revision; provisional) | | | |
| `party_max_break` | `float` | `40.0` | Break meter of the Hollow and of each companion, tracked per unit. 0 disables party Break. |
| `party_break_hit` | `float` | `8.0` | Break one damaging enemy action removes from a party target that did not react or whose reaction failed, unless the action authors `party_break`. |
| `party_break_brace_multiplier` | `float` | `0.5` | Share of the hit's Break a successful Brace still takes. |
| `party_break_evade_multiplier` | `float` | `0.0` | Share a successful Evade still takes (none). |
| `party_break_failed_multiplier` | `float` | `1.0` | Share an attempted, failed reaction takes. |
| `party_break_parry_cost` | `float` | `6.0` | Break a successful Parry costs the defender instead of the hit's Break: once per defending unit per resolved reaction, never per hit. |
| `party_break_turns` | `int` | `1` | Activations a Broken party member loses (at least 1). |
| **Default actions** | | | |
| `default_guard_action` | `ActionDefinition` | `` |  |
| `default_inspect_action` | `ActionDefinition` | `` |  |
| **Safety** | | | |
| `max_rounds` | `int` | `30` | Battles longer than this end as TIMEOUT (simulation guard). |
| `max_trigger_depth` | `int` | `4` | Trigger recursion limit (prevents infinite chains). |

### ResearchConfig
`src/data/config/research_config.gd`

Bestiary research: points per source and level thresholds. Research is earned by understanding (inspecting, exploiting, parrying signature moves), not only by kills.

| Field | Type | Default | Notes |
|---|---|---|---|
| **Points** | | | |
| `encounter_points` | `int` | `1` |  |
| `inspect_points` | `int` | `3` |  |
| `defeat_points` | `int` | `2` |  |
| `weakness_points` | `int` | `1` |  |
| `signature_parry_points` | `int` | `3` |  |
| `rare_ability_points` | `int` | `2` |  |
| `lore_points` | `int` | `3` |  |
| `quest_points` | `int` | `4` |  |
| **Thresholds** | | | |
| `observed_threshold` | `int` | `1` |  |
| `studied_threshold` | `int` | `5` |  |
| `understood_threshold` | `int` | `10` |  |
| `mastered_threshold` | `int` | `18` |  |
| **Battle** | | | |
| `inspect_reveal_level` | `Enums.ResearchLevel` | `Enums.ResearchLevel.UNDERSTOOD` | Inspecting an enemy reveals information at this level for the rest of the battle. |

### GameDefaults
`src/data/config/game_defaults.gd`

Starting choices that code would otherwise name by id: the new-game loadout, the fight a directly opened battle scene and a fresh CombatSandbox start with, and the loadouts the simulation CLI compares by default. Designers change them here (data/config/defaults.tres).

| Field | Type | Default | Notes |
|---|---|---|---|
| `starter_loadout` | `PartyLoadout` | `` | New games (and unknown saved ids) fall back to this loadout; its protagonist leads the party. |
| `practice_encounter` | `EncounterDefinition` | `` | The combat-toy fight: CombatSandbox default and the battle scene when opened on its own. |
| `simulation_loadouts` | `Array[PartyLoadout]` | `[]` | tools/simulate.gd compares these when no --loadout is given. |
| `journey_presets` | `Array[WeaponDefinition]` | `[]` | V0.5 UI New Journey starter presets, in order (preset id = weapon id). Each must be a weapon a fresh campaign owns; the rest of the starting loadout is the fresh campaign's (`JourneyRules.validate_catalog`). |

### TacticalDifficultyProfile
`src/data/config/tactical_difficulty_profile.gd`

Tactical Difficulty changes decision QUALITY, not numbers: which AI considerations are active (each consideration has a min_difficulty), how noisy choices are, and Story-mode courtesy rules. There is deliberately no enemy stat multiplier here (GDD: no inflated health bars).

| Field | Type | Default | Notes |
|---|---|---|---|
| `difficulty` | `Enums.TacticalDifficulty` | `Enums.TacticalDifficulty.ADVENTURER` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `score_variance` | `float` | `0.2` | Multiplicative noise on utility scores (+/-). Story is noisy, Tactician is sharp. |
| `avoid_lethal_combinations` | `bool` | `false` | Story: avoid stacking several likely-lethal attacks on one target in the same round. |
| `lethal_combination_weight` | `float` | `0.25` |  |
| `channel_extra_turns` | `int` | `0` | Story: dangerous channels take extra turns, giving more time to answer (same damage). |

### ExecutionAssistProfile
`src/data/config/execution_assist_profile.gd`

Execution Assist modifies timing windows, input-sequence speed, optional automatic Brace and an optional pause before reactions. It never changes enemy intelligence (that is Tactical Difficulty), and the two settings are independent and changeable at any time.

| Field | Type | Default | Notes |
|---|---|---|---|
| `assist` | `Enums.ExecutionAssist` | `Enums.ExecutionAssist.STANDARD` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `window_scale` | `float` | `1.0` | Multiplies every command and reaction window width. |
| `time_scale` | `float` | `1.0` | Multiplies indicator travel / beat intervals / wind-ups (> 1 = slower, easier to read). |
| `auto_brace` | `bool` | `false` | When the player gives no reaction input, a Brace succeeds automatically. |
| `pause_before_reaction` | `bool` | `false` | Show the incoming attack and wait for a key press before the real-time reaction sequence. |
| `minimum_grade` | `Enums.ExecutionGrade` | `Enums.ExecutionGrade.MISS` | Command results are raised to at least this grade. |

### ExecutionSkillProfile
`src/data/config/execution_skill_profile.gd`

A model of human execution for automated battles (GDD: simulated MISS / GOOD / PERFECT / MIXED). Probabilities are at STANDARD assist; ExecutionSimulator adjusts them for other assist windows.

| Field | Type | Default | Notes |
|---|---|---|---|
| `mode` | `Enums.SimulatedExecution` | `Enums.SimulatedExecution.GOOD` |  |
| `display_name` | `String` | `""` |  |
| **Action commands** | | | |
| `miss_weight` | `float` | `0.0` |  |
| `good_weight` | `float` | `1.0` |  |
| `perfect_weight` | `float` | `0.0` |  |
| **Reactions** | | | |
| `reacts` | `bool` | `true` | False models a player who never presses reaction keys. |
| `brace_success` | `float` | `0.95` |  |
| `evade_success` | `float` | `0.75` |  |
| `parry_success` | `float` | `0.4` |  |

### CombatantDefinition
`src/data/combatants/combatant_definition.gd`

Shared stat block for anything that takes part in battle.  Stats follow the GDD's short list: Heart (max_hp), Force, Guard, Tempo, Focus (capacity). Damage = raw * 100 / (100 + Guard); raw = power * (1 + Force / 100).

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| **Stats** | | | |
| `max_hp` | `int` | `100` | Heart. |
| `force` | `int` | `10` | Attack potency: +1% damage per point. |
| `guard` | `int` | `10` | Mitigation: damage * 100 / (100 + guard). |
| `tempo` | `int` | `10` | Initiative: higher acts earlier in the round. |
| `max_focus` | `int` | `10` | Focus capacity. |
| `starting_focus` | `int` | `-1` | Focus at battle start (-1 = BalanceConfig default for the unit's side). |
| `traits` | `Array[TraitDefinition]` | `[]` | Species mechanics / passives (owner = this unit). |
| **Visual** | | | |
| `shape` | `Enums.VisualShape` | `Enums.VisualShape.HUMANOID` |  |
| `color` | `Color` | `Color(0.7, 0.7, 0.75)` |  |
| `sprite_frames` | `SpriteFrames` | `` | Optional real art; placeholder silhouettes are drawn when absent. |
| `visual_scale` | `float` | `1.0` |  |

### ProtagonistDefinition (extends CombatantDefinition)
`src/data/combatants/protagonist_definition.gd`

The Hollow. Weapon actions come from the equipped weapon; magic and other innate actions here.

| Field | Type | Default | Notes |
|---|---|---|---|
| `innate_actions` | `Array[ActionDefinition]` | `[]` | Innate Magic/Techniques available regardless of weapon (e.g. elemental arts). |

### CompanionDefinition (extends CombatantDefinition)
`src/data/combatants/companion_definition.gd`

A recruitable companion: basic action, two core techniques, a passive identity. Relationship upgrades and the personal story arc are later milestones.

| Field | Type | Default | Notes |
|---|---|---|---|
| `basic_action` | `ActionDefinition` | `` |  |
| `techniques` | `Array[ActionDefinition]` | `[]` |  |
| `guard_action` | `ActionDefinition` | `` | Optional stance replacing the default Guard. |
| `weapon_family` | `Enums.WeaponFamily` | `Enums.WeaponFamily.NONE` | For conditions such as WEAPON_FAMILY_IS (companions wield a fixed weapon). |
| `weapon_damage_type` | `Enums.DamageType` | `Enums.DamageType.PIERCE` |  |
| `weapon_power` | `float` | `18.0` |  |
| `weapon_stagger` | `float` | `8.0` |  |
| `passive` | `TraitDefinition` | `` | Identity passive (owner = the companion). |
| `theme_statement` | `String` | `""` | How this character embodies a response to the central theme (writing guide, shown in codex). |

### EnemyDefinition (extends CombatantDefinition)
`src/data/combatants/enemy_definition.gd`

Enemy identity = species (stats, affinities, traits) + combat role (AI defaults) + biome interaction (traits / conditions). Adding an enemy is data + art, never new combat code.

| Field | Type | Default | Notes |
|---|---|---|---|
| `role` | `Enums.EnemyRole` | `Enums.EnemyRole.RAVAGER` |  |
| `tier` | `Enums.EnemyTier` | `Enums.EnemyTier.NORMAL` |  |
| `species` | `String` | `""` |  |
| `habitat` | `String` | `""` |  |
| `lore` | `String` | `""` |  |
| **Stagger** | | | |
| `max_stagger` | `float` | `30.0` |  |
| `break_turns` | `int` | `1` | Activations lost when Broken. |
| `stagger_growth_on_break` | `float` | `1.0` | Max Stagger multiplier applied after each break (bosses > 1 to prevent stun-locks). |
| `has_weak_point` | `bool` | `false` |  |
| `weak_point_name` | `String` | `""` |  |
| `expose_weak_point_on_break` | `bool` | `true` | Breaking exposes the weak point (if any) until the enemy recovers. |
| **Affinities** | | | |
| `weaknesses` | `Array[Enums.DamageType]` | `[]` |  |
| `resistances` | `Array[Enums.DamageType]` | `[]` |  |
| `status_immunities` | `Array[Enums.StatusId]` | `[]` |  |
| **Actions** | | | |
| `actions` | `Array[EnemyActionDefinition]` | `[]` |  |
| `phases` | `Array[BossPhaseDefinition]` | `[]` | Elites and bosses only. Order by descending hp_threshold. |
| **Research** | | | |
| `ai_tendencies` | `String` | `""` | Revealed at MASTERED in the bestiary and the intent "why" line. |
| `rare_interactions` | `String` | `""` | Revealed at MASTERED: unusual interactions worth knowing. |

### BossPhaseDefinition
`src/data/combatants/boss_phase_definition.gd`

A phase change for elites/bosses, entered once when HP falls to [member hp_threshold].  Phases let a boss "test every important system, but not simultaneously" (GDD roadmap).

| Field | Type | Default | Notes |
|---|---|---|---|
| `display_name` | `String` | `""` |  |
| `hp_threshold` | `float` | `0.5` | Enter when current HP fraction <= this value. |
| `announce_text` | `String` | `""` | Shown as a banner; should tell the player what changed. |
| `actions` | `Array[EnemyActionDefinition]` | `[]` | Replaces the action set when not empty. |
| `add_conditions` | `Array[BattlefieldConditionDefinition]` | `[]` |  |
| `remove_conditions` | `Array[BattlefieldConditionDefinition]` | `[]` |  |
| `on_enter_effects` | `Array[EffectDefinition]` | `[]` | Resolved with owner = the boss. |
| `opening_action` | `EnemyActionDefinition` | `` | If set, becomes the boss's next declared intent. |

### EnemyRoleDefinition
`src/data/combatants/enemy_role_definition.gd`

Reusable role logic (GDD: "Reuse role logic extensively").  Default considerations are merged into every action that expresses this role (the action's role_tags, or the enemy's role when the action has none), filtered by intent category.

| Field | Type | Default | Notes |
|---|---|---|---|
| `role` | `Enums.EnemyRole` | `Enums.EnemyRole.RAVAGER` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `default_considerations` | `Array[AIConsiderationDefinition]` | `[]` |  |

### FamiliarDefinition
`src/data/combatants/familiar_definition.gd`

A familiar never takes a turn: it reacts to triggers (GDD: on_perfect_parry, on_potion_used, on_status_applied, on_enemy_staggered, on_weakpoint_exposed…). Its trait is owned by the protagonist, so trigger relations are relative to the protagonist's side.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `playstyle` | `String` | `""` | The play style this familiar is meant to encourage (shown at the Menagerie and in tooltips). |
| `trait_def` | `TraitDefinition` | `` | The familiar's passive; with `passives` empty it is the one choice. |
| `passives` | `Array[TraitDefinition]` | `[]` | Playtest revision: the passives this familiar offers (at most `MAX_PASSIVES = 3`, unique ids), of which the player selects exactly one. Empty = the single legacy choice `trait_def`. `passive_choices()`, `default_passive()`, `passive(id)` and `resolved_passive(id)` (unknown or `&""` → the default) read them. |
| `shape` | `Enums.VisualShape` | `Enums.VisualShape.FLYER` |  |
| `color` | `Color` | `Color(0.6, 0.6, 0.7)` |  |
| `portrait` | `Texture2D` | Null | Optional familiar art/AtlasTexture; no combat targeting. |
| `display_scale` | `float` | `1.0` | Positive presentation scale over the 52×58 familiar slot; Cinder Pup uses 1.2. |

### ActionDefinition
`src/data/combat/action_definition.gd`

Anything a unit can do on its activation: attacks, techniques, magic, stances, items, inspect.  Resolved by ActionResolver for players and enemies alike. Damage happens when [member power] > 0 or [member uses_weapon_power] is set; effects then resolve top to bottom.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` | Immediate-layer tooltip text. |
| `details` | `String` | `""` | Extra analysis-layer text (formulas are generated automatically; this is for nuance). |
| `category` | `Enums.ActionCategory` | `Enums.ActionCategory.ATTACK` |  |
| `target_rule` | `Enums.TargetRule` | `Enums.TargetRule.SINGLE_ENEMY` |  |
| `focus_cost` | `int` | `0` |  |
| `cooldown` | `int` | `0` | Activations of the user before it can be used again (0 = none). |
| **Damage** | | | |
| `damage_type` | `Enums.DamageType` | `Enums.DamageType.NONE` | NONE with uses_weapon_power = use the wielded weapon's damage type. |
| `power` | `float` | `0.0` |  |
| `uses_weapon_power` | `bool` | `false` | Scale off the wielded weapon instead of `power` (weapon techniques). |
| `weapon_power_multiplier` | `float` | `1.0` |  |
| `stagger` | `float` | `0.0` |  |
| `uses_weapon_stagger` | `bool` | `false` |  |
| `weapon_stagger_multiplier` | `float` | `1.0` |  |
| **Rules** | | | |
| `generates_focus` | `bool` | `false` | Basic attacks: GOOD grants Focus, PERFECT grants more (BalanceConfig). |
| `tags` | `Array[Enums.ActionTag]` | `[]` |  |
| `effects` | `Array[EffectDefinition]` | `[]` |  |
| `command` | `ActionCommandDefinition` | `` | Null = no action command (always resolves at GOOD). |
| **Presentation** | | | |
| `glyph` | `String` | `""` | Short label for menus and the timeline (color-independent). |
| `color` | `Color` | `Color(0.85, 0.85, 0.9)` |  |

### ActionCommandDefinition
`src/data/combat/action_command_definition.gd`

Parameters for one of the four reusable action-command components.  Never write a bespoke minigame: every weapon/ability parameterises one of these. Final values seen by the player are produced by CommandRules (equipment modifiers + Execution Assist), so these are the STANDARD-assist baseline numbers.  Window widths are the TOTAL width of the zone in milliseconds, centred on the target moment (GDD tooltip example: "Good: 420 ms, Perfect: 115 ms").

| Field | Type | Default | Notes |
|---|---|---|---|
| `type` | `Enums.ActionCommandType` | `Enums.ActionCommandType.TIMING` |  |
| `duration_ms` | `float` | `1000.0` | TIMING: indicator travel time. HOLD_RELEASE: gauge fill time. OPTIONAL_AIM: reticle sweep time. |
| `target_position` | `float` | `0.75` | Where the sweet spot sits along the travel (0..1). |
| `good_window_ms` | `float` | `320.0` |  |
| `perfect_window_ms` | `float` | `100.0` |  |
| `beat_count` | `int` | `3` | RHYTHM: 2–4 beats (GDD maximum is four). |
| `beat_interval_ms` | `float` | `420.0` |  |
| `lead_in_ms` | `float` | `450.0` | Pause before the indicator / first beat starts moving, so the player can read it. |

### EnemyActionDefinition (extends ActionDefinition)
`src/data/combat/enemy_action_definition.gd`

An enemy ability: an ActionDefinition plus utility-AI data, telegraph data and reaction rules.  GDD contract: base_priority, resource_cost (= focus_cost), cooldown, target_rules (= target_rule), conditions (= use_conditions), role_tags, synergy_tags, can_brace/can_evade/can_parry.

| Field | Type | Default | Notes |
|---|---|---|---|
| **AI** | | | |
| `base_priority` | `float` | `1.0` |  |
| `max_uses` | `int` | `0` | 0 = unlimited uses per battle. |
| `use_conditions` | `Array[ConditionDefinition]` | `[]` | All must pass for the action to be legal (actor = the enemy). |
| `role_tags` | `Array[Enums.EnemyRole]` | `[]` | Role behaviours this action expresses; empty = the enemy's own role. Role default considerations are merged in from EnemyRoleDefinition. |
| `synergy_setup` | `Array[Enums.SynergyTag]` | `[]` | Combo vocabulary: setups create opportunities that allies' payoffs exploit. |
| `synergy_payoff` | `Array[Enums.SynergyTag]` | `[]` |  |
| `considerations` | `Array[AIConsiderationDefinition]` | `[]` |  |
| **Telegraph** | | | |
| `intent_category` | `Enums.IntentCategory` | `Enums.IntentCategory.ATTACK` |  |
| `channel_turns` | `int` | `0` | Activations spent channeling before release (0 = immediate). Shown as an hourglass. |
| `interruptible` | `bool` | `true` | Breaking Stagger cancels the channel. |
| `telegraph_text` | `String` | `""` | Always-visible flavour of the intent, e.g. "Preparing a heavy strike." |
| `telegraph_detail` | `String` | `""` | Revealed at research level UNDERSTOOD, e.g. "Parries easily after the second flash." |
| `signature` | `bool` | `false` | Parrying a signature move awards research. |
| `rare` | `bool` | `false` | Observing a rare move awards research. |
| **Reactions** | | | |
| `can_brace` | `bool` | `true` |  |
| `can_evade` | `bool` | `true` |  |
| `can_parry` | `bool` | `true` |  |
| `windup_ms` | `float` | `900.0` | Wind-up animation length before impact (presentation; reaction timing centres on impact). |
| `reaction_window_scale` | `float` | `1.0` | Scales all reaction windows for this move (fast jabs < 1, slow slams > 1). |
| `party_break` | `float` | `-1.0` | Playtest revision: Break this action removes from a party target that does not react (`-1` = `BalanceConfig.party_break_hit`). Only a damaging action deals it. No authored action sets it yet. |

### AIConsiderationDefinition
`src/data/combat/ai_consideration_definition.gd`

One utility-AI factor. When the test holds, the action/target score is multiplied by [member weight]; otherwise by [member else_weight].  [member min_difficulty] gates the factor: the same data makes Tactician enemies smarter instead of inflated (GDD "Harder AI should feel smarter, not merely inflated").

| Field | Type | Default | Notes |
|---|---|---|---|
| `type` | `Enums.ConsiderationType` | `Enums.ConsiderationType.TARGET_HP_BELOW` |  |
| `min_difficulty` | `Enums.TacticalDifficulty` | `Enums.TacticalDifficulty.STORY` |  |
| `weight` | `float` | `1.5` |  |
| `else_weight` | `float` | `1.0` |  |
| `threshold` | `float` | `0.5` | HP fraction, Focus amount or round number depending on `type`. |
| `status` | `Enums.StatusId` | `Enums.StatusId.NONE` |  |
| `role` | `Enums.EnemyRole` | `Enums.EnemyRole.MENDICANT` |  |
| `battlefield_condition` | `BattlefieldConditionDefinition` | `` |  |
| `applies_to` | `Array[Enums.IntentCategory]` | `[]` | Role defaults only: restrict to these intent categories (empty = all actions). |
| `reason` | `String` | `""` | Short explanation shown in the intent's "why" line, e.g. "Ally badly hurt". |

### StatusDefinition
`src/data/combat/status_definition.gd`

Behaviour of one of the six statuses. Core mechanics are typed fields interpreted by StatusRules; anything unusual is expressed with [member traits] (active while present).

| Field | Type | Default | Notes |
|---|---|---|---|
| `status` | `Enums.StatusId` | `Enums.StatusId.NONE` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` | Immediate-layer text (always available in tooltips). |
| `details` | `String` | `""` |  |
| `glyph` | `String` | `""` | Color-independent label (GDD: "color-independent status icons"). |
| `color` | `Color` | `Color.WHITE` |  |
| `is_negative` | `bool` | `true` |  |
| **Duration** | | | |
| `duration_mode` | `Enums.DurationMode` | `Enums.DurationMode.TURNS` |  |
| `default_duration` | `int` | `3` | Turns (TURNS) or charges (CHARGES) when an application does not specify one. |
| `max_duration` | `int` | `6` |  |
| `max_stacks` | `int` | `3` |  |
| `expiry_turns` | `int` | `0` | CHARGES mode: also expires after this many bearer turns (0 = never), so it cannot sit forever. |
| **Damage** | | | |
| `tick_timing` | `Enums.TickTiming` | `Enums.TickTiming.NONE` |  |
| `tick_damage_per_stack` | `float` | `0.0` | PURE damage per stack when it ticks (Burn). |
| `strenuous_damage_per_stack` | `float` | `0.0` | PURE damage per stack each time the bearer performs a STRENUOUS action (Bleed). |
| **Interactions** | | | |
| `removes_on_apply` | `Array[Enums.StatusId]` | `[]` | Applying this status removes these from the bearer (Wet removes Burn). |
| `blocked_by` | `Array[Enums.StatusId]` | `[]` | If the bearer has one of these, this application fails and that status is consumed (Burn on a Wet target is doused). |
| `traits` | `Array[TraitDefinition]` | `[]` | Rules active on the bearer while the status is present (owner = bearer). |

### BattlefieldConditionDefinition
`src/data/combat/battlefield_condition_definition.gd`

An environment rule. Usually one MAJOR and optionally one MINOR per battle.  [member description] is always shown in the condition panel: the player should never wonder why a mechanic changed. Behaviour is entirely in [member traits] (owner = none).

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `severity` | `Enums.ConditionSeverity` | `Enums.ConditionSeverity.MAJOR` |  |
| `description` | `String` | `""` |  |
| `details` | `String` | `""` |  |
| `glyph` | `String` | `""` |  |
| `tint` | `Color` | `Color(0.4, 0.6, 0.9, 0.25)` |  |
| `traits` | `Array[TraitDefinition]` | `[]` |  |

### WeaponDefinition
`src/data/items/weapon_definition.gd`

A horizontal choice, not a stat tier. The family defines the action-command language; the individual weapon modifies it through traits (timing windows, statuses, Focus, Stagger, reactions, environment). Rarity means mechanical complexity, never large raw-stat jumps.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `details` | `String` | `""` |  |
| `family` | `Enums.WeaponFamily` | `Enums.WeaponFamily.SWORD` |  |
| `rarity` | `Enums.Rarity` | `Enums.Rarity.COMMON` |  |
| `damage_type` | `Enums.DamageType` | `Enums.DamageType.SLASH` |  |
| **Numbers** | | | |
| `base_power` | `float` | `20.0` |  |
| `base_stagger` | `float` | `8.0` |  |
| `tempo_modifier` | `int` | `0` | Added to the wielder's Tempo (hammers are slow). |
| **Actions** | | | |
| `basic_attack` | `ActionDefinition` | `` |  |
| `techniques` | `Array[ActionDefinition]` | `[]` |  |
| `guard_action` | `ActionDefinition` | `` | Optional stance replacing the default Guard. |
| **Identity** | | | |
| `traits` | `Array[TraitDefinition]` | `[]` | COMMON: one identity mechanic. UNCOMMON: + socket. RARE: + socket or alternative action. RELIC: a unique rule-changing effect. |
| `resonance_tags` | `Array[Enums.ResonanceTag]` | `[]` |  |
| `socket_count` | `int` | `0` | Modification sockets (Forge milestone; stored now so saves stay compatible). |

Optional `icon: Texture2D` defaults to null; the character menu and loot readouts use it only for presentation.

### ArmorDefinition
`src/data/items/armor_definition.gd`

Garb, Charm or Relic. Mostly supplies rules ("Brace generates Focus"), not stat padding.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `details` | `String` | `""` |  |
| `slot` | `Enums.EquipSlot` | `Enums.EquipSlot.GARB` |  |
| `rarity` | `Enums.Rarity` | `Enums.Rarity.COMMON` |  |
| `traits` | `Array[TraitDefinition]` | `[]` |  |
| `granted_actions` | `Array[ActionDefinition]` | `[]` | Actions this item teaches while equipped (e.g. a charm granting a spell). |
| `resonance_tags` | `Array[Enums.ResonanceTag]` | `[]` |  |

Optional `icon: Texture2D` defaults to null; the character menu and loot readouts use it only for presentation.

### ResonanceDefinition
`src/data/items/resonance_definition.gd`

A two-item synergy. Active when at least two equipped items (weapon, garb, charm, relic) share [member tag]. The GDD forbids benefits that require more than two items or full sets.

| Field | Type | Default | Notes |
|---|---|---|---|
| `tag` | `Enums.ResonanceTag` | `Enums.ResonanceTag.NONE` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `trait_def` | `TraitDefinition` | `` |  |

### PotionDefinition
`src/data/items/potion_definition.gd`

A brewed combat consumable carried in one of the potion slots. Using it is an ITEM action. Playtest
revision: campaign supplies are finite. A save holds a stock of doses per potion
(`inventory.consumables`, at most `MAX_STOCK = 99`); a prepared position carries
`min(charges, held)` doses into an encounter, and only a saved victory removes the doses that battle
actually used. Practice, the Lab and static loadouts never read the stock and keep `charges`.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `icon` | `Texture2D` | `` | Optional supply icon; readouts expose its resource path. |
| `action` | `ActionDefinition` | `` | Category must be ITEM. Targets and effects live here. |
| `charges` | `int` | `1` | The per-encounter cap: the most doses one prepared position carries into an encounter. |
| `starter_stock` | `int` | `0` | Doses a new journey starts with, and an older save receives once (0–99). Only starter-loadout potions may author it. Mending Draught and Fen Water Flask: 4. |

### TraitDefinition
`src/data/rules/trait_definition.gd`

A named package of rules: continuous modifiers plus triggered effects.  The single building block for weapon identities, equipment properties, resonance synergies, companion passives, familiars, status behaviour, battlefield conditions and species mechanics (DECISION_LOG D-004).

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` | Simple tooltip text (immediate layer). |
| `details` | `String` | `""` | Analysis-layer text shown while holding the info key. Optional. |
| `modifiers` | `Array[ModifierDefinition]` | `[]` |  |
| `triggers` | `Array[TriggeredEffectDefinition]` | `[]` |  |

### ModifierDefinition
`src/data/rules/modifier_definition.gd`

A continuous change to a number while its trait is active.  Result of a query = (base + sum of ADD values) * product of MULTIPLY values, considering only modifiers whose conditions pass for the query (see ModifierQuery).

| Field | Type | Default | Notes |
|---|---|---|---|
| `stat` | `Enums.ModifierStat` | `Enums.ModifierStat.DAMAGE_DEALT` |  |
| `operation` | `Enums.ModifierOp` | `Enums.ModifierOp.MULTIPLY` |  |
| `value` | `float` | `1.0` | For MULTIPLY: 1.2 = +20%. For ADD: flat amount in the stat's own units. |
| `conditions` | `Array[ConditionDefinition]` | `[]` | All must pass (evaluated with the query's actor/target, e.g. attacker/defender). |

### TriggeredEffectDefinition
`src/data/rules/triggered_effect_definition.gd`

"When <trigger> happens to a unit related to my owner, and <conditions>, do <effects>."  Familiars, weapon identities, equipment rules, statuses and battlefield conditions all use this. [member watch] picks the event role (actor or target) whose relation to the trait owner is checked against [member relation]. Battlefield traits have no owner: use relation ANY.

| Field | Type | Default | Notes |
|---|---|---|---|
| `trigger` | `Enums.TriggerType` | `Enums.TriggerType.HIT_LANDED` |  |
| `watch` | `Enums.TriggerWatch` | `Enums.TriggerWatch.ACTOR` |  |
| `relation` | `Enums.TriggerRelation` | `Enums.TriggerRelation.OWNER` |  |
| `conditions` | `Array[ConditionDefinition]` | `[]` |  |
| `effects` | `Array[EffectDefinition]` | `[]` |  |
| `chance` | `float` | `1.0` |  |
| `max_per_round` | `int` | `0` | 0 = unlimited. |
| `max_per_battle` | `int` | `0` | 0 = unlimited. |
| `announce` | `bool` | `true` | Show the owning trait's name when this fires (audiovisual feedback for every mechanic). |

### EffectDefinition
`src/data/rules/effect_definition.gd`

One thing that happens: damage, healing, Focus, Stagger, statuses, buffs, battlefield changes…  Interpreted by EffectResolver. Effects on an action resolve top to bottom after the action's hit; each effect's [member conditions] are checked at the moment it resolves. Within an action, DAMAGE / HEAL / STAGGER_DAMAGE amounts scale with the execution grade.

| Field | Type | Default | Notes |
|---|---|---|---|
| `type` | `Enums.EffectType` | `Enums.EffectType.DAMAGE` |  |
| `target` | `Enums.EffectTarget` | `Enums.EffectTarget.TARGET` | Who receives the effect. In an action: OWNER/ACTOR = the user, TARGET = each target. |
| `amount` | `float` | `0.0` | Damage/heal/Focus/Stagger amount, status stacks (APPLY/CHAIN) or extension (EXTEND). |
| `scaling` | `Enums.AmountScaling` | `Enums.AmountScaling.FLAT` |  |
| `damage_type` | `Enums.DamageType` | `Enums.DamageType.PURE` |  |
| `status` | `Enums.StatusId` | `Enums.StatusId.NONE` |  |
| `duration` | `int` | `0` | Status turns (0 = status default) or weak-point exposure rounds. |
| `filter_status` | `Enums.StatusId` | `Enums.StatusId.NONE` | CHAIN_STATUS only spreads to units that currently have this status. |
| `buff` | `BuffDefinition` | `` |  |
| `battlefield_condition` | `BattlefieldConditionDefinition` | `` |  |
| `conditions` | `Array[ConditionDefinition]` | `[]` | All must pass for this effect to resolve. |
| `chance` | `float` | `1.0` | Deterministic chance (battle RNG). |

### ConditionDefinition
`src/data/rules/condition_definition.gd`

One boolean test, evaluated by ConditionEvaluator against a RuleContext.  Used by triggered effects, conditional modifiers, effect gates and enemy action legality. Only the fields relevant to [member type] are shown in the inspector.

| Field | Type | Default | Notes |
|---|---|---|---|
| `type` | `Enums.ConditionType` | `Enums.ConditionType.ALWAYS` |  |
| `negate` | `bool` | `false` | Invert the result of the test. |
| `on` | `Enums.ConditionOn` | `Enums.ConditionOn.TARGET` | Which unit a unit-based test inspects (trait owner, event actor or event target). |
| `grade` | `Enums.ExecutionGrade` | `Enums.ExecutionGrade.PERFECT` |  |
| `reaction` | `Enums.ReactionType` | `Enums.ReactionType.PARRY` |  |
| `status` | `Enums.StatusId` | `Enums.StatusId.NONE` |  |
| `category` | `Enums.ActionCategory` | `Enums.ActionCategory.ATTACK` |  |
| `tag` | `Enums.ActionTag` | `Enums.ActionTag.STRENUOUS` |  |
| `family` | `Enums.WeaponFamily` | `Enums.WeaponFamily.NONE` |  |
| `damage_type` | `Enums.DamageType` | `Enums.DamageType.NONE` |  |
| `threshold` | `float` | `0.5` | HP fraction for HP_BELOW / HP_ABOVE. |
| `round_number` | `int` | `1` |  |
| `side` | `Enums.Side` | `Enums.Side.PLAYER` |  |
| `battlefield_condition` | `BattlefieldConditionDefinition` | `` |  |
| `buff` | `BuffDefinition` | `` |  |

### BuffDefinition
`src/data/rules/buff_definition.gd`

A temporary trait placed on a unit: stances, empowerments, marks and debuffs.  Granted by EffectType.GRANT_BUFF. Re-granting an active buff refreshes it (no stacking).

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `glyph` | `String` | `""` | Short color-independent label for the HUD. |
| `is_debuff` | `bool` | `false` |  |
| `is_guard_stance` | `bool` | `false` | Marks the unit as guarding (AI sees this; HUD shows a shield). |
| `expiry` | `Enums.BuffExpiry` | `Enums.BuffExpiry.OWNER_TURN_START` |  |
| `duration` | `int` | `1` | Number of expiry events before removal (NEXT_ACTION: number of qualifying actions). |
| `consume_conditions` | `Array[ConditionDefinition]` | `[]` | NEXT_ACTION buffs are consumed only by an owner action passing all of these. |
| `trait_def` | `TraitDefinition` | `` | Rules active while the buff lasts. |

### EncounterDefinition
`src/data/encounters/encounter_definition.gd`

A designed fight: enemies + battlefield conditions + optional pre-combat advantage. Used by the CombatSandbox, the simulator and (later) visible overworld enemy groups.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `group` | `String` | `""` | Sandbox grouping label ("Toy", "Briarfen", "Elite", "Boss"…). |
| `enemies` | `Array[EnemyDefinition]` | `[]` |  |
| `conditions` | `Array[BattlefieldConditionDefinition]` | `[]` | At most one MAJOR and one MINOR condition. |
| `advantage` | `Enums.Advantage` | `Enums.Advantage.NONE` |  |

### PartyLoadout
`src/data/encounters/party_loadout.gd`

What the party brings into battle: chosen at home (GDD core loop) or in the CombatSandbox.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `protagonist` | `ProtagonistDefinition` | `` |  |
| `weapon` | `WeaponDefinition` | `` |  |
| `garb` | `ArmorDefinition` | `` |  |
| `charm` | `ArmorDefinition` | `` |  |
| `relic` | `ArmorDefinition` | `` |  |
| `companion` | `CompanionDefinition` | `` | Null = protagonist fights alone (combat toy). |
| `familiar` | `FamiliarDefinition` | `` |  |
| `potions` | `Array[PotionDefinition]` | `[]` |  |
| `modifications` | `Array[ModificationDefinition]` | `[]` | V0.5B fittings resolved for `weapon`; `from_ids` reads an entry's `"modifications"` ids. Practice and the Lab leave it empty. |
| `action_ids` | `Array[StringName]` | `[]` | V0.5 UI: the Hollow's arranged action ids in battle order (`from_ids` reads `"actions"`). Empty = every granted action in grid order (Practice, the Lab, static loadouts, older entries). |
| `potion_charges` | `Array[int]` | `[]` | Playtest revision: the supply allowance, one entry per potion in `potions` (`from_ids` reads `"potion_charges"`, each clamped to 0–`charges`). Empty = every potion's authored `charges` (Practice, the Lab, static loadouts, older entries). `charges_for(index)` reads it. |
| `familiar_passive` | `TraitDefinition` | `` | Playtest revision: the familiar's selected passive (`from_ids` reads `"familiar_passive"`). Null = the familiar's default. `familiar_trait()` is what the battle uses. |

Constants: `MAX_POTION_SLOTS = 2`; `MAX_ACTIONS = 8` (V0.5A home of the eight-slot rule; the
battle grid's `ActionMenu.CAPACITY` uses it). `UnitFactory.granted_actions(loadout, balance)` lists
every action the gear grants (basic, techniques, innate, armor-granted, stance or Guard, Inspect; no
duplicates; held to `MAX_ACTIONS` by the equipment checks). `protagonist_actions(loadout, balance)`
is what the protagonist gets in battle: with `action_ids`, the granted ones in that order (never
more than `MAX_ACTIONS`); without, every granted action. `companion_actions(definition, balance)`
is unchanged (companions are not arranged).

### MaterialDefinition
`src/data/items/material_definition.gd` (V0.5A)

A salvage material, counted per save in `inventory.materials`. Public item facts only. Saved stacks
saturate at `MAX_COUNT = 999`; the catalog check keeps all authored grants of one material below it.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` | Required, public. |
| `icon` | `Texture2D` | `` | Optional; readouts expose its resource path. |
| `listed` | `bool` | `true` | Playtest revision: shown in the public ingredient catalog (Inventory, Stillroom, Forge) even at a count of zero. False hides it from the catalog; it is still counted and spent. |
| `sort_order` | `int` | `0` | Catalog order: lower first, then by id. |

### RewardDefinition
`src/data/progression/reward_definition.gd` (V0.5A)

One stable campaign reward. `id` is the persistent claim id (lowercase dotted words, ≤ 64 chars,
e.g. `first_footsteps.patrol`): a save receives it once, in the write that commits its source, and
Reset journey keeps the claim. Quantities are provisional slice data.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` | Claim id. |
| `display_name` | `String` | `""` | Public label ("Patrol salvage"); never an encounter or species name. |
| `source` | `RewardDefinition.Source` | `SITE_VICTORY` | `SITE_VICTORY = 0` (first committed victory at an encounter landmark), `WORLD_FLAG = 1` (the action that sets a world flag); V0.5C `GATHERED = 2`, `SECRET_FOUND = 3`, `PUZZLE_SOLVED = 4`. |
| `source_id` | `StringName` | `&""` | Encounter landmark id, a `WorldDefinition.flags` id, a GATHERING or SECRET landmark id, or a puzzle id. |
| `items` | `Array[RewardItem]` | `[]` | No item twice; may be empty when equipment slots are granted. |
| `equipment_slots` | `int` | `0` | Permanent equipment bag expansion through this claim; 0–50, multiple of five. |

### RewardItem
`src/data/progression/reward_item.gd` (V0.5A)

| Field | Type | Default | Notes |
|---|---|---|---|
| `kind` | `RewardItem.Kind` | `MATERIAL` | `MATERIAL = 0` or `EQUIPMENT = 1`. Consumables are not reward kinds. |
| `material` | `MaterialDefinition` | `` | MATERIAL only; must be the registered `data/materials` definition. |
| `equipment` | `Resource` | `` | EQUIPMENT only: a registered `WeaponDefinition` or `ArmorDefinition`. Never duplicated when already owned. |
| `count` | `int` | `1` | MATERIAL: 1–99. EQUIPMENT: exactly 1. |

Catalog checks (`RewardRules.validate_catalog`, run by `DefinitionRegistry.validate()` and the
content test): duplicate claim ids, id format, empty or null items, kinds, counts, registered
material/equipment references (not copies), sources (an ENCOUNTER landmark, a world flag, or a
V0.5C gathering node, secret or puzzle of `registry.world`), and each material's authored total ≤ 999.

### MaterialCost
`src/data/crafting/material_cost.gd` (V0.5B)

| Field | Type | Default | Notes |
|---|---|---|---|
| `material` | `MaterialDefinition` | `` | Must be the registered `data/materials` definition. |
| `count` | `int` | `1` | 1–99. Spent whole on purchase; a refundable recipe returns exactly this. |

### RecipeDefinition
`src/data/crafting/recipe_definition.gd` (V0.5B)

A home-station recipe. Playtest revision: a `FITTING` recipe crafts one fitting once (ownership is
saved by `id`), a `POTION` recipe is brewed any number of times into finite stock (nothing is saved
by `id`), and the older `FITTING_KIT` can no longer be bought (a save that owns one keeps every
fitting it offered and may still refund it).

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` | Lowercase dotted words (`forge.first_fitting`). |
| `display_name`, `description` | `String` | `""` | Public, required. |
| `station` | `RecipeDefinition.Station` | `FORGE` | `FORGE = 0`, `STILLROOM = 1` (grouping/labels; the bench hosts both). |
| `kind` | `RecipeDefinition.Kind` | `FITTING_KIT` | `FITTING_KIT = 0` (legacy: retired from purchase, still refundable when owned), `POTION = 1` (brews `yield_count` doses of `potion`), `FITTING = 2` (crafts the one fitting in `fittings` for `weapon`). |
| `costs` | `Array[MaterialCost]` | `[]` | The whole price, spent in the write that brews or crafts; non-empty, no material twice. For POTION, the Reagent. |
| `refundable` | `bool` | `false` | FITTING_KIT only. A crafted fitting and a brew are not refundable. |
| `mastery_points` | `int` | `0` | Crafting or brewing needs this many saved points on any one owned weapon in `mastery_weapons`. |
| `mastery_weapons` | `Array[WeaponDefinition]` | `[]` | Required when `mastery_points > 0`. |
| `weapon` | `WeaponDefinition` | `` | FITTING_KIT and FITTING. |
| `fittings` | `Array[ModificationDefinition]` | `[]` | FITTING_KIT: non-empty, unique. FITTING: exactly one. |
| `potion` | `PotionDefinition` | `` | POTION only. Every campaign potion, starters included, has one brew recipe. |
| `yield_count` | `int` | `1` | POTION only: doses one brew adds to the stock (1–`MAX_YIELD = 20`). Every authored recipe yields 2. |
| `base_name`, `base_description` | `String` | `""` | POTION only: the public Base (a reusable home supply, never a saved stack or hidden cost). No Catalyst in V0.5B. |

### ModificationDefinition
`src/data/crafting/modification_definition.gd` (V0.5B)

A weapon fitting: a stable saved id reusing one complete authored trait by reference.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` | Lowercase dotted words (`fitting.merciful_grip`); saved and captured. |
| `display_name`, `description` | `String` | `""` | Public, required. |
| `trait_source` | `Resource` | `` | The registered weapon or armor authoring the trait (never granted or edited). |
| `trait_id` | `StringName` | `&""` | Must resolve in `trait_source.traits`; `resolved_trait()` returns that shared resource. |

Catalog checks (`CraftingRules.validate_catalog`): registered materials, mastery weapons, kit weapons,
fittings, potions and trait sources; one kit per weapon; one recipe per potion; no recipe for a free
starter; every fitting offered by a kit; and the V0.5B economy invariant: all recipes together cost
no more of each material than the authored rewards grant, so any purchase order can buy everything.

### GatheringDefinition, SecretDefinition, RuneSequenceDefinition
`src/world/exploration/*.gd` (V0.5C), held by `WorldDefinition`.

| Definition | Field | Type | Notes |
|---|---|---|---|
| Gathering | `landmark` | `StringName` | A GATHERING landmark. Its yield is a `GATHERED` RewardDefinition (source_id = landmark id). |
| Gathering | `refresh` | `GatheringDefinition.Refresh` | `ONCE_PER_SAVE = 0` (the only policy: no clock, no regrowth, kept by Reset journey). |
| Secret | `landmark` | `StringName` | A SECRET landmark: no prompt, discovery or map entry until revealed. Reward source `SECRET_FOUND`. |
| Secret | `reveal`, `reveal_key` | `SecretDefinition.Reveal`, `StringName` | `ALWAYS = 0` (no key), `PUZZLE_SOLVED = 1` (a puzzle id), `WORLD_FLAG = 2` (a world flag). |
| Rune sequence | `id`, `display_name` | `StringName`, `String` | Stable puzzle id (saved; reward source_id of `PUZZLE_SOLVED`) and public name. |
| Rune sequence | `runes` | `Array[StringName]` | ≥ 2 RUNE landmarks, all in one area, each in one puzzle. |
| Rune sequence | `solution` | `Array[StringName]` | 2–8 strikes of its own runes (repeats allowed). Never shown by a readout. |

## V0.2 support presentation additions (transient)

See [support presentation](design/V02_SUPPORT_PRESENTATION.md). ActionReadout.support_effects is an
array of RuleNotes.SupportNote (icon, label, recipient, explanation, color), derived from direct
action effects. Only flat amounts are numeric; conditional/chance effects carry qualified wording.
Buff names/explanations come from BuffDefinition. This is not serialized and performs no resolver,
RNG or research mutation. Existing descriptions remain the fallback for unrecognized effects.

FamiliarDefinition.portrait remains the sole familiar art binding; AtlasTexture may crop transparent
padding without altering its source PNG. ConditionRibbon's condition_id metadata identifies a
current header button for announcement docking; missing IDs fall back to a stationary fade.
ResourceBarArt's frame textures are presentation resources, with no gameplay geometry or values.

## V0.2.1 presentation interfaces (transient, not saved)

See [the cleanup report](reports/V0_2_1_ENGINEERING_CLEANUP.md). No Resource, save, settings or
content field changed.

- **Inspection providers.** A source control supplies its text through `get_tooltip(point)` and
  its typed payload through one of three metadata providers, called with the source-local point:
  `inspection_readout` (ActionReadout, action and supply buttons), `inspection_intent`
  (IntentReadout, the move icon) or `inspection_unit` (UnitReadout, unit bodies; individual field
  regions return null). The inspector re-renders when the text changes. A unit body's text is
  therefore `UnitReadout.plain_text()`, built from the same readout the card draws, which lists
  every field the card can show.
- **Wheel ownership.** `HoverInspector.claims_wheel(hovered)` is the single rule: the card itself,
  its current source while expanded, or a collapsed source outside any scrolling list. Otherwise
  the hovered Actions/Supplies list scrolls (`ActionMenu.wheel_claimed`, wired by BattleScene).
  Neither handler depends on scene-tree callback order.
- **Inspection source.** `HoverInspector.follow_keyboard()` selects focus inspection after
  deliberate navigation (ActionPicker's `keyboard_navigation` signal). Pointer motion or a click
  selects pointer inspection again. `follows_pointer()` reports it.
- **Layout.** `BattleLayout` exposes `header, timeline, stage, dock, help, actions, preview,
  supplies, timed` (`familiar` was renamed `supplies`; the unused party/details/overlay/rail/ribbon
  rectangles and modes were removed). These are presentation geometry, never hit areas.
- **Cards.** `PreviewPanel.card_height(readout)` sizes nested action and move cards.
  `PreviewPanel.get_text()` returns the card's plain text. `UITheme.plain_text(bbcode)` is the one
  markup stripper.
- **Removed scaffolding.** `DetailsPanel`, `PartyCard`, the inspector's pinned fields, the picker's
  group/analysis-extra path and its `target_reviewed` signal, UnitView's label/plate-badge fields,
  and the intent strip's mode, stats and selection fields. None had a remaining consumer.
- **QA isolation.** `tools/qa_godot.py` sets `APPDATA`, `XDG_DATA_HOME` and `HOLLOW_CHOIR_QA_HOME`.
  `tools/qa_user_data.gd` (preloaded by the test runner and capture tool) refuses to run when user data is outside that
  home.

## V0.3 presentation additions

`FieldGuideReadout.build(EnemyDefinition, BestiaryState, ResearchConfig)` returns null for unknown
species. Otherwise it contains the learned identity/portrait, current level/points, config-derived
next threshold/fraction and filtered text sections. It never stores engine state or temporary
Inspect/hit reveals. Observed shows field notes/sources; Studied adds affinities; Understood adds
base stats, species traits/immunities and initial move cards; Mastered adds tendencies, rare
interactions and later-phase moves. Existing Understood trait text may mention later moves, as
in battle. Later phase thresholds are not shown. The guide displays existing weapon_mastery totals
and ignores missing content IDs without rewriting the save. No new persisted fields.

`MusicLibrary.playlists: Array[MusicPlaylist]`, `MusicPlaylist.cue_id/tracks`, and
`MusicTrack.id/version/tone/stream/source_offset_seconds/gain_db/crossfade_seconds/sync_group` are presentation Resources
outside `data/` and DefinitionRegistry. `AudioManager.request_music(cue_id, tone = base)` requests
one cue; missing cue fades to silence. Missing tone falls back to base, then calm, then remaining
playable mixes. Tone changes prefer the same version and preserve source time. The offset is the
preparation manifest's trim_start_seconds, defaulting to zero for old Resources. Same-song manual
selections also preserve source time; new cues and explicit Next version start at zero. A target
outside its source-time range clamps to its start/tail. `sync_group` is reserved for an aligned-layer
adapter; current full mixes overlap and are never claimed sample synchronized.

`tools/prepare_music.py` generates `assets/audio/music/runtime_library.tres` and
`prepared_manifest.json` from authorized inbox names. The manifest is tooling evidence, not a
runtime parser: source/export paths and SHA-256, native rate, duration, measured edge trims,
constant export gain, user authorization and decode check. Source updates regenerate active
playlists, without deleting old exports. The delivery catalog retains history and active_playlist
markers; single-version selected fields can remain null because playlist membership is explicit.
Playback uses a private RNG, real-time fades and two persistent decks on the existing Music bus.

Manual audition is exposed by `MusicMixer.audition(cue_id, track_id) -> bool` (invalid IDs preserve
playback), `next_mix() -> bool` (starts another version at zero), `test_loop() -> bool` (seeks five
seconds before the normal end-overlap trigger, unavailable during fades), `seek(seconds) -> bool`
(rejects nonfinite values, clamps bounds and commits the selected deck), and
`playback_status() -> Dictionary`. Status contains cue, requested tone, actual track/tone,
position/duration and source_position in seconds, seconds_until_transition, transition reason,
fading and active player count. Audio Lab uses these presentation-only methods; selection does
not pin later shuffle rotation. Its HSlider supports click/drag/keyboard seeking and suppresses
playback-update feedback. Pending play/seek reads do not repeatedly add pre-command mix age.
Explicit auditions and version-preserving tone switches update shuffle history.

`tools/import_music.py` accepts paths or inbox filenames. It canonicalizes spaces/dashes/case and
version padding, copies external originals or renames inbox audio/sidecars, rejects duplicate
cue/version/tone formats and archives previous audio/metadata before explicit `--replace` swaps.
The delivery metadata retains original_filename provenance and records current_filename separately.

## V0.5A salvage and preparation

See [the implementation report](reports/V0_5A_BACKEND_IMPLEMENTATION.md) for the API/fixture guide.
Nothing here changes combat rules, balance or the battle resource policy (every encounter resets).

- **Grants ride inside the accomplishment's write.** `WorldSession.commit_victory()` grants the
  site's unclaimed `SITE_VICTORY` rewards, `restore_bell()` the `WORLD_FLAG wayside_bell_restored`
  rewards and `open_latch()` any `WORLD_FLAG return_latch_open` rewards (none authored), in the same
  copy → change → write → adopt commit. Eligibility is the claim id, never an encounter token.
  Discovering a site, examining the bell, defeat, leaving, an interrupted entry, Practice and the
  recording Lab (`GameState.record_battle`) grant nothing. Equipment that is already owned is never
  duplicated; material stacks saturate at 999.
- **Receipts after adoption only.** A successful reward-capable command sets
  `WorldSession.last_receipts: Array[RewardReadout]` (status `GRANTED`) and emits
  `EventBus.rewards_granted(receipt)` once per receipt. A failed write changes nothing and emits
  nothing; Retry grants once. A repeated victory token is a no-op with no receipt.
- **World-entry reconciliation.** `WorldSession.reconcile()` (called by `WorldHost` after `open()`,
  through the save-failure card) grants, in one write, the rewards whose accomplishment the save's
  journey still proves (a cleared site or a set flag without its claim) and repairs the saved
  loadout: approved gear in its own slot that the save does not list as owned becomes owned; an
  unknown or wrong-slot armor id is unequipped; an unknown or wrong-slot weapon becomes the starter
  loadout's weapon (or the first owned weapon). It writes nothing when there is nothing to do, so
  a second call is a no-op. `last_repairs` lists the repairs written.
- **Preparation station context.** *Superseded by the V0.5 UI section: equipment no longer needs a
  station; the context now carries a typed Forge or Stillroom service.* `enter_station(landmark_id)`
  (a PREPARATION landmark; refused
  while an entry is pending) is opened by the bench interaction and ends with `leave_station()`,
  which the host calls when the bench closes and on any return to exploration, battle or a
  transition; `begin_entry()` and `reset_journey()` also end it. It is never saved; a saved anchor or
  a hidden button never stands in for it.
- **Preparation commands.** `equip(slot, item_id)`, `unequip(slot)` and `choose_weapon(weapon_id)`
  (= `equip(WEAPON, …)`) return `Error` and set `last_preparation: PreparationResult`
  {reason, error, slot, item_id, previous_id, changed}. Reasons: `NO_STATION`, `ENCOUNTER_PENDING`
  (`ERR_UNAVAILABLE`); `UNKNOWN_ITEM`, `NOT_OWNED`, `WRONG_SLOT`, `REQUIRED_SLOT` (the weapon cannot
  be emptied), `ACTION_LIMIT` (the whole new loadout would exceed `PartyLoadout.MAX_ACTIONS` for a
  party member; nothing is truncated) (`ERR_INVALID_PARAMETER`); `WRITE_FAILED` (the writer's error;
  live state unchanged). Changes apply to the next `EncounterEntry`; a captured entry and its retry
  never change. Practice, the Lab and `PartyLoadout.from_ids` stay ownership-free.
- **Readouts (plain data, copies).** `WorldSession.preparation() -> PreparationReadout` {station_id,
  reason, reason_text, action_limit, protagonist_actions, companion_actions, slots:
  `EquipmentSlotReadout` ×4 {slot, label, optional, equipped_id, equipped_name, can_remove, options:
  [{id, name, icon_path, description, details, category, rarity, equipped, selectable, reason, reason_text,
  actions, traits: [{name, description}], grants: [{name, description}], resonance}]}};
  `inventory() -> InventoryReadout` {equipment_capacity, materials: [{id, name, description, icon_path, count}],
  equipment: [owned option facts above plus slot, slot_label, mastery]}; `reward_previews(source,
  source_id)` and `EncounterCardReadout.rewards` → `RewardReadout` {claim_id, label, source,
  source_id, equipment_slots, status AVAILABLE/CLAIMED/GRANTED, items: [{kind, id, name, description, icon_path,
  count, added, total, owned}]}, `status_text()` (eligibility wording), `summary()` and
  `plain_text()`. They name only approved items and
  their public text; no enemy, species or research facts, and no shared Resources.
- **Bench listing.** `WorldRules.bench_weapons(progress)` lists every owned, approved weapon by
  family, rarity and id (the three starters keep their order); `WorldRules.STARTER_LOADOUTS` was
  removed.

### V0.5A Director presentation integration

`WorldHost.open_bench()` presents `session.preparation()` through `WorldPreparationView`, with
Weapon/Garb/Charm/Relic tabs, public trait/action facts and backend action counts/availability.
`equip`/`unequip` run through the host's `_commit` adapter; its optional rejection callback rebuilds
the station from current readouts and shows `last_preparation.text()`. A failed write uses the
existing Retry card and captures IDs/resources rather than discarded controls. Paused Inventory
uses only `session.inventory()`; Inventory opened from preparation remains inside the same station
interaction and returns to its selected slot. Neither inventory path equips or writes.

Victory, bell restoration and old-save reconciliation render only the command's successfully
adopted `last_receipts`, using `WorldRewardView`. No second EventBus listener consumes these same
receipts. Empty/no-addition receipts are omitted. Old-save catch-up has one dismissible notice
after a successful write; repeat world entry has none. The encounter card renders its already
filtered `rewards` previews and typed status without changing eligibility or enemy knowledge.
Material icon paths are now supplied by two native SVG textures through `MaterialDefinition.icon`.
These are presentation changes only; save version, command contracts and combat remain unchanged.

### V0.5A character menu follow-up

The exploration portrait opens `WorldCharacterView` (Inventory, Actions, Magic, Skills). Paused
Inventory and the bench inventory use the same view, preserving their return destination and
station context. `CharacterReadout.build()` copies the real `UnitFactory.protagonist_actions()`
into Actions/Magic plus saved weapon mastery and currently equipped passives into Skills (V0.5 UI:
every granted action, arranged or not; resonance and familiar passives added). It
does not simulate a battle or infer target numbers. Equipment and material cells provide
`ItemInspectionReadout` through `inspection_readout`; the existing `HoverInspector` renders
these with the same focus/pointer arbitration, detail setting, Alt/gamepad info, wheel ownership,
right-click pin and source-destruction release as combat. `manages_detail_input` is opt-in for
world inspectors; battle retains its existing input owner.

Equipment has ten starting presentation slots (two rows of five). `RewardDefinition.equipment_slots`
defaults to zero and must be 0–50 in multiples of five. First bell restoration grants five.
`PreparationRules.inventory()` computes capacity from approved claimed reward definitions;
ingredients consume no slots. There is no new saved counter or migration: existing claims unlock
their row, failed transactions publish none, reset/reload retain capacity, and repeated claims
cannot add rows. This is visible bag capacity, not an item-discard or full-bag rejection mechanic;
compatibility equipment above capacity is always shown. Future acquisition rules must explicitly
define a full-bag policy before adding content that can exhaust capacity.

The V0.5 visual follow-up uses existing `UICraft` cloth/leather textures for square pockets and
dark/gold atlas strips for ingredient and character-fact rows. These are presentation styles;
item payloads, inspection input and capacity contracts stay the same. Application metadata is now
0.5.0 at Adrian's request; save version remains 1.

`WeaponDefinition.icon` and `ArmorDefinition.icon` are optional presentation textures copied into
readouts; reward equipment uses the same paths. Compact loot rows show only icon/name/quantity,
with descriptions in the shared inspector. The persistent Exposed sprite banner and bullseye
are replaced by an effect icon using only the presentation ledger's weak-point flag. It explains
increased damage, Precision, Spotter's Mark and Break recovery without revealing enemy research.

## V0.5B Forge and Stillroom

See [the implementation report](reports/V0_5B_BACKEND_IMPLEMENTATION.md) for the API/fixture
guide. No combat rule, balance number or encounter changed; a battle without a fitting is
identical to before (determinism probe in the report).

- **Data.** `data/crafting/forge_first_fitting.tres` (`forge.first_fitting`: 2 Bog Iron, 1 mastery
  point on Pilgrim's Edge, Mire Maul or Reedbow, refundable; Pilgrim's Edge with Merciful Grip or
  Hollow Echo), `stillroom_clotting_salve.tres` (1 Bog Iron) and `stillroom_focus_tincture.tres`
  (1 Storm Salt), both permanent; `data/modifications/merciful_grip_fitting.tres` and
  `hollow_echo_fitting.tres` reuse the traits authored in `merciful_iron.tres` and
  `hollow_reliquary.tres` by reference. Pilgrim's Edge keeps `socket_count = 0`; capacity is derived.
- **Station.** *V0.5 UI: purchase/refund/fit need the open station of their own service (Forge anvil
  or Stillroom; `WRONG_STATION` otherwise) and `prepare_potion` is a field command; see the V0.5 UI
  section.* Every command needs the bench's station context and no pending encounter (the same
  context as equipment). Commands return `Error` and set `WorldSession.last_crafting:
  CraftingResult` {command, reason, error, reason_text, recipe_id, weapon_id, modification_id,
  potion_slot, potion_id, previous_id, changed, spent, refunded, cleared_fitting}.
  - `purchase(recipe_id)`: spends the whole price and records the unlock in one write.
  - `refund(recipe_id)`: refundable recipes only; returns exactly the price and clears the unlock
    and that weapon's fitting together; rejected whole (`REFUND_OVERFLOW`) if any stack would pass 999.
  - `fit(weapon_id, fitting_id)` / `remove_fitting(weapon_id)`: free; the fitting applies to the
    next encounter whenever that weapon is equipped.
  - `prepare_potion(slot_index, potion_id)`: slot 0 or 1; a free starter or a potion whose recipe is
    owned, not already in the other slot.
  A repeated fit or potion choice is an accepted no-op that writes nothing.
- **Reasons.** `NO_STATION`, `ENCOUNTER_PENDING` (`ERR_UNAVAILABLE`); `ALREADY_OWNED`
  (`ERR_ALREADY_EXISTS`; never spends again); `UNKNOWN_RECIPE`, `RECIPE_NOT_OWNED`,
  `INSUFFICIENT_MATERIALS`, `MASTERY_REQUIRED`, `NOT_REFUNDABLE`, `REFUND_OVERFLOW`, `UNKNOWN_FITTING`,
  `WRONG_WEAPON`, `WEAPON_NOT_OWNED`, `NO_FITTING_CAPACITY`, `DUPLICATE_TRAIT`, `ACTION_LIMIT`,
  `UNKNOWN_POTION`, `POTION_LOCKED`, `DUPLICATE_POTION`, `INVALID_POTION_SLOT`
  (`ERR_INVALID_PARAMETER`); `WRITE_FAILED` (the writer's error; live state unchanged, Retry
  repeats the command). Equipment commands gain `PreparationResult.Reason.DUPLICATE_TRAIT = 9` when
  the new loadout would carry an active fitting's trait twice.
- **Duplicate traits.** A fitting whose trait the resulting loadout already supplies (e.g. a Hollow
  Reliquary with the Hollow Echo fitting on the equipped Pilgrim's Edge) is rejected in either
  direction; nothing is doubled, dropped or removed. Reconciliation removes such a fitting from an
  edited save (never the gear).
- **Publishing.** A successful changing command emits `EventBus.crafting_completed(result)` once,
  after adoption; rejections, no-ops and failed writes emit nothing.
- **Battle.** `PreparationRules.battle_ids(progress, registry)` = the saved loadout ids plus the
  resolved `modifications`; `EncounterEntry.capture()` stores them; `UnitFactory` adds each
  fitting's trait to the protagonist with the source `"<weapon> fitting"`. Potions use the Supplies
  slots (not the eight-action grid) and keep their authored charges; recipes unlock selection only.
- **Readouts (plain-data copies).** `WorldSession.crafting() -> CraftingReadout` {station_id, reason,
  reason_text, materials, recipes: `RecipeReadout` (costs with held/enough, Base/Reagents/Catalyst,
  mastery required/current/weapons/met, owned, refundable, refund preview, can_purchase/can_refund
  with typed reasons and text, fitting choices or potion facts), fittings: `FittingReadout` (weapon,
  equipped, kit owned, capacity + reason, installed, active, can_remove, base traits, options with
  trait facts, typed reasons and action counts), potion_slots: `PotionSlotReadout` ×2 (prepared
  potion, options with source, recipe id, unlocked, selected, typed reasons), action counts}.
  `CharacterReadout` and `PreparationReadout` read the same campaign loadout (fitting passives
  included). No enemy, species or research facts.

## V0.5C exploration vocabulary

Production content is placed in `data/world/first_footsteps.tres` and the Reedway scene:
iron seam (+1 Bog Iron), listening rhythm (low → high → middle, no direct reward), and the
drowned niche it reveals (existing Fenrunner Leathers). The [Director specification](design/V05C_EXPLORATION.md)
confirms persistence, copy and physically tested coordinates. `tests/fixtures/exploration_kit.gd`
keeps an independent test proposal and a second, test-only puzzle. The
[backend report](reports/V0_5C_BACKEND_IMPLEMENTATION.md) remains historical.

- **Commands** (`WorldSession`, each one atomic write; rewards ride inside it; receipts and
  `EventBus.rewards_granted` only after adoption): `gather(area_id, landmark_id)`,
  `find_secret(area_id, landmark_id)`, `strike_rune(area_id, landmark_id)`. They set
  `last_exploration: ExplorationResult` {command, reason, error, landmark_id, puzzle_id, strike
  (`ADVANCED`, `MISTAKE`, `SOLVED`), progress, length, revealed, rewarded}. Reasons:
  `UNKNOWN_FEATURE` (`ERR_INVALID_PARAMETER`), `ENCOUNTER_PENDING`, `HIDDEN` (`ERR_UNAVAILABLE`),
  `ALREADY_DONE` (`ERR_ALREADY_EXISTS`; no write), `WRITE_FAILED`. Each charts its landmark and makes
  it the resume point when it is a safe anchor.
- **Rune grammar** (`ExplorationRules.strike`, pure): the expected rune advances the attempt; the
  last one solves the puzzle; a wrong rune clears the attempt, or restarts it when it is the
  solution's first rune. Every strike is saved. `WorldSession.puzzle(id) -> PuzzleReadout` {id, name,
  solved, entered, length, runes: [{id, label, lit}]} never carries the solution.
- **Perception.** `WorldRules.perceivable()` / `ExplorationRules.perceivable()`: an unrevealed secret
  has no prompt, is never discovered by proximity and is never charted. `WorldRules.interaction_label`,
  `dialogue` and `map_readout` take an optional `WorldDefinition` (the host passes its own).
- **Host routing.** GATHERING and SECRET open a dialogue with `gather` /
  `search` actions and show successful receipts with the existing reward card; Confirm at a RUNE
  strikes at once and emits `WorldHost.rune_struck(result)`; solving shows a short card. Copy lines
  are Director-authored in `WorldCopy`; static saved feedback, prompt progress and scene-authored
  stone tones supplement the existing reward cards. No solution is passed to widgets.

## V0.5 UI backend: journeys, saves, field preparation, stations, combat arrangement

See [the implementation report](reports/V0_5_UI_BACKEND_IMPLEMENTATION.md). Save version 1;
application 0.5.0. No combat rule, balance number, recipe, reward or encounter changed; a battle
built from a static loadout is identical to before.

- **Save slots.** `SaveManager.summary(slot) -> SaveSlotSummary` {slot, state (`EMPTY`, `READY`,
  `UNREADABLE`, `UNSUPPORTED`), saved_at_unix (UTC epoch seconds; 0 = unknown), saved_at_text
  ("2026-10-10 14:03 UTC" or "Time unknown"), save_version, game_version, battles_won, weapon_id,
  weapon_name, difficulty, difficulty_name, starter_preset, reason_text}; `summaries()` (slot order)
  and `journeys()` (READY only, newest first, equal times by slot number). Summaries read quietly
  (`read_json_quiet`: no engine error for a damaged file), type-check every field and never load,
  write or change the active slot. Every non-EMPTY state counts as occupied. `load_slot(slot)` adopts
  only after parse and migration succeed (`GameState.adopt`); a missing, damaged or newer file
  changes neither the live journey nor the active slot. `SaveMigrator.migrate` rejects an envelope
  without a dictionary `data` section. The slot count is `SaveSlotSummary.SLOT_COUNT` (3) and
  `SaveManager.SLOT_COUNT` aliases it. Pure rules use the class constant: tool scripts compile them
  before the autoloads exist.
- **New Journey.** `MainMenu.new_journey_requested(options)` is connected in `_ready`. Options:
  `{difficulty: int, preset_id: StringName, slot: int, replace: bool}`; without `slot` the title
  shows the explicit slot step (an occupied slot needs a separate Replace confirmation).
  `GameState.start_journey(options, writer = SaveManager.write_progress) -> JourneyResult` {reason
  (`OK`, `UNKNOWN_DIFFICULTY`, `UNKNOWN_PRESET`, `NO_SLOT`, `INVALID_SLOT`, `SLOT_OCCUPIED`
  (`ERR_ALREADY_EXISTS`), `WRITE_FAILED`), error, slot, difficulty, preset_id, replace, replaced,
  changed}. Values are never guessed: a missing or wrong-typed difficulty, preset or slot is
  rejected. The fresh journey is `ProgressState` defaults with the preset weapon equipped, the
  difficulty and starter recorded and the world at its start anchor (`JourneyRules.fresh_progress`):
  nothing is owned, claimed or unlocked beyond a fresh campaign. It is written atomically to the
  chosen slot and adopted (`GameState.adopt`: progress, active slot, session resumed, Settings
  difficulty) only after success; then `game_saved(slot, true)` once. A rejection or failure changes
  no file, the live journey, the active slot or Settings. `JourneyRules.setup(registry, summaries,
  default_difficulty) -> JourneySetupReadout` {difficulties [{id, name, description}], presets [{id,
  name, description, icon_path, category, facts, details}], slots, default_difficulty,
  default_preset, suggested_slot (first EMPTY, -1 = all occupied), all_full()}.
- **Save events.** `WorldSession.commit()` owns `EventBus.game_saved(slot, true)`: one emission per
  successful world write, after adoption; none for a rejection, an accepted no-op or a failed write.
  The world host pushes no save notice of its own and hides the notice layer while a battle owns
  the screen. `SaveManager.save_slot` (Practice battle recording) is unchanged; `write_progress`
  stays a silent candidate writer. Reward receipts still emit `rewards_granted` after adoption.
- **Field preparation.** `equip`/`unequip`/`choose_weapon` and `prepare_potion` need no station:
  `PreparationRules.availability(progress)` and `CraftingRules.field_availability(progress)` reject
  only during a pending or active encounter (`ENCOUNTER_PENDING`). `PreparationResult.NO_STATION`
  is never returned (kept for compatibility). Re-choosing the equipped item is an accepted no-op that
  writes nothing. A changing equip reconciles the combat arrangement in the same write and reports it:
  `PreparationResult.actions_removed / actions_added` [{id, name, position}], `summary()`
  (saved/unchanged/rejection plus one sentence per affected position). Equipment options preview it
  (`option.combat`); `option.actions` counts every action the gear would grant;
  `PreparationReadout.granted_actions` / `protagonist_actions` (arranged, for battle) /
  `combat_capacity`.
- **Station services.** `WorldSession.enter_station(landmark_id)` opens the landmark's typed
  `LandmarkDefinition.Service`; `service()` reads it; leaving, walking, transitions, battles and
  Reset journey end it. `CraftingRules.availability(progress, service, required)`: `NO_STATION`
  without an open station, `ENCOUNTER_PENDING`, then `WRONG_STATION` (`CraftingResult.Reason` 21,
  `ERR_UNAVAILABLE`) when the open station offers the other service. Kit purchase, refund and
  fit/remove need `FORGE`; Stillroom purchases need `STILLROOM`. `CraftingReadout.service`; each
  recipe and fitting carries its own availability here; potion slots carry the field availability.
  Display constants: `FITTING_SOCKETS = 3`, `POTION_POSITIONS = 4`, `fitting_capacity = 1`,
  `potion_capacity = 2`, `locked_reason_text` (display concepts only).
- **Combat arrangement.** `CombatRules`: `capacity()` = `STARTING_CAPACITY` (6) until authored
  progression exists, never a saved counter; `POSITIONS` = `PartyLoadout.MAX_ACTIONS` (8 shown,
  2 locked). Candidates = granted actions, Actions then Magic. `resolve(saved, candidate_ids, slots)`
  keeps each saved position whose action is still granted, frees duplicates and ungranted ids, fills
  freed and remaining positions with saved overflow first, then candidates in order; never a
  duplicate or more than `slots`. Commands (`WorldSession`, field, one atomic write, typed
  `CombatResult` in `last_combat` {command, reason, error, reason_text, action_id, position,
  other_position, previous_id, before, after, changed}): `arrange_action(position, action_id)` (PUT:
  replace, swap when already arranged, or fill the next empty position), `swap_actions(first,
  second)`, `move_action(action_id, position)` (reorder). Reasons: `ENCOUNTER_PENDING`
  (`ERR_UNAVAILABLE`), `INVALID_POSITION`, `LOCKED_POSITION`, `UNKNOWN_ACTION`, `NOT_GRANTED`,
  `PASSIVE_SKILL`, `EMPTY_POSITION` (`ERR_INVALID_PARAMETER`), `WRITE_FAILED`. The same arrangement
  is an accepted no-op. `WorldSession.combat() -> CombatReadout` {reason, reason_text, capacity,
  positions_total, action_limit, positions [{index, locked, reason, reason_text, action_id}],
  arranged, unarranged, actions/magic [candidate facts + arranged, position, selectable, reason,
  reason_text, source], skills [passives + mastery facts; never selectable], companion {name,
  actions}}. `CharacterReadout` lists every granted action and adds the authored passives the battle
  applies: active resonances (e.g. Litany: Pilgrim's Edge + Pilgrim's Coat) and the familiar trait.
- **Battle.** `PreparationRules.battle_ids` adds `"actions"`; `EncounterEntry.capture` stores it and
  the journey difficulty; `UnitFactory.protagonist_actions` builds the hero's grid from it. Mastery
  tally, AI, companions and potion Supplies are unchanged.

## V0.5 playtest revision (backend)

Additive to save version 1 and application 0.5.0. Save keys and the one-time supply migration are in
section 6 ("Playtest revision keys"); new definition fields are in the field reference. This section
lists the rules, results, readouts and events presentation consumes. Readouts are plain copies:
changing one changes neither the save nor a definition. Every command below is rejected without a
write (typed reason, nothing published), a failed write adopts and publishes nothing and the same
command may be retried, and an accepted no-op writes nothing.

### Capacities

| Capacity | Shown | Usable | Where it is derived |
|---|---|---|---|
| Combat positions | 8 (`PartyLoadout.MAX_ACTIONS`) | 6 | `CombatRules.STARTING_CAPACITY`; unchanged by this revision. |
| Supply positions | 4 (`SupplyRules.POSITIONS`) | 2 | `SupplyRules.capacity()` = `PartyLoadout.MAX_POTION_SLOTS`. |
| Fitting sockets per fitting-capable weapon | 3 (`CraftingRules.SOCKETS`) | 1 | `CraftingRules.socket_capacity(registry, weapon_id)`; 0 for a weapon no fitting is offered for. |
| Equipment bag cells | 20 (`InventoryReadout.EQUIPMENT_CELLS`) | 10; 15 once the bell restoration reward is claimed | `InventoryReadout.equipment_capacity`: `PreparationRules.STARTING_EQUIPMENT_CAPACITY` plus `RewardDefinition.equipment_slots` of claimed rewards. Cells at or beyond it are locked. |
| Action icons per gear source | 3 (`LoadoutRules.STRIP_CELLS`) | actions that source grants | `LoadoutRules.strip()`. |
| Familiar passives | up to 3 offered (`FamiliarDefinition.MAX_PASSIVES`) | exactly 1 selected | `FamiliarRules`. |
| Doses held per potion | 99 (`PotionDefinition.MAX_STOCK`) | per encounter: `PotionDefinition.charges` | `SupplyRules`. |

None of the usable numbers is saved: each is derived, so a later authored unlock changes one
function and no save.

### Finite supplies (`SupplyRules`, `src/progression/supply_rules.gd`)

Four things are kept apart: the **recipe** (data, open to every save at the Stillroom), the
**stock** (`inventory.consumables`), the **prepared choice** (`loadout.potions`; it survives an empty
stock) and the **allowance** (what one battle starts with: `min(charges, held)`, captured once by
the encounter entry).

- `WorldSession.brew(recipe_id)` (Stillroom context): spends the recipe's whole price and adds its
  `yield_count` to the stock in one write. Reasons: `NO_STATION`, `WRONG_STATION`,
  `ENCOUNTER_PENDING`, `UNKNOWN_RECIPE`, `NOT_BREWABLE`, `MASTERY_REQUIRED`,
  `INSUFFICIENT_MATERIALS`, `STOCK_OVERFLOW` (the yield would pass 99: the whole brew is rejected,
  nothing is clipped). Brewing never prepares a position.
- `WorldSession.prepare_potion(slot, potion_id)` (a field command, unchanged signature): needs a
  usable position, an approved potion not in the other position and at least one held dose
  (`NO_STOCK`). It moves no stock. Re-choosing what the position already holds is an accepted no-op,
  even at zero doses. A position cannot be emptied.
- `WorldSession.begin_entry()` captures `potion_charges` in the entry. Entering moves no stock, and a
  retry of that entry rebuilds the battle from the captured numbers, never from the live stock.
- The battle engine counts the item actions that actually resolved (`BattleResult.item_uses`:
  potion id → count). `WorldSession.commit_victory()` removes them from the stock in the victory's
  own write (`SupplyRules.settle`: never more than the captured allowance, never below zero), and
  reports them in `last_consumed` (`[{id, name, icon_path, count, total}]`).
- **Only a saved victory consumes.** Defeat then Return home, Leave battle, a quit or crash and a
  failed victory write all leave the stock as it was; a repeated victory result
  (`ERR_ALREADY_EXISTS`) settles nothing a second time.
- `PreparationRules.battle_ids()` returns `potion_charges` and `familiar_passive` with the loadout
  ids; `PartyLoadout.from_ids()` without them (Practice, the Lab, static loadouts) keeps the
  authored charges.

### Fittings (`CraftingRules`)

- `WorldSession.craft_fitting(fitting_id)` (Forge context): spends the fitting recipe's whole price
  and records ownership in one write. Reasons: station reasons, `UNKNOWN_FITTING`, `UNKNOWN_RECIPE`
  (no craft recipe), `WEAPON_NOT_OWNED`, `ALREADY_OWNED` (`ERR_ALREADY_EXISTS`; crafted, or granted
  by an older kit), `MASTERY_REQUIRED`, `INSUFFICIENT_MATERIALS`.
- `WorldSession.fit(weapon_id, fitting_id, socket := 0)` and `remove_fitting(weapon_id, socket := 0)`
  are free and never grant materials. New reasons: `FITTING_NOT_OWNED`, `INVALID_SOCKET` (not one of
  the three shown), `LOCKED_SOCKET` (shown, beyond the usable capacity). Duplicate-trait and
  action-limit checks are unchanged.
- **Legacy kit.** `forge.first_fitting` can no longer be bought (`RECIPE_RETIRED`). A save that owns
  it owns every fitting it offered (`CraftingRules.fitting_owned_source()` returns
  `OWNED_LEGACY_KIT`; nothing is written to grandfather it) and may still `refund()` it for its
  exact price; the refund clears an installed fitting only when the save does not also own that
  fitting by craft. A refunded kit cannot be bought back, so no refund loop exists.
- `WorldSession.purchase(recipe_id)` remains for older callers: it brews a potion recipe, crafts a
  fitting recipe and rejects a kit. The stations emit `brew` and `craft` directly.
- `CraftingRules.validate_catalog()` now requires a craft recipe for every fitting, a brew recipe
  for every campaign potion, and that each recipe alone costs no more of a material than the
  authored rewards grant in total. The old "all recipes together fit the route budget" check is
  gone because brewing is repeatable.

`CraftingResult`: `Command.BREW = 4`, `CRAFT = 5`; reasons `STOCK_OVERFLOW = 22`, `NO_STOCK = 23`,
`RECIPE_RETIRED = 24`, `FITTING_NOT_OWNED = 25`, `INVALID_SOCKET = 26`, `LOCKED_SOCKET = 27`,
`NOT_BREWABLE = 28`; new fields `produced` (`[{id, name, icon_path, count, total}]`, BREW) and
`socket` (FIT); `operation()` returns `&"brew"`, `&"craft"`, `&"fit"`, `&"remove"`, `&"prepare"`,
`&"refund"` or `&"purchase"` for a changed command and `&""` for a rejection or a no-op.

`CraftingReadout` gains `ingredients` (the shared catalog, zero counts included), `supplies` (all
four positions; `potion_slots` stays the two usable ones), `stock` (`[{id, name, description,
icon_path, held, cap, usable, prepared_slot, recipe_id}]`) and `SUPPLY_POSITIONS`.
`PotionSlotReadout` gains `state` (`EMPTY`/`PREPARED`/`DEPLETED`/`LOCKED`), `locked`, `reason`,
`icon_path`, `description`, `held`, `cap`, `usable`, `inspection` (title, category, description,
icon_path, facts, details) and `choices` (what the save holds, plus what the position holds).
`RecipeReadout` gains `yield_count`, `potion_held`, `potion_cap`, `potion_total_after`, `can_brew`,
`brew_reason`, `brew_reason_text`, `repeatable`, `retired`, `potion_icon_path`. `FittingReadout`
gains `weapon_icon_path`, `sockets` (three entries: index, locked, reason, fitting id and name),
`socket_capacity` and `legacy_kit` (id, name, owned, can_refund, refund lines); each option gains
`owned`, `owned_source`, `recipe_id`, `costs`, `mastery_*`, `can_craft`, `craft_reason(_text)`,
`can_fit`, `can_remove` and `action` (`&"remove"`, `&"fit"`, `&"craft"` or `&"none"`: the one
primary command the option offers now).

### Ingredients and Loadout facts

- `PreparationRules.ingredient_catalog(progress, registry)` → `[{id, name, description, icon_path,
  count, held}]` for every `listed` material, zero counts included, by `sort_order` then id.
  `InventoryReadout.ingredients` and `CraftingReadout.ingredients` carry the same list.
- `InventoryReadout` gains `EQUIPMENT_CELLS = 20`, `equipment_cells` (cells drawn),
  `cells_locked_text` and `ingredients`; `equipment_capacity` stays the usable count. `EquipmentSlotReadout` gains `source_id`, `icon_path`, `strip_cells` and
  `actions` (the actions that slot's item grants, at most three shown).
- `WorldSession.loadout()` → `LoadoutReadout` (`LoadoutRules`, `src/progression/loadout_rules.gd`):
  `gear` (weapon, garb, charm, relic: `EquipmentSlotReadout` with up to three action facts each),
  `core` (the stance or Guard, the Hollow's innate actions, Inspect, and any action a strip had no
  cell for), `positions` (eight: six usable, two locked, each with its action and source),
  `arranged`/`unarranged`, `supplies` (four positions), `familiar`, `passives` (gear, fitting,
  resonance and familiar passives in effect, never placed in a position), `mastery`, `ingredients`
  and the bag capacity. An action fact is `{id, name, description, details, category, category_id,
  focus_cost, timing, source_id, origin, origin_name, arranged, position, selectable, reason,
  reason_text}`; every granted action appears exactly once across the strips and `core`. Fitting
  sockets are in `FittingReadout`.
- `PreparationResult` gains `actions_kept`, `arrangement_before`, `arrangement_after` and
  `operation()` (`&"equip"`, `&"unequip"` or `&""`). `CombatRules.changes()` returns `kept` beside
  `removed` and `added`; `reconcile()` returns `before` and `after`.

### Familiar (`FamiliarRules`, `src/progression/familiar_rules.gd`)

`WorldSession.familiar()` → `FamiliarReadout` (the travelling familiar, its passives with exactly one
selected, the owned familiars as choices). `choose_familiar(id)` makes an owned, approved familiar
travel and selects its default passive in the same write; `choose_familiar_passive(id)` selects one
of the travelling familiar's passives. Both are field commands rejected during a pending encounter;
see `last_familiar` (`FamiliarResult`: reasons `ENCOUNTER_PENDING`, `UNKNOWN_FAMILIAR`, `NOT_OWNED`,
`UNKNOWN_PASSIVE`, `WRITE_FAILED`; `operation()`). Both authored familiars offer one passive today,
so the selection is real but has one option. World entry repairs an unknown travelling familiar or
a passive the familiar does not offer (`FamiliarRules.repair`, one repair line each). A familiar is
still a passive: no turn, no target, no HP.

### Party Break (`StaggerRules`)

The Hollow and each companion have their own Break meter (`BattleUnit.stagger` / `max_stagger`,
`BattleUnit.has_break_meter()`), filled at battle start from `BalanceConfig.party_max_break`. Only a
damaging enemy action that reaches a living party target changes it, once per target per action:

| The target… | Break removed |
|---|---|
| did not react, or was not offered a reaction | the hit's Break (`party_break`, else `party_break_hit`) |
| reacted and failed | hit × `party_break_failed_multiplier` |
| Braced successfully | hit × `party_break_brace_multiplier` |
| Evaded successfully | hit × `party_break_evade_multiplier` |
| Parried successfully | `party_break_parry_cost` instead of the hit's Break |

The Parry cost is charged once per defending unit per resolved reaction (a multi-hit action costs it
once) and is flagged `BattleEvent.FLAG_REACTION_COST = 1024` on its `STAGGER_DAMAGE` event. At zero
the unit is Broken (`BROKEN`): it loses its next `party_break_turns` activation(s) (`TURN_SKIPPED`),
is not offered a reaction and takes no further Break while Broken (`BattleUnit.can_react()`,
`IntentRules.reacting_targets()`), then recovers with a full meter (`RECOVERED`). The same event
types as enemy Break are used; the subject may now be a party member. None of the enemy Break
consequences apply to the party: no damage vulnerability, no weak point, no growing cap, no Focus
reward to the attacker, no `STAGGER_BREAK` trigger. When every party target of an action is Broken,
no reaction window opens. A lethal hit deals no Break. Damage over time, triggered or effect damage
and authored Stagger effects are not party Break sources. Enemy Stagger is unchanged. Readouts: `ReactionSpec.break_unreacted`, `break_brace`, `break_evade`, `break_parry_cost`,
`break_remaining`, `break_for(reaction)`, `would_break(reaction)`; `IntentPreview.break_unreacted`,
`break_braced`, `break_parry_cost`; `UnitDisplay.has_break` and `UnitReadout.has_break`,
`break_current`, `break_max`; `BattleMetrics.party_breaks`. `ExecutionSimulator` weighs a reaction
that would Break its own unit (`BROKEN_TURN_VALUE = 0.6`), so simulated players stop parrying
themselves into a lost turn.

### Encounter countdown (`EncounterCountdown`, `src/world/encounter_countdown.gd`)

The move-away countdown replaces the Engage card. Pure state fed by `WorldHost` each exploration
frame with `[{id, distance, radius}]` for every uncleared encounter site of the area:

- Entering an armed site's radius starts `DURATION = 3.0` s for that site, which then owns the
  countdown (the nearest armed site starts; ties by id). Leaving the radius cancels and disarms the
  site until the feet are `REARM = 24` px beyond the radius. A site is armed from where the feet
  stand when an area loads, so a threat underfoot waits until the player has left.
- Frames outside exploration (a modal, the paused menu, a lost focus, a transition) are *frozen*:
  the remaining time is held, never reset. Opening and closing a menu cannot postpone it.
- Interact inside the radius fights at once (Adrian, V0.5 follow-up): the host calls `engage(site)`
  without waiting, whether or not a countdown is running. The prompt reads "Engage the patrol"
  (`WorldCopy.PROMPT_ENGAGE`).
- At zero `update()` returns the site once and the host calls `engage(site)`. Either way: one saved
  entry, one battle; `engage()` drops a running countdown first and refuses while a battle exists. A
  failed entry write shows the usual Retry card; Retry enters the same site once.
- A cleared site is not in the list and can own nothing. An area load re-arms from scratch and a
  portal cancels first.

`WorldHost.encounter_countdown()` → `EncounterCountdownReadout` (`state`, `active`, `frozen`,
`threat_id`, `threat_label` (the public category), `remaining`, `duration`, `fraction()`), current
every physics frame; `WorldHost.encounter_countdown_changed(readout)` fires on state changes; the
HUD's `present_countdown(readout)` is called on changes and every frame while one is active.
`WorldHost.open_encounter_card()` and `WorldRules.encounter_card()` remain as unused APIs.

### Quest journal (`QuestRules`, `src/world/quest_rules.gd`)

One quest, `first_footsteps.wayside_bell`, with stages `FIND = 0` (the guard holds the approach),
`RESTORE = 1` (guard cleared), `RETURN = 2` (bell restored) and `COMPLETE = 3` (back in Gloamstead
with the bell restored; kept once reached, until Reset journey). The stage is derived from `world`;
its step text is the HUD objective's own `WorldCopy` lines. It adds no reward, flag or content.
`WorldSession.quests()` → `QuestJournalReadout` (`active`, `completed`, `quest(id)`), each entry a
`QuestReadout` (`id`, `title`, `objective`, `stage`, `stage_count`, `completed`, `steps`:
`[{stage, text, done, current}]`). Reading announces and writes nothing.

`WorldSession.commit()` re-derives the stage on the candidate before every write and, after a
successful write, emits `EventBus.quest_changed(QuestChange)` (`kind`: `ACQUIRED`, `ADVANCED`,
`COMPLETED`, `RESET`; `quest_id`, `title`, `objective`, `previous_stage`, `stage`). Two cases are
silent by design: a quest entering the journal through a world write (an older or loaded save had no
recorded stage) and anything adopted by `reconcile()` at world entry. A journey created this session
is announced once by `WorldSession.announce_new_journey()` (no write), which the host calls at that
journey's first world entry (`GameState.take_fresh_journey()`).

### Save origin, operation facts and cues

- `EventBus.save_completed(SaveFact)` follows every successful `game_saved`: `SaveFact {slot,
  origin}`, `Origin.AUTOMATIC = 0`, `MANUAL = 1`. Manual is exactly `WorldSession.save()` (Save, Save and
  return to title, Save and Quit). Everything else is automatic: every other world write, a new
  journey's first write and a Practice recording (`SaveManager.save_slot`). A failed write emits
  neither event.
- Changed commands publish one typed fact each, after their write: `EventBus.crafting_completed`
  (`CraftingResult`, existing), `preparation_completed(PreparationResult)` and
  `familiar_changed(FamiliarResult)`. Each result's `operation()` names what happened.
- `AudioManager.operation_cue(result) -> int` maps a result to a `Cue` (`-1` = no sound): equip,
  prepare, fit → `UI_EQUIP`; unequip, remove → `UI_UNEQUIP`; brew → `CRAFT_BREW`; craft →
  `CRAFT_SMITH`; refund, purchase → `PURCHASE`. The five cues are appended to `AudioManager.Cue`;
  their sounds are the Director's. The backend plays nothing itself.
- `WorldSession.commit_victory()` fills `last_learnings` (`LearningReadout`: `enemy_id`, `name`,
  `icon`, `icon_path`, `previous_tier`, `new_tier` and their names): one entry per enemy whose
  knowledge tier rose, measured against the tier before the victory was adopted. Empty after a
  failed write or a repeated result. `WorldHost.victory_learnings` holds them while the victory
  card is open.

### Input

`InputBindings` accepts middle, X1 and X2 mouse buttons as bindings (`"mouse:3"`, `"mouse:8"`,
`"mouse:9"` in `settings.cfg`; left and right stay reserved for the pointer). `kind_of(event)`,
`capture_code(event)`, `is_capture_cancel(event)`, `rebound()`, `conflicts()` and
`code_label()` handle them; `ui_mirror_event(event)` turns a bound mouse press into the matching
`ui_*` action so menus follow a mouse-bound Confirm or Cancel, forwarded by `Settings`' window input
handler. `WorldPlayer.moving` is true only when input achieved travel that is not along the normal
of a surface the feet collided with that step (`WorldPlayer.walked()`), so a tap into a wall never
reads as a walking frame.

### V0.5 follow-up: sprint, shortcuts, session log

- **Sprint.** `InputBindings.WORLD_SPRINT` (Shift, pad L-Stick). `WorldPlayer.step(direction, delta,
  sprint)` moves at `SPRINT_MULTIPLIER` (1.6) × `SPEED` while `WorldPlayer.stamina` (`Stamina`, pure)
  allows: `DRAIN_SECONDS = 5` of sprint from full, refilled at a rate of `RECOVER_SECONDS = 5` from
  empty whenever Hollow is not sprinting; emptying it sets `exhausted` until the input is released.
  Only travel achieved at sprint speed spends it; only exploration frames advance it; `place()`
  resets it. `StaminaMeter` draws it under the feet while it is not full. Nothing is saved.
  `WorldHost.sprint_held()` reads the input through the held-input gate (`scripted_sprint` in tests).
- **Shortcuts.** `WORLD_LOADOUT` (L), `WORLD_INVENTORY` (I), `WORLD_JOURNAL` (J), `WORLD_FIELD_GUIDE`
  (F), keyboard only (the pad's face buttons belong to menus). `WorldHost.toggle_view(view)` opens the
  view from exploration, closes it when it is on screen (through the view's own Back), and switches
  between the shortcut views (`shortcut_view()`: `map`, `loadout`, `inventory`, `journal`,
  `field_guide`, `""` while exploring, `other` otherwise). Stations, dialogue, the menu, reward and
  save-failure cards, battles and transitions ignore them. `FieldGuide.close()` leaves the guide.
- **Session log.** `project.godot` keeps Godot's file logging on for every platform at
  `user://logs/hollow_choir.log` and flushes on each print; each run starts a new file and the
  previous ones are kept beside it, timestamped (default 5). The `SessionLog` autoload prints a
  header (version, save format, build, platform, adapter, renderer, display) and `event(category,
  text)` breadcrumbs (`[T+mm:ss.mmm] category: text`): scenes, areas, opened views, engagements,
  battle start (encounter, seed, difficulty) and result, saves and failed writes, quest stages, and
  `session: ended normally` on a clean exit. `quiet` silences it (the test runner sets it).
  `SessionLog.folder()` is the OS path; Settings → Gameplay → Session logs opens it.

### Public wording

Rule classes return player-facing lines straight from `WorldCopy` constants (`CRAFT_*`,
`FAMILIAR_*`, `SUPPLY_*`, `QUEST_BELL_*`, `BAG_LOCKED_CELL`, `JOURNAL_TITLE`). A line with `%d`
placeholders (`CRAFT_STOCK_OVERFLOW`, `SUPPLY_FACT_HELD`, `SUPPLY_FACT_USABLE`) keeps them. The
overlap-era name lookup (`WorldText.line`) is no longer used.

### Presentation wiring

`WorldHost` calls the views directly: `WorldCharacterView.present(inventory, loadout)` (Loadout and
Inventory tabs; the pre-Loadout Equipment and Combat pages are gone), `present_preparation`,
`present_combat`, `WorldCraftingView.present_operation(CraftingResult)`,
`WorldRewardView.present_learnings(Array[LearningReadout])`, `WorldJournalView.make(QuestJournalReadout)`
and `ExplorationHUD.present_countdown(EncounterCountdownReadout)`. `JourneyNotices` listens to
`save_completed` only; `OperationFeedback` plays `AudioManager.operation_cue(result)` for the three
operation events. A floating tooltip card is dismissed as soon as the pointer leaves its source
unless it is pinned; the fixed battle dock keeps its subject across short gaps and while the
pointer reads or scrolls it. A card for a source inside a control marked with the `tooltip_anchor`
meta (`OwnedChoicePopup`) is placed beside that whole control, level with the source, and the
popup's own card draws above the popup (both are top-level, so their z is absolute).
