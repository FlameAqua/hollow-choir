# V0.4 fifth playtest presentation — 9 October 2026

Adrian's status/toolbelt/inspection feedback and subsequent action-menu request are implemented in the shared working tree. This continues the fourth presentation pass and preserves Claude's completed engineering work. No save-schema or combat-rule changes, commits, publishing or area-scene regeneration.

## Changes

- The action grid has two columns and room for four rows. Its ScrollContainer and hero heading are removed. The action and inspection panels extend 18px lower, from 186px to 204px high on the fixed game canvas. The footer is one small line; the battlefield retains its previous space. Existing keyboard focus and action-replacement behavior remain. Adrian's final adjustment centers the group vertically within the frame as well as retaining its equal horizontal margins.
- Each turn now announces the combatant: **The Hollow's Turn**, **Bogshell 1's Turn**, etc. Ally announcements use the authored utility frame and green type; enemies use the separate authored attack frame and red type. Enemy numbers follow the same encounter ordering as the intent badges. Announcements precede selection/reaction timing and scale their hold with combat speed.
- All tool and condition buttons explicitly center their icons horizontally and vertically. This fixes the Flooded Floor drop and the log/pause alignment while retaining the subtle frames and shared toolbelt.
- Unit plates reserve the complete bottom status-cell outline plus clearance. Broken and Burn remain entirely within both the unit and battlefield bounds.
- Inspection has equal 14px outer margins and 6px internal insets. The former extra 12px on the right is replaced with 6px on each side. The footer is likewise inset, clearing the bottom ornament. Scrolling remains available in inspection and Supplies.
- **Right-click an inspectable combat element to pin its current description. Right-click again to release it.** Actions, supplies, units, intents, resource/status fields and plain condition rules use the existing public readout/tooltip providers. Pinning never submits an action or spends Focus. Hovering other subjects preserves the pinned card. The footer identifies the pinned state. Modal/timed/turn boundaries clear the old pin, as does a disappearing source.
- Hovering structured fields within inspection opens one small textured explanation to its left, kept within the canvas. It does not replace the parent card. Focus/charges, target/timing scope, damage, Break, support effects, intent threat/reaction fields and unit resources/effects expose local help. Ordinary outside hover still has only one inspection dock; native delayed tooltips remain suppressed.
- The south idle mask now has matching two-by-two dark eye apertures. A generated localized repair is integrated into a versioned v05 atlas/resource. Every pixel outside the two `(27,27,7,5)` inserts is identical to v04. Head/boot stabilization, torso breathing, other facings and walk animations retain the previous behavior. [Source, prompt and provenance](../art/first_footsteps_v01/fifth_playtest_prompts.md).

## Capacity and inspection semantics

The current weapon loadouts contain seven non-item actions and Mara has five. The eight-action rendered fixture adds the existing Guard action to its temporary in-memory Hollow, then asks the engine for real ActionOptions; it does not ship an extra ability or modify a save. Adrian's proposed future allocation of two attacks, two techniques, two spells, Identify and a flexible eighth slot remains a design direction. This pass provides room for eight without deleting existing stance/Guard behavior or imposing a new loadout rule.

Pinning preserves a filtered readout snapshot during the current planning phase, including its original target estimate. It deliberately does not follow a newly hovered subject. Returning to normal hover gets fresh readouts. The surrounding battle and target-review controls keep their existing behavior.

## Verification

- Full isolated headless suite: **304 passed, 0 failed, 4,117 assertions** (86.86s).
- Final rendered fifth-pass tests: **5 passed, 0 failed, 87 assertions**. Real mouse input through the scaled 2560×1440 window covers pin/release, field help, supplies/intents/conditions, no action submission/Focus spend, modal clearing, eight visible actions, status geometry and separate turn frames.
- Existing rendered interaction regressions: **32 passed, 0 failed, 401 assertions**.
- Fourth rendered regressions with the v05 sprite: **3 passed, 0 failed, 39 assertions**, including identical heads/boots and changing torso pixels for all eight idle directions, dialogue acceleration/autoscroll and battle-log scrolling/history.
- Compilation: **245 scripts checked, 0 failed**. Material integrity: **264 checks, 0 failures**. Whitespace validation passes.
- These counts are the completed baseline before the final source-destruction guard and small vertical-centering adjustment. The source guard now also runs while the pointer is inside inspection. No new regression run was started for the centering change, per Adrian's request; its layout was checked with a native capture.
- The expected corrupt-save, future-save and deliberately rejected isolation fixtures print diagnostics during the full suite; they pass their negative-case assertions. Every run uses an isolated QA home and does not touch Adrian's real settings or progress.

## Rendered evidence

- [Eight visible actions](v0_4_fifth_polish/eight-actions.png) — the temporary eight-action fixture described above.
- [Final centered action group](v0_4_fifth_polish/centered-actions.png) — shipped seven-action hammer loadout, with the same four-row geometry as the eight-action capacity fixture.
- [Pinned action with local Focus help](v0_4_fifth_polish/pinned-action-field.png).
- [Pinned unit with Health help](v0_4_fifth_polish/pinned-unit-field.png).
- [Broken and Burn status clearance](v0_4_fifth_polish/status-plates.png) — presentation-ledger fixture, not a fabricated battle result.
- [Ally turn frame](v0_4_fifth_polish/ally-turn.png), [enemy turn frame](v0_4_fifth_polish/enemy-turn.png).
- [Registered native mask repair, enlarged without filtering](v0_4_fifth_polish/hollow-mask.png).

Further integrated engineering review: [Claude continuation brief](../briefs/V0_4_FIFTH_PLAYTEST_ENGINEERING.md).
