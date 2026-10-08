# Hollow Choir

A 2D top-down pixel-art RPG with **reactive turn-based combat**: read every enemy's intent, choose a
tactical action, then execute it with a short timing command and defend with Brace / Evade / Parry
in real time. Design canon lives in [`docs/DESIGN_DOCUMENT.md`](docs/DESIGN_DOCUMENT.md).

**Version 0.3.0** ([release notes](docs/RELEASE_NOTES.md)). The playable build is the combat
foundation: a deterministic battle engine, data-driven content, utility AI with three tactical
difficulties, four execution assists, the V0.2 combat UI, Practice/Lab and headless balance
simulation, a saved-knowledge Field Guide and randomized music playlists. The M1.1 human clarity
gate (fresh-player READ/REACT sessions) is still open. The
overworld, hub, quests and progression UIs are later milestones.

## Running it

Requires **Godot 4.7.2** (standard build; no addons, no C#).

1. Open the folder in the Godot editor (or run the executable with `--path <repo>`); press **Play**.
2. Title → **Combat Sandbox**. **Practice** offers curated encounters with fixed, honest rules.
   **Lab** builds any fight (enemies, conditions, equipment, knowledge, simulated execution,
   autopilot) and **Simulate** runs it 10–500 times. Inside a battle, **Setup** returns to these
   pages and **Restart** replays the fight.
3. **Settings** covers Tactical Difficulty and Execution Assist (independent, changeable any time),
   window size, text size (75–200%), accessibility options, volumes and rebinding.
4. **Field Guide** shows saved species research and weapon practice. Practice remains unrecorded;
   use Lab's **Record progress** opt-in to populate the guide. Opening it never grants progress.

### Default controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Menus / targets | Arrows; Enter confirms; Escape, X or Backspace go back | D-pad; A confirms, B goes back |
| Action command | Space or Z | A / X |
| Brace · Evade · Parry | A · S · D | LB · X · RB |
| Details (hold by default; Toggle/Always in Settings) | Alt | Y |
| Battle log · Pause | Tab · Escape | Back · Start |

Hover or focus anything for an immediate explanation in one contextual card; hold Details to
expand it. A targeted action always asks for its recipient: click it or press Confirm, or go back
without spending anything. Before each manual command or reaction, its real meter or ring appears
for a short, motionless preparation beat. During an enemy attack a ring shrinks onto its target:
press a reaction as it lands. The first allowed key locks your choice, and crossed-out reactions
are unavailable for that move. Saved custom bindings always take precedence over these defaults.

## Development

```sh
godot --headless --path . --import                                     # once per fresh checkout
godot --headless --path . --script res://tools/check_scripts.gd        # compile every script
godot --headless --path . --script res://tests/run_tests.gd            # full suite, ~40 s
godot --headless --path . --script res://tools/simulate.gd -- --encounter=all --exec=MIXED --runs=10 --seed=1
```

On a development machine, run tests and captures through `python tools/qa_godot.py …` (same Godot
arguments). It gives each run a throwaway user-data home, so your own settings, saves and Lab
choices neither affect results nor get overwritten. CI (`.github/workflows/ci.yml`) runs the
import, script check, full suite and simulation smoke run on every push. Details, the suite map,
rendered captures and the manual checklist: [`docs/TESTING.md`](docs/TESTING.md).

### Layout

```
data/            designer-editable content (.tres): actions, weapons, armor, enemies, encounters, configs…
src/core/        enums, display text, input bindings, settings data, content registry
src/data/        Resource definitions (the data contracts)
src/battle/      pure, deterministic combat: engine, rules, AI, previews, simulation (no Nodes)
src/progression/ save-facing progress models (bestiary, mastery, loadout)
src/save/        save migration
src/autoload/    EventBus, Database, AudioManager, Settings, GameState, SaveManager, SceneRouter
src/audio/       typed playlists and two-deck, real-time music mixer
src/ui/          theme and battle presentation (readouts, ledger, inspector, cards, timing widgets)
scenes/          battle scene, CombatSandbox (Practice/Lab), main menu, settings (UI built in code)
tests/           headless test runner, fixtures, unit / content / UI suites
tools/           script check, simulation CLI, QA launcher, capture tool, placeholder SFX generator
docs/            design document, decision log, contracts, briefs, reports, release notes
assets/          art (by purpose and region) and audio (see the audio contract)
```

### Documents

Current authority (read first):

- [`docs/DESIGN_DOCUMENT.md`](docs/DESIGN_DOCUMENT.md) — canonical GDD; its opening sections list current authority
- [`docs/design/V02_UI_INTERACTION.md`](docs/design/V02_UI_INTERACTION.md), [`V02_UI_FOLLOWUP.md`](docs/design/V02_UI_FOLLOWUP.md),
  [`V02_SUPPORT_PRESENTATION.md`](docs/design/V02_SUPPORT_PRESENTATION.md) and
  [`V02_PRE_PUSH_POLISH.md`](docs/design/V02_PRE_PUSH_POLISH.md) — current combat UI contracts
- [`docs/DATA_CONTRACTS.md`](docs/DATA_CONTRACTS.md) — every Resource, the rules vocabulary, presentation data, save formats
- [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) — decisions and why
- [`docs/TESTING.md`](docs/TESTING.md) — suites, simulation CLI, QA launcher, captures, manual checklist
- [`assets/art/STYLE_GUIDE.md`](assets/art/STYLE_GUIDE.md) and [`assets/audio/AUDIO_CONTRACT.md`](assets/audio/AUDIO_CONTRACT.md) — art and audio contracts
- [`docs/reports/V0_2_1_ENGINEERING_CLEANUP.md`](docs/reports/V0_2_1_ENGINEERING_CLEANUP.md) — latest engineering report
- [`docs/design/V03_FIELD_GUIDE_AND_AUDIO.md`](docs/design/V03_FIELD_GUIDE_AND_AUDIO.md) and
  [`docs/reports/V0_3_FIELD_GUIDE_AND_AUDIO.md`](docs/reports/V0_3_FIELD_GUIDE_AND_AUDIO.md) — V0.3 scope and evidence

History and preparation:

- [`docs/design/M1_1_COMBAT_CLARITY.md`](docs/design/M1_1_COMBAT_CLARITY.md) — core combat clarity contract (layout superseded by the V0.2 contracts)
- [`docs/reports/v02_ui/README.md`](docs/reports/v02_ui/README.md) — V0.2 UI evidence and captures
- [`docs/reports/M1_1_ENGINEERING_REVIEW_2026_10_08.md`](docs/reports/M1_1_ENGINEERING_REVIEW_2026_10_08.md) — M1.1 engineering review
- [`docs/reviews/M1_DIRECTOR_REVIEW.md`](docs/reviews/M1_DIRECTOR_REVIEW.md) — pillar review, source findings and validation limits
- [`docs/playtests/M1_1_SESSION_PACK.md`](docs/playtests/M1_1_SESSION_PACK.md) — human playtest protocol (blank sheets are intentional)
- [`docs/proposals/M1_COMBAT_FOUNDATION.md`](docs/proposals/M1_COMBAT_FOUNDATION.md) and [`docs/reports/M1_COMBAT_FOUNDATION.md`](docs/reports/M1_COMBAT_FOUNDATION.md) — original M1 proposal and report
- [`docs/DESIGN_QUESTIONS.md`](docs/DESIGN_QUESTIONS.md) — resolved M1 questions with simulation evidence
- Art provenance: [`docs/art/briarfen_v01/README.md`](docs/art/briarfen_v01/README.md),
  [`docs/art/briarfen_v02/README.md`](docs/art/briarfen_v02/README.md), [`docs/art/CINDER_PUP_V01.md`](docs/art/CINDER_PUP_V01.md)

### Roles

ChatGPT is Game Director and owns UI/UX direction, art consistency and UI integration. Claude is
Lead Gameplay Engineer and owns combat architecture, deterministic rules, the presentation-ledger
contract, tools and tests. Agent prompts: [`docs/CHATGPT_PROMPT.md`](docs/CHATGPT_PROMPT.md),
[`docs/CLAUDE_PROMPT.md`](docs/CLAUDE_PROMPT.md). All content numbers are **provisional** and live
in data, so the Director can retune them without code changes.

## Art and audio

[Shared frame/backdrop direction](docs/design/ENVIRONMENT_FRAME_ART.md),
[music folder contract](assets/audio/AUDIO_CONTRACT.md), and
[Suno requests](docs/audio/SUNO_REQUESTS.md) describe the asset pipeline. All six supplied songs are
approved by Adrian and integrated: two base versions each for title, Briarfen battle and Mirebell
boss, plus a v01 intense battle mix. **Audio Lab** on the title lets you select songs, versions,
tones at the current timestamp, seek by clicking/dragging the playhead, and preview endings with
a countdown before automatic rotation. Next version starts another mix from zero.
Versions shuffle without immediate repeats and overlap at their endings; scene changes crossfade.
Same-cue restarts preserve playback. Music and SFX retain separate volume/mute controls.

Import one or more files with `python tools/import_music.py "path/to/file.m4a" "path/to/other.m4a"`.
It normalizes names, preserves external originals and rebuilds playlists; `--replace` archives
previous audio before a deliberate swap. See [music import instructions](docs/audio/MUSIC_IMPORT.md).
After removing inbox files, run `python tools/prepare_music.py` (Python 3.11+, FFmpeg/FFprobe), then
let Godot import. Tone groups
such as `_calm` and `_intense` support future full-mix transitions. Simultaneous synchronized layers
require aligned arrangements and a later adapter; current tracks have no verified beat alignment.
