# V0.4 fourth playtest presentation — 9 October 2026

Claude's [third engineering review](V0_4_THIRD_PLAYTEST_ENGINEERING_REVIEW.md) is acknowledged. Action replacement, transactional journey reset, expanded root/prop footprints, input hysteresis, victory-return trigger arming, immediate motion settings and audio teardown are implemented by Claude. This pass preserves that work. Shared `dev` remains uncommitted after `6d8401d`, application 0.3.0 / save 1. No world-area regeneration or save-schema change.

## Presentation changes

- Small framed controls and timeline portraits use the existing `material_v02/textures/tooltip.png`, matching Adrian's attached thin stitched frame. Tools use smaller 23px glyphs inside one stitched toolbelt. Action icons are 24px with 17px edge clearance. Larger panels retain their existing authored frames.
- Turn-order material tiles across the bar instead of stretching its grain. The left emblem is inset from the corner decoration. Conditions cannot be clicked or keyboard-focused, and an authored horizontal divider separates them from the toolbelt. The round count is small and sits at bottom right.
- Broken no longer gets a persistent blue word over the sprite or an intent badge. Its icon joins the enemy's bottom-right status row on the same dark backing as other effects. Timeline Broken markers still explain skipped activations. `broken.png` is a presentation-only ledger fixture, not evidence of a resolved break event.
- Inspection text reserves 12px beside its scrollbar. Reaction cards retain the key, icon, name, availability and timing feedback. Long explanations move to **Pause → Reaction help**; Back restores Pause without resuming the battle. No timing, grading, first-press or legality rules changed.
- NPC names are 22px and dialogue 20px, leaving most of the card for speech. Holding physical Space accelerates the typewriter from 38 to 190 characters/second. The latest revealed line scrolls smoothly into view, with vertical edge fades and space below the final line. Existing Confirm-to-reveal and subsequent explicit Close behavior remain.
- Battle log uses an explicit ScrollContainer with one content owner. Wheel, thumb, Page Up/Down and Home/End work; arriving events preserve a history position until the reader returns to the latest event. Opening Pause hides the log so it cannot intercept input behind settings/help. The old wheel test passed before this change in a rendered run; the new test additionally covers the actual Pause → Battle log route through a 2560×1440 window transform.

## Idle art and app icon

Built-in image_gen produced new versioned source siblings. Original sources remain intact. [Exact prompts and provenance](../art/first_footsteps_v01/fourth_playtest_prompts.md).

- [App icon PNG](../../assets/art/global/icon/hollow_choir_v01.png), [multi-size Windows ICO](../../assets/art/global/icon/hollow_choir_v01.ico), [original source](../../assets/art/global/icon/sources/hollow_choir_v01.png). Project icon settings now point to these. ICO contains 16, 24, 32, 48, 64, 128 and 256px sizes. No distributable build or Windows shortcut packaging was created.
- [Revised idle source](../../assets/art/world/first_footsteps_v01/sources/hollow_idle_v04.png), [native atlas](../../assets/art/world/first_footsteps_v01/atlases/hollow_idle_v04.png), [frames](../../assets/art/world/first_footsteps_v01/frames/hollow_motion_v04.tres). Export measures opaque silhouettes rather than almost-transparent fringe. All frames share the foot baseline. The game renderer holds the first frame's head/mask and boots while switching the authored torso/scarf pixels, preventing both eye-shape changes and sideways head movement. Southwest's front-diagonal standing pose is mirrored to face the proper direction. Walking remains on the existing frames. Reduced motion holds frame zero.
- `tools/prepare_fourth_polish.gd` prepares mechanical atlas/PNG outputs. The ICO is a format conversion of the prepared PNG. Native rendered comparisons in `test_fourth_playtest.gd` verify identical upper 32 rows and lower 12 rows across both idle frames in all eight directions, while confirming that torso pixels still change.

## Music

All four new inbox originals are preserved. Both Gloamstead versions and both Briarfen exploration versions now have decoded, gain-matched Ogg runtime exports, typed playlists and delivery records. Gloamstead and Reedway area definitions request the corresponding cues, including after returning from combat. Versions overlap through the existing equal-power three-second playlist transition; scene changes retain the existing 0.75-second fade. These are independent arrangements, not beat-aligned stems. Music Lab exposes both playlists. Listening acceptance of the joins remains Adrian's.

## Verification

- Full isolated headless regression: **299 passed, 0 failed, 4034 assertions** (72.13s).
- Final rendered regressions after art registration and dialogue spacing: **3 passed, 0 failed, 39 assertions**, including eight-direction pixel identity, hold-Space/smooth scroll, Help/Back pause preservation, and scaled-window battle-log wheel/history/Home/End.
- Final world presentation: **11 passed, 0 failed, 196 assertions**.
- Final script check: **243 checked, 0 failed**. Material integrity: **264 checks, 0 failures**.
- Python importer/preparation/isolation tests: **10 passed**. The test process's TEMP/TMP were pointed into `.godot/qa/python-temp` because the sandbox's default temporary directory denies access.
- Expected invalid-save and isolation-rejection diagnostics are negative-test fixtures. Real player saves/settings were not used. `git diff --check` passes; existing line-ending normalization notices are not whitespace failures.

Native evidence: [planning](v0_4_fourth_polish/planning.png), [revealed dialogue](v0_4_fourth_polish/dialogue-revealed.png), [reaction window](v0_4_fourth_polish/reaction.png), [reaction help](v0_4_fourth_polish/reaction-help.png), [scrolled battle log](v0_4_fourth_polish/log.png), [Broken status](v0_4_fourth_polish/broken.png). Eight pairs of 64px rendered idle proofs are in the same folder. Captures use isolated, in-memory fixtures and do not certify human timing, listening or visual preference. Late presentation-only refinements were followed by focused rendered/world/asset checks rather than rerunning unrelated combat simulations.

Next engineering review: [fourth continuation brief](../briefs/V0_4_FOURTH_PLAYTEST_ENGINEERING.md). Adrian can begin playtesting this working tree now.
