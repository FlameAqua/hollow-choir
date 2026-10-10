# Testing

Owner: Claude (automated tests, simulation tooling). Acceptance criteria: the Director
(`DESIGN_DOCUMENT.md`, "Acceptance criteria for the combat prototype").

**Current display policy:** [fixed presets](design/DISPLAY_PRESETS.md). Qualify the canonical
1280×720 layout and supported output presets; no independent font-size or arbitrary-width matrix.
Older enlarged-text regressions/captures below record the V0.3 baseline and do not describe a current
player setting. Capture tooling uses `--size=<supported preset>`; `--scale` is retired.

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
console shows those, the test counts them.) Expected diagnostics in a passing full run (V0.5 UI,
10 October 2026): nine invalid-save errors and six warnings.
- Six errors come from `test_save_and_settings`: missing and future `save_version`, a corrupt file
  and its JSON parse error, and two saves without a data section.
- Three errors come from `test_world_journey_setup` loading its damaged and newer slots.
- One warning is `BattleEngine: rejected action (Needs 5 Focus)`.
- Five are `WorldSession` sanitation warnings from `test_world_session`'s invalid-anchor case.

Anything else is unexpected.

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
The home also holds the editor/resource cache (`LOCALAPPDATA` / `XDG_CACHE_HOME` → `<home>/cache`):
editor runs no longer write thumbnails or class-doc caches into the developer's own
`%LOCALAPPDATA%\Godot`, and the guard refuses a run whose cache escaped the home.

**Windows “Safe save failed” (editor only).** Godot's editor writes files through a temporary file
and an atomic replace. When the replace cannot complete within its retry window (read-only or
locked target, antivirus, a sandbox that denies replacing files) it prints this diagnostic from
`file_access_windows.cpp`, keeps the previous file and leaves `<file><digits>.tmp` beside it.
Imports still complete. Headless `--import` writes no tracked project file; a windowed editor
session re-saves `project.godot`, which is kept in the editor's canonical form so its bytes do not
change. Do not suppress the diagnostic by disabling safe save or security settings; find the
stray `.tmp` to identify the file.

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

### V0.4 world additions

`world/test_world_session.gd` guards the save boundaries: old slots without a `world` section keep
research/mastery/loadout and start at the square, invalid anchors and unknown IDs recover without
inventing unlocks, one entry is written before launch, victory commits once (duplicate token is a
no-op), a failed write publishes nothing and can be retried, retry rebuilds the identical setup and
battle fingerprint, quitting mid-battle resumes at the approach, and the bell/latch flags stay
independent. `world/test_world_rules.gd` covers derived objectives, knowledge-filtered encounter
cards and maps, latch sides, four-facing stability, separate world bindings and the area scene
contract (layers, landmark points, anchors outside triggers/walls/engage radii, closed boundary).
`world/test_world_host.gd` drives the real host and scenes: feet collision, walk-follows-displacement,
portal round trip without bounce, unarmed triggers, modal/held-input gates, focus-loss pause,
Cancel/Engage/Leave battle, victory/failed-write/defeat-retry/return paths, far-side latch, home
consequence, bench → next entry, Field Guide/Settings return to the paused world and map leak checks.
World captures (`tools/capture_world.gd`, states listed in its header) are fixtures: they seed an
in-memory world state and open modals directly. Rebuild the editable area scenes only deliberately:
`tools/build_world_areas.gd` refuses to overwrite authored scenes without `--force`.

Director integration adds `world/test_world_presentation.gd`: modal action bounds/focus containment,
every owned starter weapon's complete text, pointer/Confirm map selection without saving or travel,
focus scrolling to the last charted place, physical traversal of the outside loop to the still-closed
far-side latch without an encounter card, integer art/camera alignment with continuous feet, and
the restored town map description. Run `--filter=world` for all world suites.
`world/test_world_journey.gd` walks the real feet body along every authored link in both dressed
areas (bench, Bellkeeper, gate, main approach past the patrol card, guard card and committed
victory, bell, outside loop, overlook, far side, opened short return, home) and checks that every
landmark and link reached the last write. `test_bench_choice_survives_a_failed_save_and_retry`
guards the save-failure retry path. `unit/test_qa_isolation.gd` and `tests/test_qa_godot.py` cover
the launcher's user-data/cache isolation; the guard test deliberately prints one
`QA isolation failed: cache is …` line while proving the rejection (expected, not an error).
The expanded world capture tool includes both encounter cards, all bench weapons, full/restored
maps, facade/gate views and synthetic victory/defeat/save-failure cards; see its header.
[Director evidence](reports/V0_4_DIRECTOR_ACCEPTANCE.md) separates these fixtures from human acceptance.

### V0.4 third playtest additions (Claude)

`world/test_world_collision.gd` checks authored prop footprints against the visible art with the
real feet body. Ground masks come from each prop's own sprites (willow trunk/root flare, bell
footings and roots, listening stones, lamp plinth, latch gateposts). Hollow walks at every prop
from sixteen directions: the feet box may touch at most 8 base pixels on the way in or at rest, and
an approach stopped by the prop must end within 6 px of the art (no invisible wall). It also checks
that all 21 willows use `scenes/world/footprints/willow_roots.tres`, that canopy ground stays
walkable and behind-the-trunk stops stay Y-sorted behind, that the open gateposts keep the short
return passable while the closed gate bars it, and that every safe anchor fits Hollow in both
states. Mutation check: against the pre-pass scenes, four of its six tests fail on the reported
defects. `world/test_world_reset.gd` covers Menu → Reset journey: one write, journey-only reset,
kept research/mastery/loadout/inventory/statistics/settings, failed write and Retry, Cancel as
default and Back, repeated presses, token continuity across the reset, fresh-session reload and a
real write to a throwaway slot only. `ui/test_target_switching.gd` drives real clicks and keys
through recipient review: enemy → enemy, enemy → ally item, ally → one-recipient ally action,
ally → enemy item, → self (submits), unavailable rows, the pending action itself, hover and Details,
Back, device-specific help, a fallen remembered recipient, single submission and nothing spent
before it, and focus returning from the battle log. `ui/test_inspection_dock_tour.gd` follows the
pointer from a potion to an enemy, its intent and the empty stage, and scrolls an overflowing card
both ways from its source and inside the dock.

Collision evidence: `tools/capture_collision.gd` renders native 4x close-ups with debug collision
shapes after walking the real feet body at a prop (`--shot=<name>`; shots in its runner). Run it
against an older tree with `--path` for before/after pairs. `tools/probe_willow_footprint.gd` now
reports polygon footprints and writes to `--out` (default: the third-pass report folder).
`capture_battle.gd --state=target --action=<id> --then=<id>` captures an action switch during
review; `capture_world.gd --state=reset` captures the Reset journey confirmation.

Exit-time "ObjectDB instances leaked / resources still in use" in focused runs and captures came
from audio, not game objects: a battle-music deck or cue voice still mixing when the process quit
keeps its stream playback referenced by the audio server. The test runner and capture tools now call
`AudioManager.silence()` and let the mixer drop those playbacks before quitting. A deliberately
orphaned node is still reported, so real ownership leaks remain visible.

### V0.4 fifth playtest additions (Claude)

`ui/test_battle_pause.gd` covers Adrian's Pause rule (9 October 2026). Pause opens during
recipient review and returns to the same review, and the reviewed action keeps its selected frame.
Paused playback, announcements and floating text stand still, and Resume continues at once. While a
command or reaction window is open (preparation beat included), the Pause key, controller Start,
the toolbar button and a host's Setup are all ignored, not queued, and the window's clock never
stops. Tab cannot reopen the log under Pause or Help. A decided or host-owned outcome cannot be
paused into a retreat, and a frozen battle opens no new request. Its live-window fixtures simulate
focus returning, because a real desktop focus change during a rendered run holds the preparation
beat by design.
`ui/test_fifth_engineering.gd` covers:
- a pin surviving recipient review and target hover until a boundary;
- field help naming the player's Details key/mode, conditional weak-point and engine Focus sources;
- announcement fades at Combat Speed;
- an enemy turn banner showing its intent-badge number (Thornhound Pack);
- the eight-slot grid with empty, inert frames for unused slots;
- every shipped action name fitting its grid cell (`KNOWN_CLIPPED_NAMES` lists the measured names
  awaiting a layout fix).

`unit/test_action_capacity.gd` holds every protagonist × weapon × most action-granting armor and
every companion to `PartyLoadout.MAX_ACTIONS` (V0.5A; `ActionMenu.CAPACITY` is the same constant). `unit/test_app_icon.gd` checks that the project uses the
v02 icon (built by `tools/prepare_icon_alpha.gd`): transparent outside the frame in the PNG and all
seven ICO sizes, opaque inside, colours identical to v01. `world/test_world_host.gd` adds Pause
being ignored in a world battle's reaction window followed by Leave battle, and the town → Reedway
→ battle → return music cues.

### V0.5A salvage and preparation (Claude)

Run `--filter=reward`, `--filter=preparation` and `--filter=salvage` while working on this area.
- `unit/test_reward_rules.gd`: the shipped reward table (from data, so tuning the quantities only
  touches its first test), catalog validation of malformed rewards (id format, empty/null items,
  kinds, counts, unregistered or copied references, sources, duplicate ids, totals over the stack
  limit), saturating grants, never-duplicated equipment, claim-id order, readouts as plain public
  data, and `ProgressState.from_dict()` sanitizing malformed claims, counts, equipment and loadouts.
- `world/test_world_rewards.gd`: production `WorldSession` acceptance cases. Patrol, guard and bell
  grant once in the same write as the accomplishment; duplicate results, failed writes with Retry,
  Reset journey replays and reloads never duplicate; defeat, leaving, interrupted entries, Practice
  and the recording Lab grant nothing; older saves catch up only what their journey proves, once,
  also after a failed write; malformed saved data creates nothing.
- `world/test_world_preparation.gd`: the station context gates every command (and a pending
  entry blocks them), typed rejections change nothing, optional slots empty, starter weapons stay,
  a failed equip write is retried once, an over-limit loadout (a synthetic two-action charm) is
  rejected whole, every owned shipped choice fits, older loadouts keep valid gear and repair the
  rest once, readouts match ownership and are copies, and the restoration charm reaches the next
  entry and a real Fen Patrol battle: Fen Water Flask (Wet) then Spark (Shock) fires Grounding once
  and adds exactly its Stagger (compared with the same captured battle without the charm), while a
  captured entry and its retry keep their loadout.
- `world/test_world_salvage_host.gd` drives the real `WorldHost`: world-entry catch-up writes once
  and a failed write shows the save-failure card before play; the bench interaction owns the station
  context (kept under the failure card, ended by Leave or any return to exploration); the victory
  card and the rung bell show each receipt once.

Director integration extends `test_world_salvage_host.gd` with the saved catch-up notice and
no repeat after reload; first-clear preview without grants; actual charm button equip, failed
write/Retry, removal and restored focus; read-only Inventory from preparation and pause; visible
disabled overflow reasons and stale-choice rejection keeping the station open; failed bell
restoration with no receipt until Retry; empty-slot navigation and native Page Up/Down scrolling;
the last compact catch-up receipt reachable without extra reading buttons; and first-clear salvage visible
on the initial encounter card.
The existing world presentation tests now inspect `WorldEquipmentDetails` / `EquipmentScroll`
and re-fetch buttons after a saved choice refreshes the station. They retain on-canvas actions,
focus containment, owned weapon facts and selected-state coverage.

Run reward, preparation, salvage and world filters, then the complete suite alone through the QA
launcher. The final rendered/automated evidence and exact counts for this integration are in
[V0_5A_PRESENTATION.md](reports/V0_5A_PRESENTATION.md). New `capture_world.gd` fixture states:
`bench-charm`, `bench-empty`, `inventory`, `encounter-claimed`, `charm-reward`, `catch-up`.
They seed isolated data and render the real host; they do not pass human/controller/listening gates.

Adrian's follow-up adds `world/test_world_character_menu.gd`: exploration portrait opens the
ten-slot/five-column inventory and returns to exploration; Actions/Magic match combat's factory;
Skills matches owned mastery/current passives; Alt detail, real pointer/right-click pin/release
and inspection wheel ownership remain read-only; first bell restoration expands 10→15 only after
a successful save and persists through reset/reload, without a second row on replay; compact loot
keeps descriptions in inspection. `ui/test_icon_ui.gd` checks that exposure waits for its public
ledger event and presents one hoverable effect with Mark/Precision/Break information.
Run `--filter=test_world_character_menu` and `--filter=test_icon_ui` in Compatibility as well as
the complete regression suite. [Current report and captures](reports/V0_5A_CHARACTER_MENU.md)
supersede the original integration layout. World capture states now include `inventory-start`,
`character-actions`, `character-magic`, `character-skills`; battle captures accept `--exposed`
and `--inspect-exposed`.

The [V0.5 atlas follow-up](reports/V0_5_MENU_ATLAS.md) reuses existing cloth/leather slot frames
and dark/gold row strips. Its fresh screenshots cover all four tabs, starting/expanded inventory,
the 1920×1080 preset and title version 0.5.0. The
[current continuation handoff](briefs/V0_5_CONTINUATION_FOR_CLAUDE.md) schedules the full human
test after V0.5B/C backend and presentation integration; automated checks continue per stage.

Demonstration fixture (prints public results only; it refuses to run outside an isolated QA home
because it writes a throwaway save slot):
`python tools/qa_godot.py --headless --script res://tools/demo_v05a.gd`. It plays the guard fight
with the party autopilot, commits it, rings the bell, reloads from disk, equips the charm through
the real bench interaction and station command, reloads again and shows the next entry's Grounding
trait firing on a Wet → Shock turn. It is not a playtest or acceptance result.

### V0.5B Forge and Stillroom (Claude)

Run `--filter=crafting` (both suites below) while working on this area, then the preparation and
world filters and the complete suite alone.
- `unit/test_crafting_rules.gd`: the authored catalog equals the Director's table (prices, mastery,
  kinds, refundability, potions, Base vocabulary; 3 Bog Iron + 1 Storm Salt against the route's
  4 + 1); both fittings resolve to the very trait resources of Merciful Iron and the Hollow
  Reliquary with their exact authored numbers, and Pilgrim's Edge stays socketless; catalog checks
  reject unregistered materials, unresolved or unoffered fittings, refundable potion recipes,
  recipes for free starters and prices above the route budget; capacity derives only from the kit
  and saved mastery (any owned starter; unlisted or unowned weapons do not count; unknown or
  unoffered fitting ids stay inert); all six purchase orders fit the finite budget (guard salvage
  buys kit + tincture; the patrol funds the rest); duplicate traits are found only when a fitting
  doubles one; the saved `crafting` section is parsed without trusting it.
- `world/test_world_crafting.gd`: production `WorldSession` acceptance cases. The station context
  and a pending encounter gate every command; nineteen rejections are typed, change nothing, write
  nothing and publish nothing (including the exact zero-mastery reason); a duplicate purchase never
  spends again; duplicate traits are rejected from both directions without removing anything; an
  over-limit loadout rejects fit and potion commands whole; failed writes change nothing and a retry
  publishes once; refunds return exactly 2 Bog Iron and clear the fitting in one write, never credit
  twice, conserve materials over rebuy loops and reject a cap conflict whole; the real route funds
  everything and unlocks, fittings, potions and claims survive Reset journey and reload (New Game
  has none); older saves grandfather a prepared potion's recipe with no charge, repair unknown
  potions once and keep unknown ids inert; the fitting reaches the next entry (reloaded) and a retry
  never changes; real battles show Merciful Grip's ×1.6 / ×1.5 windows, Perfect 1.07 and 8 HP per
  successful Parry, and Hollow Echo exposing each parried attacker; Focus Tincture reaches battle with
  its authored charge and +4 Focus; readouts are typed copies with no creature facts; other saves and
  shared Resources are unaffected.

Demonstration fixture (isolated QA home only):
`python tools/qa_godot.py --headless --script res://tools/demo_v05b.gd`. Guard victory by the
autopilot → bell → the real bench interaction opens the station → kit and tincture bought, salve
rejected for materials, Merciful Grip fitted, kit refunded and rebought, tincture prepared → reload
from disk → the next entry carries the fitting and both potions → a scripted Parry restores 8 HP
through the fitting and the tincture gives +4 Focus → Reset journey keeps the unlocks.

### V0.5C exploration vocabulary (Claude)

Run `--filter=exploration` (both suites below). Production now contains the iron seam, listening
rhythm and drowned niche at the [Director's tested placements](design/V05C_EXPLORATION.md).
`tests/fixtures/exploration_kit.gd` keeps independent test definitions plus Gate chimes, a second
puzzle that stays test-only.
- `unit/test_exploration_rules.gd`: the fixture world validates and broken definitions are reported
  (wrong kinds, two definitions per landmark, missing reveal puzzle/flag, runes across areas,
  foreign solution runes, length limits, orphan landmarks, rewards with non-feature sources); the
  rune grammar on both puzzles (advance, mistake, restart on the first rune, repeated runes, no
  input mutation, determinism); reveal and perception; readouts never carry the solution; world
  state round-trips and is sanitized; gathered/found/solved accomplishments drive catch-up; prompts,
  dialogue, map and every new `WorldStateView` source follow typed state.
- `world/test_world_exploration.gd`: gathering yields once (failed write → Retry publishes once),
  is kept by Reset journey and reload and never yields again; each rune strike is saved, survives
  reload and a failed final strike retries once; solving reveals the niche, whose reward is claimed
  once (found again after Reset journey with nothing granted); the second puzzle rewards on its own;
  an older save catches up once; the main route completes without any exploration content; the real
  `WorldHost` (with runtime markers at the fixture's planning tiles) never prompts or discovers the
  hidden secret, routes gathering/search dialogues and reward cards, strikes runes directly with
  `rune_struck`, shows the solved card and retries a failed strike through the save-failure card.

Demonstration fixture: `python tools/qa_godot.py --headless --script res://tools/demo_v05c.gd`
(gather → a mistake and the rhythm → the niche → reload → Reset journey → repeats grant nothing).

### V0.5B/C integrated presentation (Codex, 10 October)

`world/test_world_v05_integration.gd` adds eight production-host tests: read-only station
navigation and typed locks; purchase, fit and potion save failure/retry with preserved selection;
free no-ops, exact refund and both recipe unlocks into a battle entry; stale purchase rejection
and refund overflow; restored scene/prompt state after reload and reset; physical feet traversal
from the fork to the seam and from the existing overlook anchor to every placed rune and niche;
saved mistake/solve/reveal feedback and found/gathered art; reset/repeat grants nothing.
Run `--filter=v05_integration` headless and Compatibility. Run the complete suite alone.
New capture states: `forge`, `forge-locked`, `forge-fitted`, `forge-refund`, `forge-receipt`,
`stillroom`, `stillroom-potion`, `stillroom-locked`, `explore-clue`, `explore-runes`, `explore-progress`,
`explore-mistake`, `explore-solved`, `explore-niche`, `explore-searched`, `explore-reward`,
`explore-iron`, `explore-gathered`. `--revealed` finishes dialogue text before capture.
Use Compatibility/Dummy audio and isolated QA homes.
[Evidence](reports/V0_5BC_PRESENTATION.md) separates fresh runs from inherited backend results.
[Full A/B/C human checklist](playtests/V0_5_INTEGRATED_TEST.md) covers gameplay, controller,
readability and listening, all still open. Existing approved music is reused.

### V0.5 journey/station UI prototype (10 October)

`world/test_world_ui_prototype.gd` adds eight production UI tests for title safety/order, read-only
setup, equipment filtering/station validation, Field Guide return, local Combat swaps, stable Save
feedback, failure/retry, notification queue/coalescing/non-overlap/reduced motion and the two dedicated
stations and readable/keyboard-scrollable Help. Older UI expectations now match the five-choice title, combined tabs and hidden public reset;
the legacy preparation/reset transaction tests remain. Physical Forge collision and full route tests pass.
Run the complete suite alone in headless and Compatibility/Dummy. Do not run captures concurrently.

New capture states: `title-new`, `title-saves`, `title-credits` in `capture_battle.gd`;
`character-equipment`, `character-combat`, `notices`, `station-forge`, `station-stillroom` in
`capture_world.gd`, plus existing `inventory`, `forge-fitted`, `stillroom-potion`, `map-full`, `menu`.
`--help` opens station/Character Help. `--inspect=<node>` focuses a shared inspection source.
Title-saves and notices are isolated presentation fixtures, not player save files or reward grants.
See [the evidence report](reports/V0_5_UI_PROTOTYPE.md) and
[current backend handoff](briefs/V0_5_UI_BACKEND_HANDOFF.md).

### V0.5 UI backend (Claude, 10 October)

New suites:
- `unit/test_journey_rules.gd`: presets, difficulties, typed requests that never guess a slot,
  explicit replacement, failed writes and the complete fresh journey for every preset × difficulty.
- `unit/test_combat_rules.gd`: candidate order, the default, `resolve`, put/swap/move, typed checks,
  repair, the readout and `UnitFactory` applying an arrangement (static loadouts unchanged).
- `world/test_world_journey_setup.gd`: the title through real slot files in the isolated home: New
  Journey writes only the chosen slot and adopts after success; occupied, cancelled and failed
  writes overwrite nothing; restart resumes the slot and difficulty; damaged, newer and broken-field
  saves summarize without engine errors; newest-first with ties; a stale load changes nothing.
- `world/test_world_combat_arrangement.gd`: commands write once, reject whole and retry; locked
  positions; entries capture the order; gear reconciliation in the same write; old-save migration;
  the Character view commands.
- `world/test_world_save_events.gd`: one `game_saved` after adoption per world write and none for
  failures, rejections or no-ops; no host push; cards hidden in battle; Save and Quit waits and
  retries; Settings difficulty becomes the journey's and entries capture it.

`test_save_and_settings` adds round-trip, default and wrong-typed-section cases.

Updated to the new contracts: `test_world_crafting` (typed Forge/Stillroom services, field
potions), `test_world_preparation` (field equipment, no-op writes nothing),
`test_world_session`, `test_world_salvage_host`, `test_world_ui_prototype` (real New Journey slot step,
field equip, saved arrangement) and `test_world_v05_integration` (each station from its landmark).

Several tests use slot files 0–2 and Settings; they save and restore them. Run complete suites alone.

New capture states:
- `title-slot` and `title-replace` (`capture_battle.gd`). The fixture saves live in the QA home.
- World station states now open their own landmark.

Demos:
- `demo_v05a` equips in the field.
- `demo_v05b` uses the anvil and the Stillroom, each rejecting the other's work.

Mutation checks for this pass: scratchpad `mutate_ui.py` (see the report).
[Report](reports/V0_5_UI_BACKEND_IMPLEMENTATION.md).

Tool entry points compile before the autoloads exist. A class they reach, for example through
`DefinitionRegistry`, must not name `Database`, `GameState`, `SaveManager` or `Settings`.
`check_scripts.gd` runs in-process and cannot see this, so also compile every tool entry with
`--check-only`. Godot exits 0 either way, so read the output; this prints nothing when clean:

```sh
for t in $(grep -lE "^extends SceneTree" tools/*.gd); do
  python tools/qa_godot.py --headless --check-only --script "res://$t" 2>&1 | grep -E "SCRIPT ERROR|^ERROR" && echo "  in $t"
done
```

Walk the player's feet inside a physics frame (`await tree.physics_frame` first). Outside one,
`move_and_slide()` uses the variable process delta, so a fixed number of `step()` calls covers a
different distance on every run.

`tools/validate_world_art.gd` reports 376 checks, 0 failures. Its Hollow motion checks read the
frames `scenes/hollow.tscn` actually uses, standing idle pairs included. `HOLLOW_FRAMES` pins the
accepted export (`hollow_motion_v05`): a polish pass that re-exports the Hollow's frames and
re-points the scene bumps it too, or the validator reports `Scene embeds stale frames: hollow`.

### V0.5 UI Director acceptance and presentation (Codex, 10 October)

The slot step, replacement review and final copy use the existing material components. Title
summaries are labels inside one focusable card; assertions now inspect those labels rather than
assuming all facts live in `Button.text`. Existing transaction/retry coverage remains.

- `test_world_journey_setup` adds card-fact bounds, whole-card pointer ownership, singular victory
  copy, damaged-file Cancel preservation and no writes/events/scene entry while reviewing. Its
  existing flow now checks the chosen setup recap, irreversible-loss copy, and all three cards
  fully visible with a save failure or full-list status. The recap stays above scrolling choices.
- `test_world_ui_prototype` adds a save receipt at both station footers with no action overlap,
  ordinary/reduced motion, return to the exploration stack and no presentation-induced save.
- `test_world_v05_integration` checks the reserved save space after an actual potion retry, keeping
  all fixed actions visible. `test_world_combat_arrangement` checks the Unplaced line changing from
  Kindle to Spark after placement; its equipment-result assertion follows the final position copy.

New capture states: `title-slot-full`, `title-slot-failed`, `title-replace-damaged` in
`capture_battle.gd`, in addition to the existing slot/replacement fixtures. Save failures use an
injected failing writer, and all saves remain inside the QA home. Capture screenshots with
Compatibility and Dummy audio. The [presentation report](reports/V0_5_UI_PRESENTATION.md) holds
fresh results and actual rendered fixtures, including a 1920×1080 slot view.

Run full suites alone, sequentially, through `tools/qa_godot.py`, headless and Compatibility/Dummy.
On restricted Windows hosts, a fresh `--home .godot/qa-director/<run-name>` keeps isolated saves and
caches inside the ignored project cache. Use a distinct run name per full suite. The player's
normal save/settings directories are untouched. A full run still has only the expected diagnostics
listed in §2. Human/controller/art/listening gates remain open.

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

Second V0.4 playtest material/standing-art integrity: run
`python tools/qa_godot.py --headless --script res://tools/validate_material_polish.gd` after import.
This complements `tools/validate_world_art.gd` and the full suite. It checks tracked bitmap imports,
socket transparency, authored idle/crow frame counts and native foot baselines; it does not certify
human art or listening acceptance. The read-only `tools/probe_willow_footprint.gd` records willow
footprint evidence; the third-pass collision work and its tests are described above and in
`docs/reports/V0_4_THIRD_PLAYTEST_ENGINEERING_REVIEW.md`.

`.github/workflows/ci.yml` downloads Godot 4.7.2 (Linux), imports the project, compiles every script,
runs the full suite and a short simulation smoke run on every push and pull request.

## V0.5 playtest revision — fresh checks and reviewed captures

The [Director implementation report](reports/V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md) is the current
feedback-coverage ledger. Claude explicitly transferred the Godot window in his backend report §6;
Director runs are sequential, isolated by qa_godot.py under `.godot/qa-playtest-revision/`.
Historical suite counts elsewhere in this document do not verify the revision. Broad snapshots
still contain protected backend failures; see the [failure inventory and logs](reports/v0_5_playtest_revision/FAILURE_INVENTORY.md).

`ui/test_playtest_revision.gd` adds tooltip safe-corner/source/Continue checks, native suppression,
manual dialogue scrolling during reveal, 10/15-of-20 bag cell geometry and read-only catalog
inspection, checkbox state geometry and tiled scrollbar caps, Journal/station bounds and adopted
audio/save feedback. Focused presentation: **8 tests / 158 assertions / 0 failed**, headless and
Compatibility/Dummy. Four Director-owned world suites: **28 tests / 450 assertions / 0 failed**
headless. Latest full results and source-state limitations are maintained in the implementation
report instead of treating these focused checks as full acceptance.

`tools/capture_playtest_revision.gd` with its runner prepares explicit in-memory production-widget
fixtures: `title`, `settings`, `dialogue`, `reward`, `inventory`, `inventory15`, `loadout`, `forge`,
`stillroom`, `journal`, `reward-learnings`. Options are `--size=<supported preset>`, `--out=res://…png`, and
`--edge=tl/tr/bl/br`, `--inspect=<node name>`. Additional variants cover `loadout-popup`,
`forge-locked/owned/fitted`, `stillroom-poor/depleted/stock`, and supplied-fact-only HUD fixtures
`countdown`, `countdown-frozen`, `quest`, `autosave`, `manual-save`.
Use qa_godot.py with a distinct `.godot/qa-playtest-revision/<run>` home,
`--hidden --rendering-method gl_compatibility --audio-driver Dummy`, then `--script` and fixture
arguments after `--`. A memory writer isolates fixture station context from player saves.
Additional flags: `--reduced` for static title decoration; `--checkbox=unchecked/hover/pressed/focused/disabled`
for state-art fixtures. Missing requested inspection nodes fail the capture instead of silently
producing an uninspected image. The wrapper is the entry point; runners load after autoloads.

`capture_world.gd` supports `revision-countdown`, `revision-cancelled`, `revision-quest`,
`revision-journal`, `revision-save-manual`, `revision-save-auto`. These use actual host/session
commands and memory writes; the countdown clock and player placement are held fixtures.
`capture_battle.gd` captures live planning/reaction/Field Guide. `--broken` and `--broken-party`
are explicitly display-only Broken fixtures, not fabricated engine outcomes.

Reviewed evidence: [capture index](reports/v0_5_playtest_revision/README.md), including 720p/1080p
main screens, five Loadout presets, all four tooltip corners at all five presets, checkbox states,
locked/owned/fitted/depleted station variants, actual host routes and compact mixed rewards.
Human input/controller feel, listening/mix, title motion, countdown fairness, party Break balance,
finite economy and the earlier full playtest checklist remain open.
