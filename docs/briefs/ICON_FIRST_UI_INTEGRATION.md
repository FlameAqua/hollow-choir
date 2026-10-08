# Icon-first UI integration handoff

## IMPLEMENTATION BRIEF

The user's 8 October UI request is implemented in the current working tree. ChatGPT owns UI direction,
art integration and presentation code; Claude owns core combat architecture and can assist against the
[canonical UI contract](../design/ICON_FIRST_COMBAT_UI.md). Review the final behavior, not the earlier
four-column/context-panel layout. Preserve unrelated uncommitted engineering work.

## DATA CONTRACT

`CombatIconMap` is a native Resource with semantic `entries` and explicit `textures` references.
`CombatIcons` is the shared accessor. Existing ActionReadout / IntentReadout filter knowledge before
rendering; their rules and schema are unchanged. Displayed actor state uses PresentationLedger.
Existing SpriteFrames metadata and ActionOption/potion slots remain the data boundary. No save change.

## STATE FLOW

Action request → flat action/supply controls → existing target choice → normal engine submission.
Target review also pins UnitDetails. Hover/focus → one immediate HoverInspector, with replacement settling
and exit grace → scrollable detail. Timed request/modal → suppress inspector → existing command/reaction
clock and fresh-press latch → normal graded result. Event playback advances ledger and clears stale intent.

## ACCEPTANCE TESTS

Run `tools/check_scripts.gd`, `tests/run_tests.gd` and the UI contract's UI-01–UI-07. `test_icon_ui.gd`
checks hover transitions, knowledge-safe icons, legality, four-enemy size, supply costs, resource loading
and visual/window boundary parity. Inspect [actual Godot captures](../reports/ui_refresh/README.md), then
use the existing fresh-player session pack. Human acceptance is still open.

## KNOWN EDGE CASES

At 200%, actions scroll and resource numbers can stack. Enlarged timed cards can cover stage rings;
the full-width meter remains the timing source's visible view. Shared family icons intentionally repeat,
so action labels and duplicate enemy numbers stay. Cinder Pup has a procedural fallback. Artwork still
needs final pixel/alpha cleanup. Font fallback may render unsupported glyphs differently.

## NON-GOALS

No new inventory/equipment behavior, pet turns, enemies, animation sets, combat rules, balance changes,
resource persistence, save migration, world slice or declaration of human/art acceptance.
