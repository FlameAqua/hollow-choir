# Claude continuation — third First Footsteps playtest

You are Hollow Choir's lead gameplay/backend engineer. Adrian explicitly delegates the functional fixes below to you. Implement them and fix integration bugs you find; this is not a review-only request. Codex owns direction, art, UI, copy and audio. The third presentation pass is complete in the shared working tree.

Work in `C:\Users\Adrian\Code\Games\hollow-choir`, existing uncommitted `dev` checkout after `6d8401d`. Inspect status and preserve every shared change. Application remains 0.3.0 / save 1. Do not commit/push, reset files, regenerate dressed areas or run `build_world_areas.gd --force`. Preserve the new user music files under `assets/audio/source/inbox/`.

Read `docs/reports/V0_4_THIRD_PLAYTEST_POLISH.md`, `docs/briefs/V0_4_SECOND_PLAYTEST_ENGINEERING.md`, the previous two polish reports and your integration review. Native third-pass screenshots are in `docs/reports/v0_4_control_polish/`.

## 1. Switch actions during recipient selection

Adrian cannot choose another attack/item after entering target review. The action buttons remain visible but `src/ui/battle/action_picker.gd::_on_option_chosen()` returns unless `_mode == Mode.MENU`. `back_to_menu()` already supports Escape, but direct replacement is missing.

Allow deliberate selection of another legal action or item during `Mode.TARGET`. Replace the pending option and rebuild its legal recipients and preview, with no stale target or extra submission. If the replacement needs no recipient, follow the established confirmation behavior for that action. Illegal/disabled rows must not destroy the existing choice. Hover inspection must remain separate from choosing; hovering or pressing Alt must never replace the selected action. Keep an obvious Back/Cancel route for keyboard/controller and explain it compactly. The existing target prompt now uses the painted tooltip frame; preserve that styling.

Test enemy-to-enemy, enemy-to-ally/item, ally-to-enemy, self/area/no-recipient transitions, canceled review, invalid options, death/eligibility changes where applicable, keyboard/controller navigation, item limits and Focus accounting. Nothing is spent until an actual submission, and one confirmation submits once. Preserve the explicit recipient review even when only one recipient is legal.

## 2. Add a player-facing exploration reset

No reset is currently exposed. `GameState.new_game()` replaces progression in memory and is used by fixtures; it is not a transactional player-facing reset. Do not call it blindly from a button or reset Adrian's actual save as part of implementation/testing.

Recommended contract: add **Reset journey** to the exploration menu, available from a safe exploration state. It resets the current exploration journey, discoveries/route links, cleared world sites, bell/latch flags and any pending encounter entry to the initial Gloamstead square state. Preserve bestiary research, weapon mastery, equipped loadout and settings. This bounded reset matches an Exploration reset without erasing unrelated combat progression. State the boundary in the confirmation copy, for example:

> Start this journey again from Gloamstead? Route discoveries, cleared encounters and the wayside bell will reset. Research, weapon mastery and equipment will be kept.

Use **Cancel** (initial/default focus) and **Reset journey** with the existing painted modal/button styles. Do not add a seventh title option that makes the title menu scroll again. Avoid reset while a battle, result commit, pending write or host transition owns the session. Build a candidate progression state, save successfully, then publish it and rebuild the host at a safe initial anchor. On a failed write, leave the live journey untouched and expose the existing failure/retry path. Keep the schema at save 1 if the existing representation suffices.

Test cancel and confirmation, repeated clicks, disk/write failure and retry, fresh session/reload, pending encounter cleanup, reset gates/discoveries, preserved research/mastery/loadout/settings, one-slot behavior and no leakage from isolated test homes. Make the copy match exactly what the implementation preserves.

## 3. Complete the earlier physics correction

The willow/root collision issue remains outstanding from the second brief. Use its exact geometry evidence and `tools/probe_willow_footprint.gd`; a generic 54×24 rectangle was already insufficient. Author intentional ground footprints for the visible trunk/roots, preserve walk-behind canopies and shoreline access, sweep real approaches from multiple directions, and return native collision-overlay evidence. Recheck posts, bells, benches, building edges and combat return anchors. Do not infer collision acceptance from dimensions alone.

## 4. Verify presentation integration and fix issues found

- The painted controls are in `UICraft.CONTROLS`, alongside the preserved v02 material palette. `UITheme.selector()` explicitly gives popup Windows the pixel font/theme and nearest filtering. Keep the checkmark, dropdown, scrollbar and toolbar assets; do not restore engine defaults.
- The title menu has six fully visible buttons with a bitmap wordmark and no ScrollContainer. Its bounds update after container minimum-size changes. Preserve the fixed display presets and pixel-font legibility.
- Combat names the encounter and shows `Round: N`; its outer canvas uses a quiet peat material. Intents have opaque dark sockets and centered number badges. Tiny target portraits are removed. Only hovering a move region marks its public `IntentReadout.target_uids` on stage. This uses a separate `UnitView.intent_targeted` flag and must never alter selectable targets, selected actions, rule RNG or filtered knowledge.
- Battle log wheel input belongs to the visible log; scrolling history pauses auto-follow, new events must not pull the reader down, and reaching the end resumes following. Preserve one-event/one-pane wheel ownership, the shared inspection dock and no duplicate native tooltips.
- Reaction medallions use the clearer v03 raster emblems, enlarged in both inspection and reaction cards, without an extra square behind the inspection symbol. Existing timing clocks, first fresh press, legality, prepare/pause/focus-loss and reduced-motion contracts stay intact.
- Bell Crow v03 has two quiet breathing poses and a four-frame one-shot fidget. `FamiliarCard` uses a private presentation RNG and an 8–18 second quiet interval between fidgets; no battle/global RNG is consumed. Reduce Motion holds the neutral pose. Verify pause/visibility behavior and edge rendering on actual backgrounds. Other familiars retain their own art.
- Continue the earlier transactional victory/defeat/retry/reload and settings/inspection/audio checks. Investigate focused-test/capture disposal warnings before describing them as production leaks; the full third-pass suite exited cleanly.

## Validation and return

Codex's final full suite: **272 passed, 0 failed, 2,843 assertions (63.92 s)**. Compilation: **235 scripts, 0 failures**. Material validation: **264 checks, 0 failures**. Run `tools/qa_godot.py` with isolated homes under `.godot/qa/`; run the full behavior suite alone and simulation parity checks when rule logic changes. Existing `test_third_playtest_log_wheel_and_intent_recipients_do_not_change_selection` covers wheel history and public-recipient markers; title tests now check all six options fit, rather than requiring the retired scrolling layout.

Return `docs/reports/V0_4_THIRD_PLAYTEST_ENGINEERING_REVIEW.md` with implemented changes, test commands/counts, native capture paths, unresolved issues and the precise build Adrian should test. Distinguish automated checks from human collision feel, controller and listening acceptance. The later neighbour-aware terrain/blending/post-effects pipeline remains a separate follow-up, outside this bug pass.
