# V0.5 — Character-menu atlas presentation and continuation

9 October 2026 · Adrian's visual feedback · shared uncommitted `dev` · application 0.5.0 / save 1

Equipment pockets now reuse the supplied atlas's cloth and leather square frames, with quieter
empty cells and warm hover/keyboard focus. Ingredient quantities and Actions/Magic/Skills use
the matching dark and gold rectangular strips. The gold strip indicates hover or keyboard focus;
inspection remains read-only. Ten starting slots, reward-based growth, equipped checks and the
existing hover/Alt/right-click-pin behavior are preserved.

`UICraft.inventory_slot()` scales the complete square frame to each 80×80 pocket.
`style_character_row()` nine-slices the existing `slider_track` / `slider_fill` textures from the
lower material-atlas row, keeping their full diagonal end fittings outside the tiled centre.
Occupied/empty pockets use `inspection` / `cloth`. No artwork was generated, repainted or replaced,
and meter/combat styling is unchanged. Compact loot retains its existing presentation.

Application metadata is now **0.5.0** at Adrian's request. The title displays `v0.5.0` and new
save envelopes inherit the application version. Save format remains **1**; old-version fixtures
and historical reports retain their original numbers.

The [current Claude continuation](../briefs/V0_5_CONTINUATION_FOR_CLAUDE.md) puts V0.5B
Forge/Stillroom next, followed by Codex station integration and the bounded V0.5C specification,
Claude's exploration backend and Codex's visible integration. Automated verification and focused
reviews continue per stage; the full human/controller/listening test follows the integrated
V0.5 build. The B brief, roadmap and return queue now reflect this order and current version.
This prepares a handoff; it does not claim Claude has run or B/C have been implemented.

## Fresh validation

- Script compilation: **274 checked, 0 failed**.
- Focused character-menu tests: **5 passed, 0 failed, 81 assertions**.
- Final world regression, Compatibility / Dummy audio after fixture isolation: **106 passed,
  0 failed, 2,791 assertions, 27.53 s**, including the dedicated focus-loss case.
- Seven final game captures inspected: fresh and expanded inventory, Actions, Magic, Skills,
  1920×1080 inventory with Alt details and title version. See
  [capture index](v0_5_menu_atlas/README.md).
- `git diff --check`: clean.

A world run before the final strip refinement passed 106/0. A later run returned 105/1 when
the portal fixture stopped walking before arrival and consequently had no saved arrival to read;
the portal case passed alone (1/0, 8 assertions). The host fixture now disables unsolicited desktop
focus pauses during scripted movement, matching the other hidden-window fixtures. The dedicated
focus-loss test explicitly restores that behavior before sending its notification. Production
pause behavior and portal rules are unchanged.

The preceding A report's 371/0 full-suite result is inherited evidence, not a full-suite rerun
for this presentation pass. Human acceptance remains open. No commit or push was made.
