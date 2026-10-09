# First Footsteps — second playtest presentation pass

9 October 2026 · `dev` after `6d8401d` · uncommitted · application 0.3.0 / save 1.

## Implemented

- Exploration uses eight authored standing idle pairs, feet together, at 1.4 fps. The continuous fractional vertical stretch was removed; the visual root stays at native scale, with the existing integer camera/art positioning. Existing walking cycles remain at 5 fps. Reduce Motion holds the standing frame.
- Local map now has generated fen parchment and a small Hollow head marker. Discovery, routes and positions still come only from the filtered map readout.
- Peat, worn path and boardwalk footsteps were resynthesized with softer compression, damp release and grit. Peat/path have no resonant modal tones. All original 22 non-footstep WAVs are byte-identical to the previous pass; only the three step cues changed. Preview order is four peat, four path, four wood steps in `v0_4_material_polish/footsteps.wav`. Listening acceptance remains Adrian's.
- Added 32 actual raster UI assets: stitched satchel lining, cloth and soot panels, attack/technique/utility frames, focus fittings, portrait/intent/number sockets, reaction rings and medallions, timing track/needle/cursor, painted break badge and slider furniture. Applied them to combat, world modals, settings, title/pause/result menus and interaction prompts. Supplies sit in a centred leather tray below turn order. Source sheets and exact prompts are preserved; see `docs/art/first_footsteps_v01/material_polish_v02.md`.
- Action and item inspection now scrolls from the hovered source whenever its description overflows, including without Alt. One wheel event still moves one pane. Alt adds analysis without repeating the base description. Pointer exit clears the old payload instead of restoring the last potion/action; deliberate keyboard navigation still inspects its focused/current action.
- Action cards say `1 enemy`, `All enemies`, `1 ally`, `All allies`, `Self` or `Battlefield`, followed by `Good timing` or `No timing`. The old `Good · hit` meant the preview for the Good execution grade, per direct hit; the wording is now explicit. Break damage uses the painted cracked badge. Purple/blue crack lines over Broken bodies were removed.
- Bell Crow now has four authored planted fidgets at 2 fps in combat; its original portrait and sprite remain intact. Reduce Motion holds frame zero. Other familiar art has not been regenerated.
- Audio sliders show live percentages and use painted tracks/knobs.

## Remaining engineering work: tree collision is not fixed

The willow still uses a 54×24 rectangle centred at (0,-12), below a 128×128 sprite offset (-64,-124). A read-only probe of Gloamstead `DepthSorted/Willow8_46` at (272,1504) shows painted roots spanning x=-34..44 at y=-24, and -32..37 at y=-16. The current rectangle spans only -27..27. Actual 16×9 feet queries at (40,-6), (44,-12) and (-40,-6) relative to the tree miss its collider. Some of those positions overlap visible roots; see `v0_4_material_polish/willow_footprint_probe.json` and `tools/probe_willow_footprint.gd`.

Claude should author a ground footprint from the trunk/root silhouette and verify side approaches, shoreline access and Y-sort. Tall canopy overlap while correctly walking behind a tree is a separate depth behavior; do not make the whole canopy solid. The previous blanket expansion was insufficient. No area scene or water collision was rewritten in this pass. Full implementation instructions are in `docs/briefs/V0_4_SECOND_PLAYTEST_ENGINEERING.md`.

## Verification

- Final full suite: **271 passed, 0 failed, 2,813 assertions, 62.87 seconds**, run alone in an isolated QA home after all presentation changes. No shutdown ownership warning appeared in the full run.
- Final script compilation: **234 scripts, 0 failed**.
- World art: **328 checks, 0 failures**. Material/standing/crow bitmap integrity: **195 checks, 0 failures**. The new validator caught semitransparent crow source padding; native export now aligns the opaque feet correctly rather than treating faint edge alpha as the baseline.
- After final bitmap/style adjustments, focused icon/UI checks passed **6/0 (129 assertions)** and world presentation **11/0 (187 assertions)**. All **25 WAVs** also passed hash, PCM format, frame count, clipping and tail-endpoint checks.
- Native 1280×720 captures reviewed: `v0_4_material_polish/{combat,reaction,map,settings,town,menu,item-expanded,all-enemies,break-icon}.png`. The item capture dwells 1.2 seconds with Alt held. Scope remains visible for an unavailable all-enemy technique. The known Hammer Blow capture shows the painted break-damage symbol. Captures are synthetic fixtures, not playtest acceptance.
- Existing shutdown ownership warnings remain in some interrupted reaction captures and focused UI runs (4–9 ObjectDB instances / 2–4 resources). The full suite exits without those warnings. Claude should investigate retained callbacks/timing fixtures; do not label these proven gameplay leaks or silence them.

Human controller, movement/collision, listening and art acceptance remain open. No commit, push, schema change, version bump or map regeneration was performed.
