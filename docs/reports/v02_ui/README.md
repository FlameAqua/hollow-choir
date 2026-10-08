# V0.2 UI correction evidence — 8 October 2026

Changes follow [the canonical interaction/card contract](../../design/V02_UI_INTERACTION.md) and
[implemented handoff](../../briefs/V02_UI_FIXES.md). This is automated and rendered evidence;
it does not claim a fresh-player, physical-controller, color-vision or comfort playtest.
The latest screenshot-driven pass follows [the inspection/targeting addendum](../../design/V02_UI_FOLLOWUP.md).

Latest follow-up: [opening announcements and actual timing previews](OPENING_AND_TIMING_PREVIEW.md).
The completed suite now passes 184 tests / 1,665 assertions, with 180 scripts checked. Announcements
fit settled content and suppress hover; the real meter/ring stays visible during preparation.
The [earlier scrolling/familiar polish](PRE_PUSH_POLISH.md) records expanded source scrolling and
the larger Pup; its separate Get ready presentation has been superseded.

The subsequent action/familiar/condition pass is recorded separately in
[support presentation evidence](SUPPORT_PRESENTATION.md): 175 tests pass and 180 scripts compile,
with updated support cards, Cinder Pup, shared resource textures and condition docking captures.
The counts and screenshots below describe the earlier pass.

## Latest follow-up

- Removed repeated stage Brace/Evade/Parry rows, YOUR TURN/TARGET tags and the familiar readiness circle.
  Reactions remain in move inspection/active input; familiar readiness remains explicit on hover.
- Replaced numeric `!1` with a named top-right threat badge. Long move names use a separate row.
- Added structured unit name/type/knowledge, separate health/break fields and icon/name affinity
  groups. “Normal damage” explicitly means no affinity bonus/reduction. The declared move reuses
  the same move card. Advanced action outcomes also have separate damage/break/Focus sections.
- Inspection uses an 82% content transform with unchanged native font raster sizes and continued
  accessibility scaling. Simple fields have no false Alt hint; scrolling instructions appear for
  overflow and shorten at enlarged text. “Wheel” was shorthand for mouse-wheel scrolling; removed.
- Fixed action/supply button wheel ownership and Hold-details release/focus-loss recovery while
  preserving Toggle/Always preferences.
- Intercept and other single-recipient targeted actions require explicit recipient review/click
  or Confirm. Back spends nothing. Guidance appears above contextual inspection in the turn strip.
- Redrew the shared heart as a stepped two-lobed silhouette. Replaced generic circular condition
  motes with muted ground reflections/ripples for Flooded Ground and low haze/flecks for Spore Fog.
  Reduced motion retains static terrain decoration. No new combat or condition rules.

## Reported failures and fixes

| Report | Resolution |
|---|---|
| Practice text/footer off-screen | Bounded scroll content; footer outside the scroll; shorter header and responsive fields. Five explicit window sizes in Settings; existing canvas scales automatically. |
| Setup and Pause overlap, requiring two dismissals | Safe-point host cover disables the battle subtree and hides its pause overlay. Closing Setup resumes directly and clears stale inspection. Results are restored if returning from Setup after a finished fight. |
| Shift/Ctrl flicker and Alt stacking windows | Only deliberate navigation switches inspection from pointer to focus. Alt expands one shared card. No separate analysis overlay or automatic target-pinned popup. |
| Space and other native accept inputs commit unexpectedly | Default Confirm is Enter/gamepad A. GUI mirrors replace native defaults; Space/Z remain command inputs. Saved explicit custom bindings are respected. |
| Description scrollbar does not work | Real input-driven wheel checks over source and card; scrollbar stays reachable; keyboard Page Up/Down. Expanded analysis survives blank pointer travel. |
| All information combined and similarly colored | Individual health/break/status/target/reaction hit regions; structured shared action/enemy-move cards; semantic title/resource/damage/healing/break/target colors. |
| Enemy symbols disappear against scenery / crowd together | Dark bordered tiles, 6px gaps and distinct rows; group targets carry an explicit count; excess statuses use an explained overflow tile. |
| Unexplained red line above enemy | Removed the intent strip's redundant selection line. Existing creature brackets still identify the actual target. |
| Turn-order click captures inspection | Removed focus-based override of point-specific timeline tooltips; pointer hover remains authoritative. |
| Enemy inspection covers Supplies | All contextual cards are bounded above the dock and placed opposite the source. No target-selection popup is automatically pinned. |
| Enlarged action and reaction text | Standard action names use two columns; enlarged grids use icons/costs with full names on inspection; supply slots stack. 150% reaction dock exposes Parry risks and input prompts are shortened. |

## Automated validation

Completed-tree results: **179 scripts checked, 0 failed; 171 tests passed, 0 failed; 1,337 assertions**
(29.43 seconds). The focused V0.2 interaction suite contains twelve tests. Earlier intermediate
runs are not represented as final evidence. Tests use isolated QA user data, not Adrian's settings
or progress. Existing invalid-save fixtures intentionally emit four errors and the illegal-action
fixture emits one warning; those are expected and counted by the runner.

`tests/ui/test_v02_ui.gd` checks real viewport pointer/key/wheel input, actual overflow, 15
resolution/text-size layout combinations, input mirror replacement, resolution round-trip/fallback,
individual icon explanations and displayed-intent cards. Existing boundary tests cover safe Setup,
target clickability, hidden-state ordering, corpses and knowledge gates.
Practice opens with the encounter selector visible after layout settles at every tested size.
Additional regressions cover physical Space not activating a focused action, deliberate Enter target
review, mouse-to-keyboard target switching, reopening inspection after Setup and returning to the
real result screen after Setup. Fields within cards explain themselves in the same card's footer.
Follow-up regressions cover sole-ally Intercept review/cancel/one submission, button-hover list
scrolling, honest hints, native raster sizes under the content transform, named threat bounds,
structured ledger/knowledge isolation and Hold/Toggle/Always detail modes. The solo keyboard action
test requires separate action and recipient confirmation, matching the latest user requirement.

## Rendered review

Actual Godot 4.7.2 Compatibility rendering at 1280×720, with separate enlarged-text views. These
are captures of the real scenes. Timing captures hold the clock for inspection and do not measure
reaction skill or certify physical input latency.

Current follow-up captures:

- [Structured unit inspection, standard](unit_followup_1280.png)
- [Structured unit inspection, 200%](unit_followup_200.png)
- [Named threat/move card, standard](intent_followup_1280.png)
- [Named threat/move card, 200%](intent_followup_200.png)
- [Explicit target guidance / Flooded Ground](target_followup_1280.png)
- [Action analysis, standard](action_followup_1280.png)
- [Spore Fog, reduced motion](spore_followup_1280.png)

Initial correction captures below predate the screenshot follow-up and record that earlier pass:

- [Practice, standard](practice_1280.png)
- [Practice, 200%](practice_200.png)
- [Practice at 1920×1080](practice_1920.png)
- [Display settings, 200%](settings_200.png)
- [Action card, standard](action_1280.png)
- [Enemy move card, standard](intent_1280.png)
- [Expanded enemy inspection, 200%](enemy_200.png)
- [Planning, 200%](planning_200.png)
- [Reaction cards, 150%](reaction_150.png)

The capture-only harness exits an active reaction coroutine after its snapshot; that capture may
log ObjectDB/resource-in-use shutdown diagnostics. It is not a passing gameplay/leak check. Full
automated battles run to completion separately. No production clock/input changes were made for captures.

## Remaining human acceptance

Play the mouse → action → target → timing → reaction → Setup → resume flow at the desired display
size. Check physical controller navigation and display modes on the target monitor, color-vision
legibility and whether the compact cards communicate quickly to a fresh player. Advanced analysis
at 200% intentionally scrolls. No V0.2 release/push or human approval is claimed by this report.
