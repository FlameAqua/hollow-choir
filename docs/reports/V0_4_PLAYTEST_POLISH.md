# First Footsteps — first playtest polish

9 October 2026 · Director / presentation pass · uncommitted `dev` after `6d8401d`.
Application 0.3.0; save version 1. Claude's prior integration review is acknowledged.

Adrian's first walkthrough established that the prototype loop and interactions work. This pass
addresses his movement, readability and sound feedback. Codex owns the art/UI/copy/audio work;
[Claude's engineering continuation](../briefs/V0_4_PLAYTEST_ENGINEERING.md) assigns the collision,
encounter-return and integration audit/fixes to the lead backend engineer. It is prepared for
Adrian to pass on, not sent automatically.

## Changes ready for review

| Playtest feedback | Current implementation |
|---|---|
| Side walk has permanently spread legs | New versioned side rows alternate contact and narrow passing poses. Original source/export preserved. These generated candidates need motion review for anatomy and mask continuity. |
| Slow north/south; add diagonals and idle | All walks run at 5 fps rather than 7. Original north/south images retained; four new diagonal cycles. Eight held standing poses breathe gently around their foot anchor. Reduce motion freezes breathing. |
| Props clip from the sides; shore feels too distant | Candidate post-art footprint and shore-edge corrections applied to native scenes; see engineering section below. |
| Large world text panels | Area title appears for 7 seconds, fading during the last 1.2; one active objective below it. Map/menu icons at top right. Only a nearby interaction shows a small bottom prompt. |
| Bench is a text wall; wrong initial highlight | Fixed weapon list opens with equipped item focused. Checkmark/selected state on its button; small Equipped badge in details. Icon, identity, category, flavor and individual action sections have separate spacing/colors. Details scroll independently, keeping choices and Close visible. |
| Bellkeeper dialogue should type in | 38 characters/sec. First Confirm reveals the whole line; second advances. No per-character sound. |
| Menu needs buttons and a Help section | Compact Resume / Field Guide / Settings / Help / Save / Save and return to title menu. Save/resume explanations moved into Help. |
| Combat has two/three overlapping information sources | One shared dock below the battlefield presents action, target, unit, intent and expanded analysis. Previous preview is hidden readout storage. No floating inspection card. Native tooltip text/background is suppressed in the local combat theme, preserved by the world host during theme updates. Descriptions are in the dock. |
| Supplies and footer consume too much room | Two supply buttons sit under turn order at top left. Actions and inspection share the lower dock. Footer is 28 px high with 11 px text, down from about 60 px and 22 px text. This recovers about 32 px of stage height. |
| Enemy assists/buffs are hard to see | Buff-applied playback gives the recipient a brief blue outline and support icon, a longer/larger buff label and a quiet focus sound. The feedback occurs on its presentation event. |
| Volume/settings unavailable mid-game | World menu exposes Settings; combat pause now also exposes the same embedded Settings screen. It remains paused while Settings is open and returns to Resume. Existing volume/accessibility controls apply immediately. |
| Combat feels static | Living actors have small, phase-offset, foot-anchored breathing. Reduced motion freezes it; hit areas and combat timing do not follow the sprite transform. |
| Victory returns several tiles away | Host restores the live feet/facing captured at Engage after victory commits; persistent resumes still use saved safe anchors. Engineering edge-case review requested. |
| Surface footsteps | Three soft original procedural cues: peat, stone and wood. Emitted per 34 px of actual travel, selected from authored tile material. Standing/pushing into a wall is quiet. Existing 22 softened SFX are unchanged. |
| More soundtrack prompts | [Town, exploration and optional homecoming requests](../audio/FIRST_FOOTSTEPS_MUSIC_REQUESTS.md) are ready to copy into Adrian's generator. Exploration stays silent until selected real exports arrive. |

The new movement source was generated using the built-in image tool. Source, native atlas and
final prompt specification are linked in [motion provenance](../art/first_footsteps_v01/hollow_motion_v02_prompt.md).
Mechanical extraction/reduction uses `tools/prepare_hollow_motion.gd`; it is not manual pixel cleanup.

## Engineering candidates to review with Claude

The physics pass keeps the original blocked-cell set, anchors, interaction points and portal
rectangles. It adjusts the feet/prop base rectangles and introduces water-edge TileSet alternatives.
Footprints: player 16×9, willow 54×24, town/wayside bell 78×24, square lamp 26×14, bench 44×18.
Only water sides adjoining walkable land inset 3 px; water interiors and map bounds remain solid.
There are 208 adjusted town shore cells and 557 Reedway shore cells. No sprite alpha drives physics.

`tools/polish_world_physics.gd` records the one-time authored-scene pass. It does not establish a
general terrain system. The native painted art and named point/portal geometry were compared with
the pre-polish working copy: 13,136 position/tile records preserved. Existing synthetic full-journey
tests still traverse the main route, outside loop, bell steps, overlook, latch and home return.

The victory correction keeps live coordinates in the host; it does not add them to progress saves.
Claude should review stale-coordinate cases, failed save retry, pending-entry resume, duplicate
completion and the physical clearance of narrow shore/prop approaches. That work may include direct
backend fixes, rather than limiting Claude to reviewing Director work.

Adrian's longer-term request for neighbourhood-aware tiles, transitions, texture blending and
post effects is recorded in the engineering brief. It remains future work. Surface labels and
collision insets do not implement terrain adjacency or blending.

## Verification

- Full Godot suite, run alone with isolated user/cache directories: **268 passed, 0 failed,
  2,788 assertions, 60.97 seconds**. Six new regressions cover equipped focus/bench layout,
  reveal-before-advance, diagonal/breathing presentation, material/distance footsteps,
  the shared inspection dock/theme, and Settings pause ownership.
  After the final Settings-only theme isolation, its focused pause regression also passed
  (1 test, 10 assertions); the full suite was not repeated for that local theme assignment.
- **230 scripts checked, 0 failed.** World art validator: **328 checks, 0 failures**, including
  the new walk/idle directions, transparent native cells, stable feet, slower cycles and source hash.
- **25/25 SFX** match enum/manifest/hashes and pass PCM, endpoints, peak/DC, import-normalization
  and deterministic regeneration checks. Original 22 WAVs match the pre-polish recipe byte-for-byte.
  Runtime smoke loaded/played all 25 and verified fixed voice pool, SFX mute/volume and Music isolation.
  New footstep peaks: peat −20.00, stone −17.72, wood −18.42 dBFS. These are sample peaks, not LUFS.
- Native 1280×720 Godot captures reviewed for world HUD, all bench choices/menu, dialogue and
  compact action/intent inspection. The delayed-hover captures hold for 1.2 seconds: no second native
  tooltip, raw BBCode or third information panel appears. Expanded inspection remains in the dock.
- `git diff --check` passes. Existing work preserved; no commit, push or version change.

Expected invalid-save/rejected-action/sanitize/QA-isolation test diagnostics remain documented by
their tests. The final full-suite run has no ObjectDB teardown warning. Some interrupted native
capture/focused runs report four ObjectDB instances/two resources still in use at exit; that fixture
shutdown investigation is included in Claude's brief. It is not proof of a gameplay leak or a clean
ownership audit. SFX smoke exits cleanly after stopping voices and releasing audio-thread playback.

## Native visual evidence

These are labelled capture fixtures with synthetic positioning/input, dummy audio and, for battle,
automatic intervening timing answers. They demonstrate layout, not uncoached play or listening.

- [Town HUD](v0_4_polish/town.png), [button menu](v0_4_polish/menu.png).
- Bench: [sword](v0_4_polish/bench-sword.png), [hammer](v0_4_polish/bench-hammer.png),
  [bow](v0_4_polish/bench-bow.png); details have their own scroll area.
- [Dialogue typing](v0_4_polish/dialogue.png).
- [Action dock after hover](v0_4_polish/combat-action.png),
  [intent dock after 1.2-second dwell](v0_4_polish/combat-intent-dwell.png),
  [expanded inspection](v0_4_polish/combat-expanded.png).
- [Battle embedded in the world host](v0_4_polish/battle.png).

## Next human review

Walk in all eight directions, stop/turn repeatedly and inspect passing poses/mask stability at game
scale. Approach prop bases from both sides and follow shores/boardwalk corners. Open bench after
equipping each weapon; scroll the detail cards. Reveal/advance Bellkeeper text. In battle, hover
actions/enemies/intents for several seconds, expand/scroll details, watch a Sporecaller support turn,
and change volume through Pause → Settings. Check victory returns to the engagement feet and retry
remains consistent. Listen to footsteps on the three surfaces through speakers/headphones.

The revised build's movement feel, collision fit, controller, display and listening acceptance remain
open. Generated art still needs contour/mask refinement if Adrian sees instability. Human approval
is not inferred from automated traversal or screenshots.
