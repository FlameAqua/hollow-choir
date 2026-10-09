# V0.4 fifth playtest — engineering review

Claude · 9 October 2026 · uncommitted `dev` after `6d8401d` · application 0.3.0 / save version 1
**Not committed or pushed. No version bump, save-schema change, combat-rule change or area
regeneration. Codex's fifth presentation pass (grid, docks, banners, pins, field help, spacing, v05
mask) is preserved.** Adrian's four decisions of 9 October (§0) are applied: Pause is ignored during
timed inputs, enemy turn banners carry the intent number badge, the grid always shows eight slots,
and the app icon is transparent outside its frame.

This answers [the fifth continuation brief](../briefs/V0_4_FIFTH_PLAYTEST_ENGINEERING.md) after
reviewing [the fifth presentation results](V0_4_FIFTH_PLAYTEST_POLISH.md). There was no separate
fourth engineering review, so §6 also closes [the fourth brief](../briefs/V0_4_FOURTH_PLAYTEST_ENGINEERING.md).
The pass ran across two Claude sessions. The first was interrupted before it wrote this report. In
the second, every inherited change was re-read, re-run and mutation-checked before being reported
here. §7 separates inherited work from what this review verified.

## 0. Adrian's decisions (9 October 2026) and what changed

| Decision | Implementation |
|---|---|
| 1. You must not be able to time things by pausing: Pause requests are ignored during quick-time events | Pause (key, controller Start, toolbar button) and the sandbox's Setup are ignored, not queued, while a command or reaction window is open, from its preparation beat to its result. Pause still freezes the battle in planning, recipient review and playback, and Resume is immediate. The draft's in-window freeze, 0.9 s resume countdown, widget `suspend()` API and Pause → log hold were removed (§1). |
| 2. Enemy turn banners show name + number, in the badge used above enemies | "[2] Thornhound B's Turn": the enemy's absolute encounter number is drawn by `UICraft.number()` (the intent badge's frame and digit style), beside the name and centred with it. Allies have no badge (§4). |
| 3. Up to eight action slots per ally/Hollow (current actions are placeholders); unused slots are empty frames | The grid always shows eight cells. Unused cells are inert, dimmed `utility` frames: no focus, pointer, inspection or pin (§5). Slot unlocking (6 → 7 → 8) and slot trading are future progression work, not built. |
| 4. The app icon may be transparent | v02 PNG/ICO: transparent outside the rounded bronze frame, colours unchanged. `project.godot` uses v02, and v01 is kept (§6). |

## 1. Pause

**Defect found.** Pause and controller Start did nothing during recipient review:
`request_pause()` fell through every branch while `_picker.is_targeting()`. Tab also reopened the
battle log underneath Pause and Reaction help.

**Final behaviour** (`scenes/battle/battle_scene.gd`):

- **Planning, recipient review and playback:** Pause opens at once and freezes the battle in place.
  `_set_frozen()` disables the event player, overlay (floating text and the turn banner), stage,
  familiar and picker; every playback wait, announcement and feedback tween is node-bound (D-014). A
  frozen battle opens no new menu, command or reaction (`_safe_point()` waits for `_resumed`).
  Resume continues at once. Recipient review survives Pause unchanged: same action, same reviewed
  recipient, nothing submitted or spent. Escape stays Back while reviewing; Pause/Start opens Pause.
- **Timed inputs (Adrian's rule):** while `_timed_active` (from `_begin_timed()`, i.e. before the
  preparation beat, until the result), `request_pause()` and `pause_for_host()` refuse. The request
  is dropped, not queued, and the command or reaction clock never stops for it. The Pause key is
  still consumed, so nothing else (such as the world menu) reads it. The widgets' existing
  window-focus freeze and relatch are unchanged (D-021).
- **Selected frame.** Recipient review releases keyboard focus, so the reviewed action lost its
  focus frame. `ActionMenu.mark_pending()` now keeps the selected frame on exactly that row until
  Back, replacement or commit (`ActionPicker`).
- **Boundaries.** Tab cannot reopen the log under Pause, Help or the result card. Once the engine
  has decided the battle, *Leave* is disabled, so the decided outcome cannot be discarded. Once the
  outcome is handed over (`_concluded`: the result card, or a world host's own outcome card over a
  finished battle), Pause no longer opens. A standalone retreat fades out without resuming. Sandbox
  Setup covers at once outside timed inputs, and closing it resumes at once. Pause → Battle log keeps
  Codex's route (Pause closes, the log stays readable).

## 2. Field explanations checked against the engine

| Field | Finding | Fix |
|---|---|---|
| Scope/timing | Hard-coded "Hold Alt for the other timing grades", wrong when Details is rebound or set to Toggle/Always | `PreviewPanel.grades_hint()` names the player's key and mode |
| Break remaining | Promised "exposes its weak point" for every enemy; only enemies with a weak point have one (`StaggerRules`) | The sentence appears only when the readout has a weak point; the channel caveat is kept |
| Focus (cost and unit field) | "Guard restores 1 Focus." Every Hollow weapon replaces Guard (Riposte Stance, Anchor Stance, Steady Aim), and the text omitted the main sources | `PreviewPanel.FOCUS_SOURCES`: basic attacks on Good/Perfect, other timed actions on Perfect, weakness hits, parries, Breaks, Inspect and each weapon's Guard action; traits, gear and supplies can add more |
| Item charges, unknown damage ("unlocks at Understood, or Inspect"), allowed/unavailable reactions, threat, channel/interrupt, support and status notes | All come from the engine's public readouts (`IntentReadout.allowed` ← `IntentPreview.allowed`; damage gated by `knows_moves` = Understood or Inspect at `inspect_reveal_level`) | No change |

Field help stays beside the main card and never replaces its subject. Research filtering and
presentation-ledger chronology are unchanged, and native delayed tooltips stay suppressed.

## 3. Right-click pins

No defects found in code or tests. Pinning is handled only by the inspector's right-click path,
which marks the event handled. Action buttons react to the left button only, so a pin never
submits, spends Focus or charges, or alters a request. A pin keeps its original filtered snapshot
through recipient review and target hover: hover still moves the reviewed recipient, but never
overwrites the pinned payload. Details expands the pinned card in place. Pause, Settings, Help, the
result card, turn/round banners, timed windows, the menu hiding, Setup cover and a destroyed or
hidden source all clear the pin through `suppressed`/`clear()`. Restart replaces the node. Wheel
ownership is still decided by `claims_wheel()` alone. An empty action slot has nothing to pin.
New coverage: `test_pin_survives_recipient_review_and_target_hover_until_a_boundary`.

## 4. Turn announcements

- **Numbered enemy turns (decision 2).** `Banner.announce_turn()` shows the enemy's display name
  ("Thornhound B's Turn") with its absolute encounter number in a badge drawn by
  `UICraft.number()`, the same frame and red digit as its intent above the stage. Sized 34 px with a
  14 px digit inside the 0.82-scaled banner, it appears at about the intent badge's 26 px. The name
  sits on one line, centred together with the badge. The number is the one the intent badges use:
  `enemies(false)` in encounter order, from the real `TURN_STARTED` path. `UICraft.number()` gained
  an optional digit size (default 11, so every existing badge is unchanged). Factory suffixes (A/B/C)
  stay in names, as everywhere else in the UI (log, target prompt, intent card "02 Thornhound B").
- **Combat Speed:** the intro, round, turn, phase and outcome banners scaled only their hold. Their
  0.15 s / 0.2 s fades ignored Combat Speed, against D-014. The shared `Banner._fade()` now divides
  by Combat Speed, which callers pass through. Condition banners already scaled fully.
- Announcements play from `TURN_STARTED` before any request, so they come before every timed clock.
  They freeze under Pause, and restarting mid-announcement drops the scene-bound tween (probe:
  freeing a battle mid-announcement is safe). Broken turns announce, then float "Skips (Broken)".
  Autopilot and channels use the same path. Alpha fades are not motion; condition flight already
  respects Reduce motion.

## 5. Action grid: eight slots

`ActionMenu.CAPACITY = 8`. Following decision 3, the grid always shows eight cells. Cells without an
action are `EmptySlot` panels: the neutral `utility` slot frame dimmed with `EMPTY_SLOT_TINT`. They
follow the real actions and take no focus, pointer, inspection or pin, and keyboard navigation never
lands on one. `tests/unit/test_action_capacity.gd` holds every protagonist × every weapon × the most
action-granting armor in each slot, and every companion, to eight, and checks that each shipped
loadout offers all of its real actions. Current (placeholder) inventory:

| Unit | Grid actions | Count |
|---|---|---|
| The Hollow, any of the 7 weapons | basic attack · 2 weapon techniques · Spark · Kindle · weapon Guard action (Riposte Stance / Anchor Stance / Steady Aim) · Inspect | **7** + 1 empty |
| Mara | Spear Flurry · Condemn · Intercept · Guard · Inspect | **5** + 3 empty |

No armor currently grants an action (`ArmorDefinition.granted_actions` is supported by `UnitFactory`
but unused). Potions live in Supplies and don't count. Nothing was discarded or invented, and
Stance/Guard choices are unchanged. Slot unlocking and slot trading are not built.

**Measured layout defect (reported to Codex, not changed).** At the fixed 1280×720 canvas (every
window preset scales the same canvas), a cell is 298 px wide. The row loses 34 px of insets, a
24 px icon, the Focus glyph and number (14+14 px) and three 6 px gaps, leaving **194 px for the
name**. An unavailable row adds an 18 px mark and a gap, leaving **170 px**. Three shipped names are
ellipsized:

| Name | Needs | Has |
|---|---|---|
| Riposte Stance (sword) | 196 px | 194 px |
| Spotter's Mark (bow) | 196 px | 194 px |
| Earthsplitter (hammer, unaffordable at start) | 182 px | 170 px — visible as "Earthsplitt…" in [centered-actions.png](v0_4_fifth_polish/centered-actions.png) |

Smallest fixes, measured: (a) draw the unavailable mark over the action icon instead of after the
cost, so names always get 194 px, and (b) reduce the row insets from 17 px to 15 px (+4 px → 198 px).
Together these fit every shipped name in either state. (a) alone does not fix the first two; (b)
alone does not fix Earthsplitter. `test_every_shipped_action_name_fits_its_grid_cell` pins these
three names in `KNOWN_CLIPPED_NAMES` and fails on any other clipped name; empty the list once the
layout changes.

Evidence (native Compatibility window, 1280×720, labelled fixtures):
[grid with empty slots and a numbered enemy turn](v0_4_fifth_engineering/enemy-turn-badge.png),
[Mara's grid](v0_4_fifth_engineering/grid-mara.png).

## 6. Fourth-brief checks

| Item | Result |
|---|---|
| 1. Battle log (Tab and Pause routes, wheel/thumb/Page/Home/End, history, refocus, 2560×1440) | Rendered `test_fourth_playtest` 3/0. **Fixed:** Tab reopened the log under Pause/Help. Pause, Help and Settings hide the log, and Help/Settings keep the battle paused and return to Pause. |
| 2. Dialogue | Code review (`WorldModal`): holding the physical Space key only speeds the reveal (38 → 190 characters/s) and never advances or closes. The first Confirm reveals the whole line and the next one chooses. Each conversation opens a fresh modal, so reveal and scroll reset. Cancel uses the bound Back action. Focus loss drops back to normal speed, because no key reads as held. Rendered hold/autoscroll test passes. No defect found. Note: acceleration is keyboard-only and not rebindable; a controller reveals the line with Confirm instead. |
| 3. Reaction help and compact cards | Help keeps the battle paused and Back restores Pause (tests). Live timing and fresh-press rules are unchanged, and Pause can no longer reach a live window. Condition caveats are inspectable before the window. Broken is a status cell (Codex's rendered test). |
| 4. Exploration idle | Rendered eight-direction head/boot identity passes with the v05 mask. Collision, journey and reset suites pass. Art untouched. |
| 5. Music, app icon | **New regression:** Gloamstead → Reedway → battle → return requests the right typed cue and plays a version of it, and pausing/menus never restart the song. **Icon (decision 4):** `tools/prepare_icon_alpha.gd` flood-fills near-black from the 1254 px source's border, so only the background outside the rounded frame becomes transparent and the eye holes stay opaque. Alpha is the exact area coverage of that mask, with no resampling halo. Every RGB pixel is copied from v01. Output: `hollow_choir_v02.png` (256 px) and `.ico` (16, 24, 32, 48, 64, 128, 256 px, PNG frames). Provenance is noted in `docs/art/first_footsteps_v01/fourth_playtest_prompts.md`. `tests/unit/test_app_icon.gd` checks the settings, transparent corners, opaque interior and unchanged colours. There is still no `export_presets.cfg`, so Windows export embedding is unverified (nothing was exported). |

## 7. Inherited work and verification

**Inherited from the interrupted session, now verified:** the review-Pause fix, playback freeze,
selected frame, outcome guards, timing/Break help, banner speed, pins, capacity test and music test.
Its in-window freeze, countdown and widget `suspend()` were removed under decision 1.
`hold_release_widget.gd` is back to its committed form, and the command/reaction widgets differ from
`6d8401d` only by Codex's changes and their updated doc comment.

**Added in this session:** the Focus field fix; Adrian's four decisions; the host-owned-outcome and
safe-point tests; the clipped-name, Focus, badge, empty-slot and icon checks; focus-robust
live-window fixtures; the stale `_retreat` and sandbox Setup comments. No edits from other agents
appeared during this session (snapshot diff).

**Mutation checks** (scratch copy of the tree, never the repo; each reverts one behaviour and runs
the covering tests).

- **Before the decisions:** 22 mutations, 21 caught. This pass covered the field help, pin
  overwrite and grid capacity, which are unchanged since. The survivor was a defensive guard that
  went with the removed in-window freeze.
- **On the final code:** 16 mutations, all caught:
  - Pause opening during a reaction, a command window or a world reaction;
  - Setup covering a timed window;
  - a missing badge, a badge number off by one, and the old plain-text number;
  - missing, focusable or pointer-catching empty slots;
  - the project still using the opaque icon;
  - re-checks of review Pause, Tab under Pause, the playback freeze, the host-owned outcome, the
    selected frame, banner speed and the safe point.

**Two rendered-run failures diagnosed (desktop focus).** Two separate full rendered runs each
failed once while a live-window test waited. One failed reaching the window, the other waiting for
it to resolve. Both tests pass when run alone, and reaching a live window normally takes about 1.0 s
of the fixture's 8 s budget. Injecting a focus-out at either point in a scratch copy reproduces each
failure exactly. Freezing the preparation beat and the window clock on focus loss is correct game
behaviour (D-021), and the desktop is shared during rendered runs. The live-window fixtures in
`test_battle_pause`, `test_world_host` and the sandbox host test now simulate focus returning while
they wait. With the guard the injected focus-out passes; without it, it fails. A stalled search
prints the battle state.

**Final results** (isolated `.godot/qa/*` homes, suites run alone, Godot 4.7.2):

| Check | Result |
|---|---|
| Baseline at the start of the pass (before any change) | 304 passed, 0 failed, 4,115 assertions |
| Full suite, headless | **328 passed, 0 failed, 4,482 assertions** (109 s) |
| Full suite, hidden native Compatibility window | **328 passed, 0 failed, 4,506 assertions** (107 s) |
| Rendered, per file | `test_fifth_playtest` 5/0 (91) · `test_fourth_playtest` 3/0 (39) · `test_battle_pause` 9/0 (100) · `test_fifth_engineering` 8/0 (154) · `test_world_host` 21/0 (206) · `test_app_icon` 3/0 (63) · `test_action_capacity` 2/0 (23) |
| Scripts (`check_scripts.gd`) | 250 checked, 0 failed |
| Material polish (`validate_material_polish.gd`) | 264 checks, 0 failures |
| Python (`unittest discover`) | 10 tests OK |
| Simulation smoke (`--encounter=all --exec=MIXED --runs=10 --seed=1`) | Identical to a fresh `6d8401d` clone except elapsed time; no errors |
| Whitespace | clean |

Assertion totals vary by a few between runs, because wall-clock fixtures loop over whatever is on
screen. Expected diagnostics only: 4 invalid-save errors, 1 "rejected action (Needs 5 Focus)"
warning and 5 world-session recovery warnings. No leak reports.

## 8. Notes for the Director

1. **Record Adrian's rulings** (§0) in the Decision Log. Decision 1 supersedes
   `docs/design/M1_1_COMBAT_CLARITY.md` §7 / M1.1 F2: pause requests during timed input are now
   ignored, not queued. Window focus loss still freezes a timed window and relatches held keys
   (D-021, unchanged). That rule protects against the OS stealing focus, but an alt-tab can still
   freeze a window. Say if it should change too.
2. **Clipped action names** (§5): the smallest measured fix is (a) + (b). Codex owns the layout.
3. **Empty slots and the badge** use existing frames (`utility` dimmed; the intent number badge).
   Restyle freely; keep the empty cells inert.
4. **Future slot progression** (decision 3): starting with about six unlocked slots, unlocking a
   seventh and eighth, and trading slots (for example Identify or a spell slot for another weapon
   skill) need a data contract (per-unit slot count and loadout rules) before implementation. The
   capacity test then becomes "≤ unlocked slots".

## 9. For Adrian to check by hand

- Esc, controller Start and the Pause button during a reaction or command: nothing should happen,
  and the window should finish normally. During planning, target review and playback, Pause should
  freeze, and Resume should continue at once.
- An enemy turn in Thornhound Pack: the badge should match the number above that hound.
- Mara's grid: three empty frames.
- The taskbar/window icon without the black corners.
- Earthsplitter's truncated name in the hammer grid (Codex fix pending).

Still open from earlier passes: human playtest and controller gates, and audio listening.

## Files changed in this pass

- `scenes/battle/battle_scene.gd`: Pause rule, playback freeze, review Pause, conclusion guards.
- `scenes/sandbox/combat_sandbox.gd`: Setup doc comment (refused during timed inputs).
- `src/ui/battle/commands/command_widget.gd`, `reaction_widget.gd`: doc comments only (Pause is
  ignored while they are open).
- `src/ui/battle/action_menu.gd` (`CAPACITY`, empty slots, `mark_pending()`, `pending_button()`),
  `action_picker.gd` (pending frame on enter/replace/back/submit/cancel).
- `src/ui/battle/banner.gd` (number badge, fades follow Combat Speed), `battle_event_player.gd`
  (speed pass-through), `src/ui/ui_craft.gd` (`number()` optional digit size).
- `src/ui/battle/preview_panel.gd` (`grades_hint()`, `FOCUS_SOURCES`), `unit_inspection_card.gd`
  (Break and Focus explanations).
- Icon: new `tools/prepare_icon_alpha.gd`, `assets/art/global/icon/hollow_choir_v02.png` (+ `.import`)
  and `.ico`. `project.godot` icon paths; the provenance line in the fourth-playtest art notes.
- Tests: new `tests/ui/test_battle_pause.gd` (9), `tests/ui/test_fifth_engineering.gd` (8),
  `tests/unit/test_action_capacity.gd` (2) and `tests/unit/test_app_icon.gd` (3).
  `tests/world/test_world_host.gd` gains 2 tests. `tests/ui/test_presentation_boundaries.gd`'s
  host test and two `tests/ui/test_fifth_playtest.gd` banner assertions follow the decisions.
- `docs/TESTING.md`: fifth-playtest test section. Evidence: `docs/reports/v0_4_fifth_engineering/`.

**Public API changes:** `BattleScene.is_frozen()`. `is_pause_pending()` is removed (no remaining
callers). `pause_for_host()` returns false during timed inputs and true otherwise.
`Banner.announce(…, speed)` and `announce_turn(…, speed)`; `ActionMenu.EMPTY_SLOT_TINT`;
`UICraft.number(…, font_size = 11)`. **Save impact:** none. **Data contracts:** unchanged.

**Next assignment:** [V0.5A backend handoff](../briefs/V0_5A_BACKEND_HANDOFF.md) (Salvage and
Preparation) is queued and was not started in this pass.
