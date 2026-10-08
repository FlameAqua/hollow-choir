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
godot --headless --path . --script res://tests/run_tests.gd            # 120 tests, ~15 s
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

- [`docs/design/M1_1_COMBAT_CLARITY.md`](docs/design/M1_1_COMBAT_CLARITY.md) — core combat clarity contract; layout revised by the icon-first UI contract
- [`docs/design/visuals/combat_study.html`](docs/design/visuals/combat_study.html) — local three-state UI study (illustrative, not a game build)
- [`docs/art/briarfen_v01/README.md`](docs/art/briarfen_v01/README.md) — v01 source provenance and individual idle packaging
- [`assets/art/STYLE_GUIDE.md`](assets/art/STYLE_GUIDE.md) — canonical materials, silhouettes, pixel targets and accessible UI conventions
- [`docs/art/briarfen_v02/README.md`](docs/art/briarfen_v02/README.md) — integrated existing-enemy art and shared combat textures
- [`docs/briefs/BRIARFEN_V02_ART_INTEGRATION.md`](docs/briefs/BRIARFEN_V02_ART_INTEGRATION.md) — bounded art resource and UI texture handoff
- [`docs/reviews/M1_DIRECTOR_REVIEW.md`](docs/reviews/M1_DIRECTOR_REVIEW.md) — pillar review, source findings and validation limits
- [`docs/briefs/M1_1_IMPLEMENTATION.md`](docs/briefs/M1_1_IMPLEMENTATION.md) — bounded Claude handoff

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

Current UI: [icon-first contract](docs/design/ICON_FIRST_COMBAT_UI.md), [runtime review](docs/reports/ui_refresh/README.md), [art library](assets/art/README.md).

## Art and audio preparation

[Shared frame/backdrop direction](docs/design/ENVIRONMENT_FRAME_ART.md),
[music folder contract](assets/audio/AUDIO_CONTRACT.md), and
[Suno requests](docs/audio/SUNO_REQUESTS.md) cover the latest asset preparation.
Runtime assignment/music playback remain separate from this delivery.
