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

## 6. Save and settings formats

**Save slot** (`user://saves/slot_N.json`, atomic temp-file + rename, D-011):

```json
{ "save_version": 1, "game_version": "0.1.0", "saved_at_unix": 1767225600, "slot": 0,
  "data": { "loadout": {"weapon", "garb", "charm", "relic", "companion", "familiar", "potions"},
            "bestiary": {"points": {id: n}, "sources": {id: [source…]}},
            "weapon_mastery": {id: n},
            "inventory": {"equipment", "materials", "consumables", "quest_items"},
            "companions": {}, "familiars": [], "quests": {},
            "regions": {"pressure": {}, "events": {}}, "world_choices": {}, "home_upgrades": {},
            "stats": {"battles_won", "battles_lost"} } }
```

All references are content ids (strings); no node or Resource is serialized. Sections for later
milestones exist now (empty) so their arrival does not need a migration. To change the format: bump
`SaveMigrator.CURRENT_VERSION` and add one `_to_N` step; never edit a released step.

**Settings** (`user://settings.cfg`, global, not per slot, D-009): sections `gameplay`
(tactical_difficulty, execution_assist, auto_brace, reaction_pause), `display` (window_mode,
window_resolution (`Vector2i`, one of 1280×720 / 1366×768 / 1600×900 / 1920×1080 / 2560×1440),
text_scale, screen_shake, reduce_flashing, show_damage_numbers, advanced_tooltips, combat_speed,
auto_advance_text, subtitles), `audio` (master/music/sfx volume) and `bindings` (action → codes such as
`"key:Space"`, `"joy:0"`; missing actions use the defaults in `InputBindings.DEFAULTS`).
The CombatSandbox remembers its own form in `user://sandbox.cfg`.
Absent/invalid window resolution falls back to 1280×720. GUI input mirrors replace their native
defaults. Enter/gamepad A confirm by default, Space/Z remain command inputs; saved explicit rebinds
remain authoritative. No progress-save format or migration changes are required.

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
| `trait_def` | `TraitDefinition` | `` |  |
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

A brewed combat consumable carried in one of the potion slots. Using it is an ITEM action. Recipe data (Base + Reagent + optional Catalyst) arrives with the Stillroom milestone.

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` |  |
| `display_name` | `String` | `""` |  |
| `description` | `String` | `""` |  |
| `action` | `ActionDefinition` | `` | Category must be ITEM. Targets and effects live here. |
| `charges` | `int` | `1` | Doses per expedition in one slot. |

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
