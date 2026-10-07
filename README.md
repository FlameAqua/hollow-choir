# Hollow Choir

A 2D top-down pixel-art RPG with **reactive turn-based combat**: read every enemy's intent, choose a
tactical action, then execute it with a short timing command and defend with Brace / Evade / Parry
in real time. Design canon lives in [`DESIGN_DOCUMENT.md`](DESIGN_DOCUMENT.md).

**Milestone 1 — Combat Foundation** (this branch) covers the roadmap's *Foundation*, *Combat toy* and
*Combat ecosystem* phases: a deterministic battle engine, data-driven content, utility AI with three
tactical difficulties, four execution assists, a playable battle UI, the CombatSandbox and headless
balance simulation. The overworld, hub, quests and progression UIs are later milestones.

## Running it

Requires **Godot 4.7.2** (standard build; no addons, no C#).

1. Open the folder in the Godot editor (or run the executable with `--path <repo>`); press **Play**.
2. Main menu → **Combat Sandbox**: pick a preset encounter or build one, choose loadout, conditions,
   difficulty, assist and execution mode, then **Start battle**. **Restart** is instant; **Simulate**
   runs the same setup 10–500 times and shows a balance report.
3. **Settings** has Tactical Difficulty and Execution Assist (independent, changeable any time),
   accessibility options, volumes and rebinding.

### Default controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Menus / targets | Arrows, Enter or Z confirm, Escape or X back | D-pad, A / B |
| Action command | Space or Z | A / X |
| Brace · Evade · Parry | A · S · D | LB · X · RB |
| Analysis details (hold) | Alt | Y |
| Battle log · Pause | Tab · Escape | Back · Start |

During an enemy attack a ring shrinks onto its target: press a reaction as it lands. The first
allowed key locks your choice; crossed-out reactions are unavailable for that move.

## Development

```sh
godot --headless --path . --import                                     # once per fresh checkout
godot --headless --path . --script res://tests/run_tests.gd            # 119 tests, ~15 s
godot --headless --path . --script res://tools/check_scripts.gd        # compile every script
godot --headless --path . --script res://tools/simulate.gd -- --encounter=all --exec=MISS,GOOD,PERFECT,MIXED --runs=100
```

CI (`.github/workflows/ci.yml`) runs the same steps on every push. Details: [`docs/TESTING.md`](docs/TESTING.md).

### Layout

```
data/            designer-editable content (.tres): actions, weapons, armor, enemies, encounters, configs…
src/core/        enums, display text, input bindings, settings data, content registry
src/data/        Resource definitions (the data contracts)
src/battle/      pure, deterministic combat: engine, rules, AI, previews, simulation (no Nodes)
src/progression/ save-facing progress models (bestiary, mastery, loadout)
src/save/        save migration
src/autoload/    EventBus, Database, AudioManager, Settings, GameState, SaveManager, SceneRouter
src/ui/          theme and battle widgets (presenter pieces, command and reaction widgets)
scenes/          battle scene, CombatSandbox, main menu, settings (thin roots; UI built in code)
tests/           headless test runner, fixtures, unit / content / UI suites
tools/           simulation CLI, script compile check, placeholder SFX generator
docs/            proposal, decision log, data contracts, testing, design questions, reports
```

### Documents

- [`docs/proposals/M1_COMBAT_FOUNDATION.md`](docs/proposals/M1_COMBAT_FOUNDATION.md) — technical proposal
- [`docs/reports/M1_COMBAT_FOUNDATION.md`](docs/reports/M1_COMBAT_FOUNDATION.md) — feature report (files, API, save impact, limitations)
- [`docs/DATA_CONTRACTS.md`](docs/DATA_CONTRACTS.md) — every Resource, the rules vocabulary, how to add content
- [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) — irreversible decisions and why
- [`docs/DESIGN_QUESTIONS.md`](docs/DESIGN_QUESTIONS.md) — open questions for the Director, with simulation evidence
- [`docs/TESTING.md`](docs/TESTING.md) — suites, simulation CLI, manual acceptance checklist

### Roles

Per the GDD collaboration table, ChatGPT is Game Director (design, balance models, UX specs, scope) and
Claude is Lead Gameplay Engineer (architecture, implementation, tests, tools). All M1 content numbers
are **provisional** and live in data so the Director can retune them without code changes.
