# Claude continuation — second First Footsteps playtest

You are Hollow Choir's lead gameplay/backend engineer. Implement necessary bug fixes as well as testing; this is not a review-only request. Codex owns direction, UI/art/copy/audio and has completed the second presentation pass. Adrian will review the result.

Work in `C:\Users\Adrian\Code\Games\hollow-choir` on the existing uncommitted `dev` checkout after `6d8401d`. Inspect status first and preserve all shared changes. Application stays 0.3.0, save stays 1. Do not commit/push, reset the tree, regenerate dressed maps or run `build_world_areas.gd --force`.

Read `docs/reports/V0_4_SECOND_PLAYTEST_POLISH.md`, the prior `V0_4_PLAYTEST_POLISH.md`, your `V0_4_INTEGRATION_ENGINEERING_REVIEW.md`, and `docs/briefs/V0_4_PLAYTEST_ENGINEERING.md`. New native captures and read-only collision evidence are in `docs/reports/v0_4_material_polish/`.

## Implement the remaining collision correction

Adrian can still enter the visible willow roots from the side. Gloamstead `DepthSorted/Willow8_46` is at (272,1504), with sprite offset (-64,-124). Its 54×24 rectangle at (0,-12) covers x=-27..27, y=-24..0, while painted root spans reach -34..44 at y=-24 and -32..37 at y=-16. Actual feet queries at relative (40,-6), (44,-12), (-40,-6) can miss the collider. Reproduce with `tools/probe_willow_footprint.gd`; evidence is `willow_footprint_probe.json` in the capture folder.

Replace the shallow generic rectangle with an intentional trunk/root ground footprint, potentially a polygon or a few simple shapes. Author geometry in the scenes or a shared prop resource, not runtime sprite-alpha collision. Inspect all willows in both areas and the screenshot Adrian supplied. Verify visible ground roots versus expected walk-behind canopy occlusion and Y-sort before choosing dimensions. Preserve natural shore access; do not solve the issue by blocking the entire canopy. Recheck lamp, bell posts, bench corners, facades, boards, shoreline corners, interaction radii and the outside route/latch. Add movement tests that actually sweep approaches from several sides rather than checking only collider dimensions. Record native collision-overlay evidence.

## Verify and fix integration issues found

- Exercise one inspection dock with actions, items, enemies, intents and timeline. Scroll both directions over a source and inside the dock, with and without Alt. Short cards leave list scrolling available; overflowing cards own the wheel. Moving from Mending Draught to enemy to empty stage must leave no stale potion payload. Keyboard/controller focus must remain deliberate; modifiers must not steal the source. No native duplicate tooltip or extra popup should reappear.
- Confirm the expanded description appears once; filtered knowledge, number ranges, target scope and break claims remain honest. `Good timing` denotes preview numbers at the Good grade. `CombatIcons` now redirects break and reaction symbols to raster art.
- Check reaction legality, impact timing, first fresh press ownership, prepare/pause/focus-loss freezes and result feedback with the new bitmap rings/medallions/needle. They use the same existing clock and rules; fix any integration issue without inventing a second timing source.
- Verify the new crow idle fidgets and Hollow standing frames respect Reduce Motion, pauses and host visibility. Other familiar definitions remain unchanged. Eight walk cycles remain 5 fps; world sprite scaling stays integer/native.
- Review live audio percentages and embedded settings/pause behavior. Recheck material footsteps at surface intersections, wall pushing, small starts/stops and portals. Three appended cue indices and the original 22 non-footstep WAV bytes remain stable.
- Continue the earlier return-after-victory, failed-write Retry, duplicate completion, defeat, fresh-session and old-save checks. Fix issues through host/session ownership and preserve transactional saves.
- Investigate synthetic capture/focused UI shutdown warnings (4–9 ObjectDB objects, 2–4 resources). Full suite was clean. Check retained lambdas/readout providers, interrupted reaction/tween callbacks and fixture disposal before calling this a production leak. Do not suppress genuine ownership errors.

## Acceptance and return

Use isolated QA homes via `tools/qa_godot.py`; run the full suite alone. Codex's full behavior run was 271/0 with 2,813 assertions. Final compilation was 234/0; world art 328/0; `tools/validate_material_polish.gd` 195/0. Run simulation parity checks if backend logic changes. Preserve the actual bitmap styling, single information dock, compact help footer, standing poses, map icon and sound direction.

Return `docs/reports/V0_4_SECOND_PLAYTEST_ENGINEERING_REVIEW.md` covering implemented fixes, tests and counts, capture paths, unresolved issues and the exact build Adrian should test. Do not claim human collision feel, controller or listening acceptance from automated fixtures. The later terrain-neighbour transition/blending/post-effect pipeline is still a separate design/engineering follow-up; do not replace the playable map pipeline during this bug pass.
