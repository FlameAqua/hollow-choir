# Testing

Owner: Claude (automated tests, simulation tooling). Acceptance criteria: the Director
(`DESIGN_DOCUMENT.md`, "Acceptance criteria for the combat prototype").

Everything runs on stock **Godot 4.7.2** with no addons. Examples use `godot`; on Windows substitute the
executable, e.g. `C:\Users\Adrian\Code\Games\Godot_v4.7.2-stable_win64.exe` (the `_console.exe`
variant prints to the terminal).

## 1. One-time setup per checkout

```sh
godot --headless --path . --import
```

A fresh checkout has no `.godot/` class cache, so `--script` runs cannot resolve `class_name`s until
the project has been imported once. Re-run it after adding new scripts.

## 2. Automated suites

```sh
godot --headless --path . --script res://tests/run_tests.gd                  # everything (~40 s)
godot --headless --path . --script res://tests/run_tests.gd -- --filter=ui   # substring filter
godot --headless --path . --script res://tools/check_scripts.gd              # compile every script
```

The runner exits with code 1 on any failure. A test also fails when it causes an engine or script
error it did not declare with `expect_engine_errors(n)` — a `push_error` or a runtime error inside
game code is never silently ignored. (Some tests deliberately trigger errors, e.g. corrupt saves; the
console shows those, the test counts them.) Expected diagnostics in a passing full run: four
invalid-save errors (missing/future `save_version`, a corrupt file and its JSON parse error) and one
`BattleEngine: rejected action (Needs 5 Focus)` warning. Anything else is unexpected.

Run the suite alone. Widget tests use wall-clock timing, so a parallel Godot process can make them
flaky. Headless probes and simulations can run in parallel.

### Isolated user data (QA launcher)

Godot reads `user://settings.cfg` (text size, bindings, window mode…) at startup, and some tests
and captures write `user://` files. On a development machine, wrap any command in the QA launcher so
each run uses a fresh, throwaway user-data home:

```sh
python tools/qa_godot.py --headless --script res://tools/check_scripts.gd
python tools/qa_godot.py --headless --script res://tests/run_tests.gd -- --filter=test_v02_ui
```

It takes the same Godot arguments (`--path` is added). Choose the executable with `--godot PATH`
or the `GODOT` variable. Use `--home DIR` to reuse a home, or `--keep-home` to inspect one. The test
runner and capture tool print `User data: …` first and stop with exit code 1 if the launcher asked
for isolation that did not take effect. CI runners start clean, so CI calls Godot directly.

### Rendered captures

`tools/capture_battle.gd` renders the real scenes for visual review. It needs a display, not
`--headless`. Its header lists every state and option, including opening/condition announcements,
held preparation beats, inspection, recipient review and Setup/resume:

```sh
python tools/qa_godot.py --hidden --rendering-method gl_compatibility --script res://tools/capture_battle.gd -- \
    --state=prepare-reaction --scale=2.0 --out=res://docs/reports/<pass>/reaction_200.png
```

Captures are fixtures. To hold a moment, the harness pauses presentation tweens, freezes widget
clocks and supplies synthetic pointer/focus input. Report them as such. They do not measure timing
skill, input latency or human comprehension. It never edits settings files, saves, rules or art.

| Suite | What it guards |
|---|---|
| `unit/test_damage.gd` | GDD damage formula and tooltip example, grade multipliers, Guard, weakness/resistance, PURE, variance, weak point / Broken / PRECISION, Stagger bonuses, modifier order, preview = resolution |
| `unit/test_engine_flow.gd` | state machine, initiative and ties, ambush, victory/defeat, MISS never cancels an action, Focus economy, illegal options with reasons, determinism, replay, cooldowns, Inspect, Guard |
| `unit/test_reactions.gd` | reaction windows and specs, Brace/Evade/Parry outcomes, statuses blocked by Evade/Parry only, disallowed reactions, auto-Brace and grade floor, assist never changes AI or numbers, one window for area attacks |
| `unit/test_commands.gd` | grading boundaries for TIMING / HOLD_RELEASE (overcharge) / RHYTHM (anti-mash), assist and equipment window modifiers, clamping, assist floor |
| `unit/test_statuses.gd` | Wet vs Burn (wash / douse), Burn ticks, stacks and refresh, durations, Shock and Wet conduction, Bleed charges / strenuous / turn cap, immunity, duration modifiers, cleanse |
| `unit/test_stagger_and_intents.gd` | break → skipped turn → recovery with growth, break rewards, channels (telegraph, release, interrupt, Story extra turn, uninterruptible), retarget-by-rule, Intercept, intent previews |
| `unit/test_triggers.gd` | familiar triggers and round limits, relations, grade-conditioned triggers, chain non-recursion, depth bound, NEXT_ACTION buffs, boss phases, condition replacement, items |
| `unit/test_ai.gd` | the GDD AI test (healer heals only when justified, explains why), difficulty-gated considerations, noise by tier, legality, Tactician combos and channel risk, Story lethal-stacking courtesy, role defaults |
| `unit/test_simulation.gd` | batch metrics consistency, better execution ⇒ less damage, never-used flags, deterministic sims, policies, reaction choice vs skill |
| `unit/test_save_and_settings.gd` | progress JSON round trip, atomic writes, migrator version guards, corrupt files, battle results → bestiary/mastery, settings persistence and assist overrides, clamping, bindings round trip, reaction key collisions, loadout from ids |
| `content/test_content.gd` | every `.tres` validates, vertical-slice scope, readable enemy telegraphs, boss covers the required systems, rarity is not raw power, every loadout/encounter builds and finishes, random-policy fuzzing |
| `ui/test_battle_ui.gd` | whole battles through the real `BattleScene` (autopilot + simulated execution, accelerated `Engine.time_scale`), keyboard action and target selection, every command widget's input → grade wiring, reaction locking / struck-through keys / no input, log + defeat recap, research-gated unit info, binding labels |
| `ui/test_presentation.gd` | M1.1 knowledge filtering: unknown affinities hide every derived number, a revealing hit unlocks one damage type, Inspect reveals without changing results, per-target area previews, honest status qualifiers, previews consume no RNG/Focus, research-gated intent labels, channel countdowns, reaction readouts read the rules |
| `ui/test_icon_ui.gd` | icon-first UI: immediate inspector with short-gap retention, icon/reaction legality from the filtered readouts, full-size cast and supply costs, every semantic icon and migrated art loads, four wide enemies keep disjoint lanes, reaction visuals share the graders' windows |
| `ui/test_stage_art.gd` | stage refresh: the defeated pose follows the presented UNIT_DEFEATED (not the HP tween), corpses stay addressable but never living targets, nine static dead poses, shared footing and compact plates, enlarged title focus/scroll |
| `ui/test_presentation_boundaries.gd` | playback never runs ahead of presented events (timeline, condition ribbon, forecast, intent rail including Inspect mid-batch), target review pins no popup and leaves targets clickable, an open unit card follows presented cover, the sandbox setup page only covers a paused battle, the inspector reads only its own battle, unusable options explain themselves, the reaction cue appears only when a press would be read, portrait/corpse/Broken+Exposed fallbacks draw |
| `ui/test_v02_ui.gd` | modifier/Alt hover stability and one card over the stage, timeline-to-action hover recovery, source/card overflow scrolling, wheel ownership in either handler order (actions, supplies, enemy sources), fixed Practice footer at five resolutions and three text sizes, individual health/break/reaction explanations and displayed-intent cards, explicit sole-recipient review, Hold/Toggle/Always, support cards, condition docking, familiar footing, the preparation beat for all command types and reactions, announcement fitting and hover suppression, deliberate confirm/rebinding mirrors, global resolution persistence/fallback |

V0.2 supersedes the older pinned-inspection expectation: target review retains facts in the dock
without automatically pinning a popup. Setup owns one overlay, disables covered battle input and
resumes directly on close. See [current UI contract](design/V02_UI_INTERACTION.md).
The [screenshot follow-up](design/V02_UI_FOLLOWUP.md) adds sole-target Intercept/cancellation,
button-hover wheel ownership, Alt release over the card, native font sizes under transformed
inspection, named threat bounds and structured ledger/knowledge isolation. Reaction glyphs are
tested within move inspection; the stage intentionally has none. The solo keyboard test now
requires separate action and recipient confirmation.

UI tests are coroutines (`await` frames/signals); the runner awaits each test. Widget tests inject
input at a chosen moment by back-dating the widget's start time instead of waiting in real time.

### V0.3 additions

`ui/test_v03_field_guide.gd` guards save-only research levels, later-phase cards, changed thresholds,
existing progression round trips, unknown saved IDs, read-only/focus/scroll behavior at 100/150/200%,
empty saves and two visible 200% reaction-help lines. `unit/test_music.gd` covers shuffle bags,
private RNG, same-cue idempotence, version/tone fallback, end scheduling, real-time fades, rapid
requests, missing-cue cleanup, imported music and Music-bus mute. Headless audio tests exercise
transport state; they do not establish audible joins, SFX intelligibility or exact device latency.
`ui/test_audio_lab.gd` drives the real version/tone buttons into the intense example, checks the
same-timestamp switches, ending-preview countdown and read-only settings/progress, and verifies initial focus/scroll and fixed Back
at 100/150/200%. Music tests also cover manual audition validation and shuffle history after tone
switches. It also drives native pointer/keyboard seek input. Music tests check source offsets,
shorter targets, nonfinite seek rejection, seeks during fades, rapid switches without mix-age drift
and overlapping player positions after audio frames. `test_import_music.py` protects originals,
verifies metadata renames and archived swaps,
and rejects unknown cues/duplicate formats. Import usage: [music instructions](audio/MUSIC_IMPORT.md).

Run media preparation tests with Python 3.11+ and FFmpeg/FFprobe:

```sh
python -m unittest discover -s tests -p 'test_*.py'
python tools/prepare_music.py
```

The Python tests create a temporary tone under `.godot/qa`, perform real decode/trim/replacement,
check source preservation and cached runs, and cover future version/tone names and duplicate IDs.
They also reject version zero and repair legacy cached codec/channel metadata without re-encoding.
Final V0.3 release checks: nine Python tests and 212 Godot tests / 1,976 assertions passed;
see [Director acceptance](reports/V0_3_DIRECTOR_ACCEPTANCE.md).
Current exports are cached by source/export hashes; rerunning preparation leaves media unchanged.
The active library follows inbox additions/removals; old exports remain unselected recovery files.

Capture states `field-guide`, `field-guide-empty` and `weapon-practice` use explicit in-memory
progress fixtures without save writes. V0.3 captures and their limits are in
[the report](reports/V0_3_FIELD_GUIDE_AND_AUDIO.md). On a restricted Windows host, use a fresh
`--home .godot/qa/<run-name>` if the OS temporary folder cannot be written by Godot.
The `audio-lab` capture selects the supplied intense example and seeks to 45 seconds. Optional
`--preview-ending` shows the real countdown; `--audio-controls` scrolls the playhead into view.
These fixtures do not establish audible transition quality.

## 3. Balance simulation (CLI)

```sh
godot --headless --path . --script res://tools/simulate.gd -- \
    --encounter=all --exec=MISS,GOOD,PERFECT,MIXED --difficulty=ADVENTURER --runs=100 --seed=1
```

Options: `--encounter`, `--loadout` (default: `GameDefaults.simulation_loadouts`), `--exec`,
`--difficulty`, `--assist`, `--policy=SMART|BASIC_ONLY|RANDOM`, `--runs`, `--seed`, `--research=LEVEL`,
`--detail` (full report per batch), `--out=user://report.md|.json`. Each batch prints win rate,
rounds (mean/p90), damage taken, Focus, breaks, and flags: `OVERLONG`, `TOO SHORT`, `TIMEOUTS`,
`UNFAIR?`, `TRIVIAL?`, `AI NEVER USED`, `PARTY NEVER USED`; the run ends with a win-rate dominance
table per matchup. The CombatSandbox's **Simulate** button runs the same batch for its current form.

## 4. Reproducing a bug

Battles are deterministic: `BattleResult.input_log` plus the setup (seed included) reproduce a fight
exactly with `BattleReplay.replay(setup, inputs)` (`test_replay_reproduces_battle` shows usage). The
sandbox shows the seed on the result screen; enter it in the Seed field to replay the same RNG.

## 5. Manual checklist (CombatSandbox)

Main menu → **Combat Sandbox**. Each line maps to a GDD acceptance test; record the result and seed.

| GDD test | How to check in M1 | Supporting automation |
|---|---|---|
| Starter viability | Preset *The Mirebell Cantor*, loadout *Starter: Sword*, Manual. Beat it. | sims: boss winnable with GOOD/MIXED execution |
| Information | Lose a fight on purpose; read the result screen recap and the log (Tab). Can you say what killed you? | `test_log_formatter_and_recap_cover_a_lost_battle` |
| AI | *Mire Shrine*: watch the Bogwife; she should not heal chip damage. Turn on *Show AI reasoning* and hover her intent. | `test_healer_*` |
| Intent | Every enemy shows its plan, targets, reaction icons and threat before it acts; channels show an hourglass. | `test_intent_preview_reports_reactions_and_threat` |
| Timing | Same fight at *Assisted* vs *Standard*: assisted still needs the right tactical calls (break channels, Brace vs Evade). | `test_assist_does_not_change_ai_or_numbers`, sims by assist |
| Hard mode | *Bramble Den* at Story / Adventurer / Tactician with Show AI reasoning: Tactician focuses targets, sets up combos, avoids breakable channels; HP is identical. | `test_difficulty_gates_considerations`, `test_tactician_*`, sims by difficulty |
| Build | Same encounter with each starter loadout: the best moves differ (Bleed vs Hammer, Bow weak points, Sword parries). | sims: dominance table, never-used flags |
| Loot | *Pilgrim's Edge* (Common) vs *Merciful Iron* (Rare, lower base power): the rare one changes a rule instead of adding damage. Is either always better? | `test_rarity_is_not_raw_power` |
| Environment | *Fen Patrol* (Flooded Ground): Evade soaks you, Shock conducts through Wet, Burn is weaker. Did you change a decision? | `test_shock_conducts_through_wet` |
| Bestiary | Same fight with *Bestiary knowledge* Unknown vs Understood: exact numbers and weaknesses appear. Inspect reveals them mid-fight. | `test_unit_info_reveals_affinities_only_with_knowledge`, `test_inspect_reveals_and_awards_research` |
| Corruption / Return loop | Not in M1 (world-state and hub milestones). | — |

Accessibility spot checks: Settings → text size, Reduce flashing (hit flashes turn dark), Screen
shake off, Damage numbers off, Analysis details *Always*, rebind Brace/Evade/Parry and confirm the
reaction prompt shows the new keys, Pause before reactions on.

## 6. Continuous integration

`.github/workflows/ci.yml` downloads Godot 4.7.2 (Linux), imports the project, compiles every script,
runs the full suite and a short simulation smoke run on every push and pull request.
