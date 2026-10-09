# Claude continuation — fifth playtest, 9 October 2026

Read [fifth presentation results](../reports/V0_4_FIFTH_PLAYTEST_POLISH.md) and the [fourth continuation](V0_4_FOURTH_PLAYTEST_ENGINEERING.md). This supplement supersedes older action-grid and hover-footer descriptions. The third engineering review remains acknowledged; do not reimplement completed action replacement, transactional reset, root/prop collisions, facing hysteresis, victory-return arming or audio teardown. The shared tree remains uncommitted after `6d8401d`, application 0.3.0/save 1.

Codex has completed the presentation changes: a centered fixed two-column grid with capacity for eight actions; no action scrollbar or hero title; larger bottom panels and one-line footer; ally/enemy turn banners with separate existing bitmap frames; centered tool icons; status clearance; symmetric inspection margins; right-click pin/release and local field help; and a localized v05 idle-eye correction. Preserve these assets and layouts. Do not regenerate dressed areas or replace authored bitmap frames with geometry.

## Engineering follow-up

Test the integrated behavior and fix concrete defects, concentrating on these boundaries:

1. Right-click pin/release for actions, potions, units, intents, conditions and resource/status fields. It must never submit an action, change Focus/charges or secretly alter a battle request. A pin retains the original filtered readout snapshot during the planning phase; entering target review and hovering another target must not overwrite it. Unpin returns normal hover. Alt details, wheel scrolling, pause/settings, Setup, restart, result transitions and source destruction must not leave stale or hidden blockers.
2. Field explanations belong beside the main inspector and never replace its subject. Verify item charges, Focus, scope/timing, unknown damage, Break, allowed/unavailable reactions and status rules against the engine's public readouts. Preserve research filtering and presentation-ledger chronology. Do not restore native duplicated delayed tooltips.
3. Verify turn announcements match encounter numbering, stay before timed input clocks, respect combat speed/reduced motion and remain safe under pause/focus loss, autopilot, channels, skipped Broken turns and restarting mid-announcement.
4. Check all current loadouts, companion actions and resolution presets fit the fixed action grid. Current weapon loadouts have seven non-item actions; the rendered eight-action test adds real Guard only to a temporary in-memory fixture. Adrian proposes an eventual eight-slot budget: two attacks, two techniques, two spells, Identify and a flexible/future slot. Inventory any data that exceeds eight and report the appropriate loadout/content decision; do not silently discard actions or invent a legendary action. Preserve the existing stance/Guard choices.
5. Continue the fourth brief's broader integration checks, including exploration/audio/reset/collision behavior and battle log scrolling. Address real backend defects found, with focused regression coverage.

## Verification baseline

Completed baseline before the final source-destruction guard and vertical-centering adjustment: full headless **304/0, 4,117 assertions**; rendered fifth-pass **5/0, 87 assertions**; prior interaction tests **32/0, 401 assertions**; fourth-pass rendered **3/0, 39 assertions**. Scripts **245/0**, material checks **264/0**. Adrian requested no new regression run for the small centering change, which was visually checked in a native capture. Use `tools/qa_godot.py` with distinct `.godot/qa/` homes for all runs; rendering/input checks need the hidden native Compatibility window. Never test against the player's real save/settings. Evidence and fixture limitations are linked in the presentation report.

Return `docs/reports/V0_4_FIFTH_PLAYTEST_ENGINEERING_REVIEW.md` with bugs found, changes made, remaining observations and exact verification results. Reference any unresolved fourth-pass work there rather than duplicating historical requests.
