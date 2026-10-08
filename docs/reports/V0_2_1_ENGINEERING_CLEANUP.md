# V0.2.1 engineering cleanup and stabilization

**Claude (Lead Gameplay Engineer), 8 October 2026.** Branch `dev`, base commit `8d71810` ("V0.2"),
Godot `4.7.2.stable.official.ed1daf0bf`. Nothing was committed or pushed. This report answers the
V0.2.1 cleanup brief and follows [the current UI contracts](../design/V02_UI_INTERACTION.md),
[follow-up](../design/V02_UI_FOLLOWUP.md), [support presentation](../design/V02_SUPPORT_PRESENTATION.md)
and [pre-push polish](../design/V02_PRE_PUSH_POLISH.md). It does not redesign ChatGPT's UI.

**All evidence here is automated or rendered.** No fresh-player, physical-controller, colour-vision
or comfort session took place. Those gates remain open.

## Verdict

- **Four verified defects fixed**, each reproduced before the change and guarded by a regression
  test that fails when its fix is reverted:
  1. An open unit card went stale when a presented event changed a fact missing from its refresh key.
  2. Wheel ownership depended on scene-tree callback order.
  3. Frozen battle feedback drew over the Setup page.
  4. The pause button's explanation changed after an input-device switch (consistency; no test).
- **Dead UI scaffolding removed** after searching scripts, scenes, resources, tools and tests: two
  widget classes, about 20 unused fields, parameters and functions, and a misleading layout name.
  No player-visible behaviour changed. Tests that read removed private nodes now test the
  player-visible behaviour they guarded.
- **Tooling:** QA runs can now isolate user data, with a guard against silent fallback. The V0.2
  capture states now live in maintained tooling.
- **Hygiene:** Godot no longer imports `docs/`. Version 0.2.1 and release notes are recorded.
- **Rules, balance, timing windows, graders, readout filtering, content, saves and bindings are
  unchanged.** Ninety-six seeded battles produce identical event streams and input logs before and
  after. The simulation smoke output is identical.

## 1. Findings and chosen priorities

### Verified defects (fixed)

| # | Defect | Reproduction on the untouched base | Fix |
|---|---|---|---|
| D1 | A hovered unit card stays stale when a presented event changes only a fact it shows. Example: a `COVER_STARTED` plays while the ally is hovered, and the card never shows "Covered by Mara". | Probe: after the real event, the visible card's notes were `[]` while a fresh `UnitReadout` had `["Covered by Mara"]`. Cause: the inspector re-renders only when the source's text changes, and that text came from a separate formatter (`BattleScene._unit_tooltip`) that omitted cover. In expanded planning it called `UnitDetails.describe` on live engine state every frame, purely as a change key. | The unit body's text is now `UnitReadout.plain_text()`, built from the same filtered, ledger-driven readout the card draws. The duplicate formatter was removed. |
| D2 | "Expanded details own the wheel over their source" held only because the inspector was added to the scene after the action menu, so its `_input` ran first. | Probe: with the inspector moved before the menu, an Alt-expanded wheel scrolled the list (54 px) and left the details at 0. | One rule, `HoverInspector.claims_wheel(hovered)`, used by both the inspector and `ActionMenu` through `wheel_claimed`. Outcomes match the contract in either order. |
| D3 | Setup covered a suspended battle, but in-flight floating text (z 50) froze **on top of** the Setup page. A late outcome banner (z 60) could do the same. | Rendered Setup capture showed "Wet · Flooded Ground" and "Evaded" over the Practice form. | `cover_for_host()` also hides the battle subtree; `resume_from_host()` shows it. The Setup page is opaque, so nothing else changes visually. |
| D4 | The pause button's explanation was assigned twice at build time and replaced by a third string after a device switch. | Code: `_build` vs `_on_device_changed`. | One `_refresh_toolbar_tooltips()`. |
| D5 | A fresh import treated `docs/**.csv` as translations: 44 locale warnings, eight `.translation` binaries and seven stale `.import` sidecars committed under `docs/`, and exportable resources. | A fresh clone import printed 44 warnings and generated the files. | `docs/.gdignore` (nothing in the game loads from `docs/`). The generated artifacts were removed, and their UIDs are unreferenced. |
| D6 | Documented test and capture commands used the developer's real `user://`: their text size, bindings, window mode and Lab preferences could change results. Captures relied on an ignored local Python wrapper. | Code: `Settings._ready()` loads `user://settings.cfg`. The V0.2 evidence used `.godot/run_ui_qa.py` (untracked). | `tools/qa_godot.py` plus the `tools/qa_user_data.gd` guard (see §3). |
| D7 | The README had a broken design-document link, a stale "Milestone 1 / 120 tests" status, and wrong controls (Z no longer confirms; Backspace goes back). `project.godot` still said 0.1.0 after "V0.2". | Read against `InputBindings.DEFAULTS` and the git log. | README, TESTING and DATA_CONTRACTS corrected. Version 0.2.1 and release notes added. |

### Obsolete scaffolding (removed; every consumer searched first)

| Item | Evidence it was dead | Test or doc consumer handled |
|---|---|---|
| `BattleScene._party_panel/_party_box/_party_cards/_build_party_cards`, `_set_card_active`, class `PartyCard` | `_build_party_cards` was never called; the dictionary was always empty; the panel was always hidden | `test_icon_ui` asserted `_party_panel.visible == false` → now asserts that the dock holds exactly Actions/preview/Supplies and that each party member is shown on stage |
| `DetailsPanel`, `_details_panel`, `_refresh_details_panel` (only hid it), `ActionPicker.details_view`, `BattleLayout.details` | Always hidden; the picker never read `details_view` | `test_v02_ui` asserted `_details_panel.visible == false` → now asserts that while Alt is held, the only framed panel over the stage is the single inspector. Canonical contract line updated. |
| `_stack_dim`; `BattleLayout.Mode`/`STACKED` re-layouts in `_begin_timed/_end_timed/_show_planning` | Never shown; `_apply_layout()` does not depend on timed state, so those calls were idempotent | Layout equivalence verified (48 size/scale cases identical) |
| Picker group path (`_group`, `_show_group`, `menu.in_group()/back()`), `_details_extra`, `show_debug`, `_detail_uid`, `_prompt`, the `target_reviewed` signal, the `rail` field | `in_group()` always returned false; nothing called the others; the signal had no connection | none |
| `UnitView.highlight_label/active_label`; label parameters of `Battlefield.set_active/set_highlight(s)` ("YOUR TURN", "TARGET(ED)") | Never drawn since the V0.2 follow-up removed those words | none |
| `UnitView.show_plate`, `_draw_badge`, `slot`, `has_sprite`, `anchor_center`; `Battlefield.set_plates`, `slot_of`, `reserved_rect` | The plate was always on, so the badge was unreachable; the others had no reader | `test_icon_ui` asserted `reserved_rect == Rect2()`; the same test's existing full-height assertions still cover "intent icons reserve no sprite space" |
| `IntentSlot.Mode/mode/stats/show_stats/selected`; `IntentRail.mode/refresh_stats/set_selected`; ignored `arrange` arguments | Stats and selection were never drawn (the selection line was removed in V0.2) | none |
| `HoverInspector.pinned_text/pinned_enemy` | Never read by the inspector | Two boundary-test lines: one redundant with the adjacent visibility assertion, one set a field with no effect |
| `PreviewPanel.show_text` and its hidden scroll/label; unused `describe(prompt, extra)` / `describe_details(extra)` / `show_readout(target_detail)` parameters | Only the dead group path used `show_text` | `get_text()` keeps the card's plain text |
| `BattleLayout.familiar` → **`supplies`**; unused `party/rail/ribbon/overlay/details/text_scale/dock_columns`; `MARGIN`/`COLUMN_GAP` now used instead of the literals they named | Comment called it a "compatibility field" | Geometry identical in all 48 cases |
| `BattleEventPlayer._condition_summary`, `CombatSandbox._build_next_tests/FORM_WIDTH/current_view`, `ActionMenu.row_texts`, `UITheme.accent_box` | No references | none |

### Considered and deliberately kept

- `IconPainter.draw_*` procedural icons have no callers. The style guide keeps procedural symbols as a
  sanctioned fallback, so they stay pending a UI-owner decision.
- `UnitDetails.describe/affinity_line` have no production caller now, but they are tested
  knowledge-gating formatters. Migrating those tests to `UnitReadout` is listed as deferred work.
- The `BattleScene` timed-input flow (`_answer_command/_answer_reaction/_prepare_timed`) stays
  inline: request → widget → preparation → `start_timing()` → result → submit remains one readable
  path. Extracting it would add references without removing duplication.
- `PreviewPanel` draws status payload strips twice, for actions (42 px step) and moves (38 px).
  Unifying them is safe only with geometry parameters and a visual review, so it is deferred.

## 2. Files changed and why

**Production code**

| File | Change |
|---|---|
| `scenes/battle/battle_scene.gd` (1063 → 972 lines) | Removed the hidden party panel, DetailsPanel, dimmer and STACKED re-layouts (§1). The unit card key now comes from the readout (D1). Wheel and keyboard-source wiring (D2). Hide while covered by a host (D3). One toolbar-tooltip source (D4). |
| `src/ui/battle/hover_inspector.gd` | `claims_wheel()` is the single wheel rule. Public `follow_keyboard()` and `follows_pointer()` replace external writes to `_pointer`. Removed dead pinned fields and per-payload height arithmetic. One transformed-point helper, `_local_point`. The shared `UITheme.plain_text` replaces two per-frame `RegEx` compilations. |
| `src/ui/battle/action_menu.gd` | The `wheel_claimed` seam; removed group stubs, `row_texts` and the meta text; `row_focused(option)`. |
| `src/ui/battle/action_picker.gd` (333 → 248) | Removed the group/analysis-extra/prompt/selection scaffolding and the unconnected signal. Behaviour-identical help text. |
| `src/ui/battle/presentation/unit_readout.gd` | `plain_text()`: every field the card can show, from the readout alone (no engine query, no new knowledge). |
| `src/ui/battle/preview_panel.gd`, `unit_inspection_card.gd` | `card_height()` sizes nested cards in one place; the hidden scroll/label became plain text; unused parameters removed. |
| `src/ui/battle/battlefield.gd`, `unit_view.gd`, `intent_slot.gd`, `intent_rail.gd`, `battle_event_player.gd` | Label-free selection calls; removed plate badge, slot, legacy fields and unused rail state. |
| `src/ui/battle/presentation/battle_layout.gd` | `supplies` rename, unused fields removed, named constants used. |
| `src/ui/ui_theme.gd` | `plain_text(bbcode)` (one cached markup stripper); removed unused `accent_box`. |
| `scenes/sandbox/combat_sandbox.gd` | Removed the dead next-test panel, constant and accessor. |
| deleted `src/ui/battle/party_card.gd`, `details_panel.gd` (+ `.uid`) | No consumers. |
| `project.godot` | `config/version="0.2.1"`. |

**Tests**

| File | Change |
|---|---|
| `tests/ui/test_v02_ui.gd` | New: `test_wheel_ownership_ignores_handler_order_and_covers_supplies_and_enemy_sources` (D2; also closes earlier gaps for the Supplies list and enemy sources in a real battle). Alt now checks for one panel over the stage, and the public source API is used. |
| `tests/ui/test_presentation_boundaries.gd` | New: `test_hovered_unit_card_follows_presented_cover` (D1) and `test_setup_hides_residual_battle_layers_until_resume` (D3). Removed-field assertions retargeted. |
| `tests/ui/test_icon_ui.gd`, `test_stage_art.gd` | Dock-composition check; the removed slot argument dropped. |
| `tests/run_tests.gd` | Prints the user data directory and stops when requested QA isolation failed. |

**Tooling and docs**

| File | Change |
|---|---|
| `tools/qa_godot.py` (new) | Runs Godot with a fresh throwaway user-data home (`APPDATA`, `XDG_DATA_HOME`, `HOLLOW_CHOIR_QA_HOME`). Optional hidden window for captures. Standard library only. |
| `tools/qa_user_data.gd` (new) | The isolation guard, preloaded (no `class_name`, so a stale class cache cannot break the runner). |
| `tools/capture_runner.gd`, `capture_battle.gd` | Folded in the ignored `.godot/capture_ui_v02_runner.gd` states. New `setup`/`resumed` states. Every held moment is labelled as a fixture. |
| `docs/.gdignore` (new); removed 15 generated import artifacts | D5. |
| `README.md`, `docs/TESTING.md`, `docs/DATA_CONTRACTS.md`, `docs/RELEASE_NOTES.md` (new) | D7, QA launcher, captures, expected diagnostics, interface notes. |
| `docs/design/V02_UI_INTERACTION.md`, `docs/DESIGN_DOCUMENT.md`, `docs/CLAUDE_PROMPT.md` | Factual pointers only: DetailsPanel removed; V0.2.1 is a no-design-change cleanup. |

## 3. Architecture, data contract and public interface

**Engine → presentation path is unchanged:** `BattleEngine` request → `BattleScene._answer_*` →
widget `begin(..., preparing=true)` → 400 ms scene-bound real-time tween → `start_timing()` →
`finished` → submit. Playback runs only through `BattleEventPlayer` and `PresentationLedger`.
No widget computes damage, status chance, eligibility, grades or reaction legality.

**Inspection provider protocol (now documented).** A source supplies text via `get_tooltip(point)`
and a typed payload via `inspection_readout` / `inspection_intent` / `inspection_unit` metadata
callables (source-local point). The text is also the re-render key. A unit body's text is now
`UnitReadout.plain_text()`, so the key covers every field the card shows.

**Knowledge and ledger guarantees preserved.** `plain_text()` reads only readout fields. The readout
still takes mutable facts from the ledger and queries research only at planning points. The existing
`test_structured_unit_readout_uses_presented_values_and_gates_affinities` (engine HP ahead of
playback, affinities withheld outside planning) passes unchanged.

**New or changed public interface:**

- `HoverInspector.claims_wheel(hovered: Control) -> bool`, `follow_keyboard()`, `follows_pointer() -> bool`
- `ActionMenu.wheel_claimed: Callable`; `ActionMenu.row_focused(option)` (group parameter removed)
- `UnitReadout.plain_text() -> String`
- `PreviewPanel.card_height(readout) -> float`; `show_readout(readout)`; `describe(readout, details)`; `describe_details(readout)`
- `UITheme.plain_text(bbcode) -> String`
- `BattleLayout.supplies` (was `familiar`); fields `header, timeline, stage, dock, help, actions, preview, supplies, timed`
- `ActionPicker.setup(engine, menu, battlefield, info)`; `Battlefield.set_active(uid)`, `set_highlight(uid)`, `set_highlights(uids)`; `UnitView.setup(unit, ledger)`; `IntentRail.arrange(area)`
- `BattleScene.cover_for_host()` now also hides the battle; `resume_from_host()` shows it.
- The widget contract (`begin(..., preparing)`, `start_timing()`, `is_preparing()`), `PREPARATION_MS = 400` and `FamiliarDefinition.display_scale` are untouched.

All callers, tests and contracts were updated in the same change. No compatibility shims remain.

## 4. Save and version impact

No save, settings, content-ID or binding format changed. `save_version` stays 1. The application
version moved from 0.1.0 to **0.2.1** in `project.godot`, the single source, which the title screen
displays and saves stamp as informational `game_version`. Older saves load unchanged, so no
migration is needed. Explicit saved bindings and the six unselected music candidates are untouched.
Release notes: [`docs/RELEASE_NOTES.md`](../RELEASE_NOTES.md).

## 5. Validation (exact commands and results)

Baseline: a fresh `git clone` of `8d71810` in a scratch directory, with isolated `APPDATA`.
Final: a fresh copy of the finished working tree (no `.godot`), run through the new launcher.
`G` is `C:\Users\Adrian\Code\Games\Godot_v4.7.2-stable_win64_console.exe`.

```sh
python tools/qa_godot.py --godot G --headless --import
python tools/qa_godot.py --godot G --headless --script res://tools/check_scripts.gd
python tools/qa_godot.py --godot G --headless --script res://tests/run_tests.gd
python tools/qa_godot.py --godot G --headless --script res://tools/simulate.gd -- --encounter=all --exec=MIXED --runs=10 --seed=1
```

| Check | Baseline `8d71810` | Final |
|---|---|---|
| Fresh import | exit 0; **44 locale warnings**; translation files generated in `docs/` | exit 0; 0 warnings, 0 errors; nothing generated in `docs/` |
| Script check | 180 checked, 0 failed | **179 checked, 0 failed** (−2 deleted widgets, +1 guard) |
| Full suite | 184 passed, 0 failed, 1,665 assertions (37.6 s) | **187 passed, 0 failed, 1,696 assertions** (42.6 s) |
| Simulation smoke | exit 0 | exit 0; **output identical** apart from the timing line |
| Event fingerprint (96 battles: 8 encounters × 3 default loadouts × seeds 1–4; SMART autopilot, MIXED execution; every event field in order plus the input log) | total SHA-256 `dfc16832…f7f82` | **identical** |
| `BattleLayout.compute` (6 window sizes × 8 text scales) | 48 cases | **identical** |

Expected diagnostics in both full runs: four invalid-save fixture errors and one
`rejected action (Needs 5 Focus)` warning. No other errors or warnings appeared. The final suite
printed `User data: …/hollow_choir_qa_…/Godot/app_userdata/Hollow Choir (isolated QA home)`.

**Mutation checks** ran on a scratch copy; the restored files hash-match the working tree:

| Mutation | Test that failed |
|---|---|
| `ActionMenu` ignores `wheel_claimed` | wheel-order test: details 0, list 54 / 22 |
| Unit key reverts to title only | cover test |
| Battle not hidden while covered | Setup-layer test |

**Brief checklist coverage** (existing, plus the new tests): immediate hover, stable subject and
modifier behaviour, Hold release/focus loss, Toggle/Always; wheel over action and supply buttons,
expanded sources, enemy sources and inside the card; explicit recipient review, cancellation and
one submission; Setup/resume without stacked menus, stuck pause or background input; all four
command types grading after preparation with fresh-press latches; preparation at zero time,
ignoring early input, focus freeze and restart cancellation; reaction legality, impact, assist pause
and held Confirm; announcement fit, empty suppression and hover suppression; support descriptions
and per-icon explanations; ledger-driven state and corpses; Cinder Pup, bars and reduced motion;
Practice at five resolutions × 100/150/200%.

## 6. Rendered evidence and unresolved defects

Real scenes rendered with OpenGL Compatibility at 1280×720, using `tools/capture_battle.gd` through
the launcher (hidden window, default settings). They are **capture fixtures**: tweens were held,
clocks frozen and pointer/focus input was synthetic. They show layout and state, not timing skill
or latency.

- [Opening announcement, pointer over an ally](v0_2_1/opening_1280.png) — panel 560×32.8, no card over it
- [Opening Flooded Ground card, 200%, reduced motion](v0_2_1/opening_condition_200_reduced.png)
- [Guard, expanded: authored rules and named effects](v0_2_1/guard_expanded_1280.png)
- [Enemy unit card, expanded (UnitReadout)](v0_2_1/enemy_expanded_1280.png)
- [Recipient review ("Pick an enemy")](v0_2_1/target_review_1280.png)
- [Actual attack meter during preparation (0.0 ms)](v0_2_1/prepare_command_1280.png)
- [Actual reaction ring/cards during preparation, 200%](v0_2_1/prepare_reaction_200.png)
- [Live command](v0_2_1/command_live_1280.png) and [condition card mid-flight](v0_2_1/condition_flight_1280.png)
- [Setup covering a paused battle, after the D3 fix](v0_2_1/setup_1280.png) and [resumed battle](v0_2_1/resumed_1280.png)
- [Settings at 200%](v0_2_1/settings_200.png): Back reachable, content scrolls (code unchanged by this pass)

**Remaining defects and observations (not fixed here):**

1. **UI layout (ChatGPT):** at 200% the reaction help bar still ellipsizes its tail
   ("Parry unavailable ·…"), as in the earlier review's R4. The 200% Evade card's Flooded Ground
   caveat continues below the card fold; it scrolls, as the contract allows.
2. **Repository:** many committed blobs contain CRLF although `.gitattributes` requests LF. The
   next commit touching them will renormalize whole files. A separate `git add --renormalize .`
   commit would keep content diffs readable.
3. **Latent:** the turn-order tooltip reads live Tempo. No current content changes Tempo
   mid-battle, so nothing can leak today.
4. **Maintenance:** tests and the capture tool still use many private members. That is acceptable
   for UI integration tests, but it means renames need the same repository-wide search used here.

## 7. Pillar assessment

| Pillar | Effect of this pass |
|---|---|
| READ | Cards cannot keep stale facts on screen. Setup shows no stray battle text. Pause has one consistent explanation. Layout and art are unchanged. |
| REACT | Clocks, windows, graders, latches and preparation are untouched, and their tests pass. Wheel ownership is now deterministic. |
| ADAPT | Knowledge filtering and ledger ordering are preserved. The unit key exposes only what the filtered readout already shows. |
| EXPERIMENT | Practice/Lab are unchanged. Isolated QA runs make results and captures reproducible, independent of local preferences. |
| AFFECT THE WORLD | Unaffected; still a later milestone. |

## 8. Remaining human acceptance and deferred work

**Human gates (open):** fresh-player READ/REACT sessions ([session pack](../playtests/M1_1_SESSION_PACK.md));
physical controller navigation; colour-vision and contrast review; comfort and pacing of the 400 ms
preparation beat; 200% readability on the target monitor; art cleanup approval; music audition and
selection. Nothing here claims release readiness or that the codebase is "ready for the full game".

**Deferred, smallest first:**

1. Migrate `UnitDetails.describe` tests to `UnitReadout`, then remove the production-unused formatter.
2. Share one status-tile painter between the action and move cards, with explicit geometry and a visual check.
3. Cache the reaction cards' per-frame `StyleBoxFlat` allocations.
4. Decide whether the uncalled `IconPainter.draw_*` fallbacks stay (UI owner).
5. Look up announced conditions by ID rather than display name. The event carries only the name today.
6. Separate the line-ending renormalization commit.
7. `BattleScene` (972 lines) still owns dock visibility, the timed flow and result text. A
   `BattleResultSummary` helper is the cleanest next extraction, done only when results change.

**Questions for the Director:** (1) Confirm that the removed `DetailsPanel` and `PartyCard` should
stay removed rather than return as designs. (2) Should R4 (the 200% help-bar tail) be shortened?
(3) Should procedural `IconPainter` icons stay as a fallback?
