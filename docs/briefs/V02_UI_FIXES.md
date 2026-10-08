# V0.2 UI fixes — implemented handoff

## IMPLEMENTATION BRIEF

User-reported UI blockers were addressed in the shared presentation path. Read
[the current contract](../design/V02_UI_INTERACTION.md). It supersedes earlier pinned target
inspection and separate Alt-overlay requirements. Preserve the current working tree and UI ownership.
Also read the latest [inspection/targeting follow-up](../design/V02_UI_FOLLOWUP.md), prompted by
Adrian's screenshot review. It supersedes repeated stage reactions, numeric threat and sole-target auto-submit.

Practice/Lab now scroll above a fixed footer. Settings adds five window sizes. Setup exclusively
covers/suspends the battle and closing it resumes directly. Modifiers no longer switch the inspector
to keyboard focus; timeline focus no longer captures later hover. One contextual inspector scrolls
from the source or within the card. Actions and enemy moves share a structured renderer, and icon
hit regions explain individual facts. Enemy icons have dark tiles/gaps; the redundant red selection
line was removed. Enlarged action grids use icons/costs and stacked supply slots. Reaction prompts
are shortened and the 150% dock enlarged for readable risks.
The follow-up removes repeated turn/target labels and pet readiness circles; adds separated unit
fields/affinity groups and a named threat badge; renders inspection at 82% through native font sizes;
gives wheel ownership to action/supply lists while collapsed; uses honest conditional hints; and redraws Flooded
Ground/Spore Fog as quiet pixel terrain art. Single-recipient targeted actions now require review.
The later [pre-push polish](V02_PRE_PUSH_POLISH.md) gives expanded details wheel priority over the
action/supply source, enlarges Cinder Pup and adds a brief preparation beat before manual timing.

## DATA CONTRACT

Global settings gain `window_resolution: Vector2i`, default 1280×720; five supported values, invalid
fallback, no progress-save changes. IntentReadout gains public `target_names` captured with the
displayed intent. Menu previews use the picker's actual default/selected target policy. Inspection
providers receive local event coordinates. No engine rule, timing, content or audio contract changes.
UnitReadout copies ledger values/effects and filtered planning knowledge, plus the displayed intent
reference. UnitView providers exclude individual field hit regions. InspectionContent reports
transformed body height. ConditionArt consumes announced condition state; it is decorative only.

## STATE FLOW

Pointer/focus navigation → inspected control/icon → single bounded card → optional expansion/scroll.
Target review keeps facts in the dock rather than pinning another overlay. Timing suppresses hover.
Setup during timing/playback queues to the safe point → host suspends covered battle/hides its modal
→ close host → resume/refocus. PresentationLedger and the displayed intent remain authoritative.
Keyboard target inspection uses `ActionPicker.reviewed_target_uid()` when GUI focus is released;
its `keyboard_navigation` signal preserves source ownership even when the picker consumes a key.
Fields within a card explain themselves in its footer, without nested popups.
Targeted action → review even with one recipient → explicit click/Confirm → submit once; Back →
same menu without spending. Top guidance names the recipient side. Hold-details state follows the
actual input action; release/focus loss collapses it. Toggle/Always preferences remain honored.

## ACCEPTANCE TESTS

See `tests/ui/test_v02_ui.gd` and the updated host/target boundary checks. Run script checks and the
full suite. Review [rendered evidence](../reports/v02_ui/README.md). Reproduce modifier hover,
timeline → supply hover, overflow scrolling, Setup/resume and deliberate Enter confirmation.
The follow-up suite checks sole-ally Intercept/cancellation, wheel over a real action button, Alt
release over the card, native font raster sizes, named threat bounds and ledger/knowledge isolation.

## KNOWN EDGE CASES

Saved explicit Space/Z confirmation overrides remain user-owned; the new defaults do not reset them.
Fullscreen uses desktop resolution, while window sizes fit the work area. Long analysis at 200%
needs scrolling. Enlarged timing can cover scenery. The old DetailsPanel stays hidden. Human
controller/color-vision/comfort checks are pending; synthetic timing captures do not certify play feel.
Advanced analysis still scrolls at enlarged text. Normal damage means no affinity bonus/reduction.
Reaction legality remains in move inspection/active reaction input, rather than repeated over actors.

## NON-GOALS

Subsequent support-card/familiar/announcement work is implemented in
[the support presentation handoff](V02_SUPPORT_PRESENTATION.md); preserve that newer shared contract.

No combat rebalance, new input timing, target eligibility, corpse mechanics, inventory, music
integration, release push or wholesale rewrite. Do not restore older pinned inspectors/native accept
defaults or replace the filtered readouts with widget-owned combat calculations.
