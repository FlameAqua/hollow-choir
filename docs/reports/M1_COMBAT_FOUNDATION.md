# Feature Report — M1 Combat Foundation

Owner: Claude (Lead Gameplay Engineer). Reviewers: ChatGPT (Game Director) for design, UX, balance
and exploit review. Scope and architecture were proposed in
[`docs/proposals/M1_COMBAT_FOUNDATION.md`](../proposals/M1_COMBAT_FOUNDATION.md) and cover the
roadmap's **Foundation**, **Combat toy** and **Combat ecosystem** phases. Everything listed as a
non-goal there (overworld, hub, quests, puzzles, Pressure, crafting UIs, loot, narrative, music, final
art) is still out of scope.

**Status:** complete and playable. 119 automated tests pass (unit, content and headless UI suites);
all 153 scripts compile; batch simulations run for every encounter × loadout × execution profile.

## How to try it (five minutes)

1. Open the project in Godot 4.7.2 and press Play → **Combat Sandbox** → **Start battle** (the
   *Training Yard* dummy telegraphs every reaction type).
2. Choose actions with the arrows and Z/Enter; press **Space** in the bright zone during action
   commands; when a ring closes on a party member press **A** Brace, **S** Evade or **D** Parry.
3. Hold **Alt** for the analysis layer, hover enemies and intents, press **Tab** for the log.
4. Try *Fen Patrol* (Flooded Ground) and *The Mirebell Cantor* (boss), then press **Simulate**.

## FILES CREATED / MODIFIED

Modified: `project.godot` (version, main scene, seven autoloads, 1280×720 canvas-items stretch,
pixel filtering). Everything else is new: about 300 tracked files excluding `.uid`/`.import`
sidecars — 153 scripts, 100 content `.tres`, 22 placeholder sounds, scenes, docs and CI.

| Area | Files | Purpose |
|---|---|---|
| Core | `src/core/` (6) | `Enums` (append-only closed sets), `EnumText`, `InputBindings`, `GameSettings`, `BattleLaunch`, `DefinitionRegistry` |
| Data contracts | `src/data/**` (31) | Resource definitions: rules (trait, modifier, trigger, effect, condition, buff), combat (action, command, enemy action, AI consideration, status, battlefield condition), combatants, items, configs (balance, research, defaults, difficulty, assist, skill), encounters, loadouts |
| Battle engine | `src/battle/` (6) + `runtime/` (10) + `requests/` (9) + `rules/` (23) + `preview/` (3) | Deterministic state machine, runtime models, input requests, static rule libraries, previews |
| AI | `src/battle/ai/` (2) | Utility-scored enemy AI with difficulty-gated considerations and explanations |
| Simulation | `src/battle/sim/` (6), `tools/simulate.gd` | Execution simulator, party autopilot, metrics, reports, CLI |
| Progression / save | `src/progression/` (2), `src/save/` (1), `src/autoload/save_manager.gd` | Bestiary and mastery models, versioned JSON saves, migrator |
| Autoloads | `src/autoload/` (7) | EventBus, Database, AudioManager, Settings, GameState, SaveManager, SceneRouter |
| UI | `src/ui/ui_theme.gd`, `src/ui/battle/` (17), `src/ui/battle/commands/` (6) | Theme, battlefield, unit views, intents, timeline, menus, previews, log, banners, event player, action picker, four command widgets and the reaction widget |
| Scenes | `scenes/battle/`, `scenes/sandbox/`, `scenes/main/` (8) | Battle presenter, CombatSandbox, main menu, settings |
| Content | `data/**` (100 `.tres`) | 3 weapon families / 7 weapons, 5 armor, 3 resonances, 2 familiars, 4 potions, protagonist + Mara, 6 enemies + elite + boss + training dummy, 8 encounters, 4 loadouts, 4 statuses, 2 conditions, 6 roles, 11 buffs, profiles |
| Audio | `assets/audio/sfx/` (22 `.wav`), `tools/generate_placeholder_sfx.py` | Placeholder synthesized cues (stdlib generator, reproducible) |
| Tests | `tests/` (17) | Runner with engine-error capture and async tests, fixtures, 12 suites |
| Tooling | `tools/check_scripts.gd`, `.github/workflows/ci.yml` | In-process compile check, CI |
| Docs | `README.md`, `docs/*` | Proposal, decision log (D-001…D-016), data contracts, testing, design questions, this report |

## ARCHITECTURE SUMMARY

```
data/*.tres ──► DefinitionRegistry ──► BattleSetup (loadout + encounter + profiles + seed)
                                            │
                     ┌──────────────────────▼──────────────────────┐
                     │ BattleEngine (pure, deterministic, no Nodes)│
                     │ stops only at ACTION_SELECT / ACTION_COMMAND │
                     │ / REACTION; everything else → BattleEvents   │
                     └───────┬───────────────────────────┬──────────┘
            requests/submits │                           │ requests/submits
   ┌─────────────────────────▼────────┐      ┌───────────▼──────────────────────────┐
   │ BattleScene presenter            │      │ SimulationRunner / tests / replay     │
   │  ActionPicker → menu + targeting │      │  PartyAutopilot + ExecutionSimulator  │
   │  CommandWidget ×4, ReactionWidget│      │  BattleMetrics → SimulationReport     │
   │  BattleEventPlayer → animation,  │      └───────────────────────────────────────┘
   │  SFX, numbers, banners, log      │
   └──────────────────────────────────┘
```

- **One engine for everything** (D-002): the game, the simulator, the replay tool and the tests
  drive the same `BattleEngine`. Seed + input log reproduce any battle.
- **Rules are data** (D-004): weapon identities, armor, resonance, familiars, companion passive,
  statuses, conditions, buffs and species mechanics are Traits interpreted by a handful of static
  rule libraries. New content needs no code.
- **AI** scores every legal (action, target) pair: base priority × considerations (gated by
  difficulty) × Story courtesy rules × soft-target focus (Adventurer+) × seeded noise; role defaults
  are merged in from data; every intent records the reasons shown in its "Why" line. Tactician also
  adapts to reactions the party has *already* performed successfully (observed, never predicted).
- **Presentation** (D-013, D-014): the presenter animates drained events with per-event HP/Stagger
  ledgers, so bars never run ahead of hits; every wait is a node-bound tween so the sandbox can
  restart mid-animation safely. Timing widgets use wall-clock time; Combat Speed never touches a
  window.
- **Information layers** (GDD "Interface philosophy"): the immediate layer is always visible (intent
  icon, targets, reaction availability, threat word, channel countdown, HP, Stagger, statuses,
  conditions with full explanation); exact numbers, move names and "why" unlock with bestiary research
  or Inspect; the analysis layer (formula breakdown, windows in ms, tags) shows while Alt is held.

## DATA CONTRACT

Full reference: [`docs/DATA_CONTRACTS.md`](../DATA_CONTRACTS.md) (rules vocabulary, trigger roles,
effect/condition field tables, how to add content, save/settings formats, generated field tables).
Highlights for the Director:

- Every tunable number is in `data/config/balance.tres`, the difficulty/assist/skill profiles, or the
  content Resource it belongs to. Nothing balance-related is a code constant.
- Enemy abilities carry the GDD contract (`base_priority`, `focus_cost` = resource cost, `cooldown`,
  `target_rule`, `use_conditions`, `role_tags`, `synergy_setup/payoff`, `can_brace/can_evade/can_parry`)
  plus channel turns, intent category and the required telegraph text.
- `data/config/defaults.tres` names the starter loadout, the practice encounter and the CLI's
  comparison loadouts, so code never hardcodes content ids.

## PUBLIC API

| Surface | Members |
|---|---|
| `BattleEngine` | `new(setup)`, `advance()`, `get_request()`, `submit_action(choice)`, `submit_command_result(grade)`, `submit_reaction(result)`, `drain_events()`, `options_for(uid)`, `preview(choice)`, `preview_intent(uid)`, `forecast_next_round()`, `build_result()`, `get_state()`, `get_unit(uid)`, `is_finished()`, `get_outcome()`, `input_log` |
| Setup / results | `BattleSetup.from_encounter(...)`, `BattleLaunch.make(setup, return_scene)`, `BattleResult`, `BattleReplay.replay(setup, inputs)` |
| Simulation | `SimulationRunner.run_battle/run_batch`, `SimulationConfig`, `SimulationReport.flags()/to_markdown()/to_dict()`, `PartyAutopilot.choose`, `ExecutionSimulator.grade_command/react` |
| Content | `DefinitionRegistry.load_default()/validate()/make_library()/sorted_ids()`, `Database.registry/library` |
| Scenes | `BattleScene.start(launch)`, `add_toolbar_button(text, tooltip, callback)`, signals `finished(result)`, `restart_requested`, `setup_requested`; standalone launch via `SceneRouter.start_battle(launch)` |
| Widgets | `CommandWidget.begin(spec, name)` → `finished(grade)`; `ReactionWidget.begin(spec, action, points, attacker)` → `started`, `finished(result)` |
| Autoloads | `EventBus` (battle_finished, research_level_gained, settings_changed, game_saved, game_loaded, toast), `Settings.set_value/set_binding/reset_bindings/difficulty_profile/assist_profile`, `GameState.build_loadout/store_loadout/record_battle/research_levels`, `SaveManager.save_slot/load_slot/delete_slot/slot_info`, `SceneRouter.goto/take_payload/start_battle`, `AudioManager.play(cue)` |
| Input | `InputBindings.install/codes_for/key_label/code_label`, actions `hc_confirm hc_cancel hc_command hc_brace hc_evade hc_parry hc_info hc_up/down/left/right hc_log hc_menu` |

## SAVE IMPACT

- New save format **version 1** (`user://saves/slot_N.json`): loadout ids, bestiary points and
  sources, weapon mastery, and empty sections for inventory, companions, familiars, quests, regions,
  world choices, home upgrades and stats — present now so later milestones need no migration.
- `GameState.record_battle()` folds a `BattleResult` into bestiary research and weapon mastery
  (uses + Perfects). The sandbox records only when *Record progress* is ticked.
- Settings are global in `user://settings.cfg` (D-009); the sandbox remembers its form in
  `user://sandbox.cfg`. Neither affects save slots.

## TEST PROCEDURE

See [`docs/TESTING.md`](../TESTING.md). In short:

```sh
godot --headless --path . --import
godot --headless --path . --script res://tools/check_scripts.gd     # 153 scripts, 0 failed
godot --headless --path . --script res://tests/run_tests.gd         # 119 passed, 0 failed
godot --headless --path . --script res://tools/simulate.gd -- --encounter=all --exec=MISS,GOOD,PERFECT,MIXED --runs=50
```

plus the manual acceptance checklist in TESTING §5 (one row per GDD acceptance test).

## ACCEPTANCE CRITERIA STATUS (GDD "combat prototype")

| Test | Status | Evidence |
|---|---|---|
| Starter viability | Met in simulation; needs a human pass | see Simulation findings |
| Information | Met | defeat recap names the blow, the attacker and how it was met; full log; `test_log_formatter_and_recap_cover_a_lost_battle` |
| AI | Met | `test_healer_does_not_heal_trivial_damage`, `test_healer_heals_when_justified_and_explains_why` |
| Intent | Met | every intent shows category, targets, reactions, threat, countdown before it resolves; consumed-in-batch intents rebuilt from events (D-013) |
| Timing | Met by construction; confirm by playtest | assist changes windows/speed/auto-Brace only (`test_assist_does_not_change_ai_or_numbers`); see assist sims |
| Hard mode | Partly met | identical stats across tiers; Tactician wins fewer fights against weak execution; gap is limited by small enemy kits (Design Questions Q4) |
| Build | Partly met | dominance tables show no loadout dominating every matchup; the autopilot under-uses techniques (Q6) |
| Loot | Met for the slice | `test_rarity_is_not_raw_power`; Merciful Iron (Rare) has lower base power than Pilgrim's Edge |
| Environment | Met by design; confirm by playtest | Flooded Ground changes Evade (soaks you), Shock (chains), Burn (shorter) |
| Bestiary | Met | numbers, weaknesses, move names and "why" are research-gated; Inspect reveals at UNDERSTOOD |
| Corruption, Return loop | Not in M1 | later milestones |

## KNOWN LIMITATIONS

- **Placeholder presentation.** Units are procedural pixel silhouettes; icons are drawn shapes;
  SFX are synthesized placeholders; there is no music. `CombatantDefinition.sprite_frames` exists
  but `UnitView` does not use it yet.
- **No expedition context.** HP does not persist between fights, so normal encounters are winnable
  even with no execution at all; whether that is acceptable depends on expedition attrition (Q3).
- **Autopilot is a heuristic.** "PARTY NEVER USED" flags often mean the autopilot undervalues a
  technique, not that the option is dead. Treat them as prompts for human playtests.
- **Reactions are pass/fail.** The GDD's "Perfect Parry" is interpreted as a successful Parry (the
  Parry window is the tightest one). See Q2 for a graded alternative.
- **Batch playback.** The engine resolves a whole step before the presenter animates it. HP and
  Stagger bars follow the events, but status icons and Focus pips show the end-of-step state while a
  step animates.
- **Input latency is not calibrated.** Widgets grade the moment Godot delivers the input event; there
  is no per-player timing offset setting yet.
- **Text scale** updates theme-driven text immediately; a few explicitly sized labels update on the
  next screen.
- **Localization** is not wired: player-facing strings live in data and code, not in translation
  tables.
- **Untested on target hardware.** Visual checks ran under Xvfb/OpenGL; gamepad and Windows window
  modes were exercised through code paths only. CI is written but has not run because pushes to
  GitHub are currently refused (see the session notes).
- **Spore Fog is provisional** (GDD: "Blight accumulates gradually", but Blight is outside the slice
  statuses) — Q1.

## FUTURE EXTENSION POINTS

- **World slice:** `SceneRouter.start_battle(BattleLaunch)` + `return_scene`; overworld enemy groups
  are `EncounterDefinition`s; `Advantage` already supports ambushes; `GameState.record_battle()`.
- **Progression slice:** `ProgressState` already stores mastery and research; `WeaponDefinition.socket_count`
  and `ArmorDefinition.granted_actions` reserve modification and rule-granting gear; potions are data.
- **New mechanics:** append an `EffectType` / `ConditionType` / `TriggerType` / `ModifierStat`, add one
  `match` branch and a test; Chill and Blight have reserved status ids.
- **Art:** swap `UnitView`'s silhouette for `sprite_frames`; widgets read colours/shapes from data.
- **AI:** add `ConsiderationType`s; role defaults are data; difficulty gates are per consideration.
- **Tools:** the CLI emits JSON (`--out=…json`) for external balance analysis; more autopilot policies
  can be added beside SMART / BASIC_ONLY / RANDOM.
- **Accessibility:** input timing offset, colour-blind palettes (icons are already shape-coded),
  per-cue volume.

## SIMULATION FINDINGS

(filled in below from the M1 matrices)
