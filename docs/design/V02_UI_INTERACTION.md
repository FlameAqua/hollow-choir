# V0.2 UI interaction and information cards

Owner: Director/UI integrator (ChatGPT). User-authorized fixes, 8 October 2026. Companion to the
canonical GDD. This supersedes earlier requirements for pinned target popups, a separate Alt
analysis overlay, Space/Z confirming menus and the fixed two-column Practice landing page.
Combat rules, knowledge gates, action-command and reaction clocks remain authoritative.
The subsequent [inspection/targeting follow-up](V02_UI_FOLLOWUP.md) is authoritative for reaction
row removal, named threat, structured unit fields, compact rendering and sole-recipient review.

## DESIGN INTENT

Make inspecting a fact, choosing an action and executing its timing three distinct, predictable
interactions. Keep controls reachable and let a player scan repeated card positions before reading
prose. Reuse existing icons, typed readouts, layout, settings and presentation ledger.

| Change / player-facing purpose | Decision supported | Interacting systems | Cost | Failure / exploit | Cheaper existing route |
|---|---|---|---|---|---|
| Bounded Practice/Lab content and a fixed footer; explicit window sizes | Choose a fight/display comfortably | Sandbox, Settings, canvas stretch, focus scrolling | Low; layout and one additive preference | Long labels or enlarged text force footer off-screen; oversized window exceeds monitor | Existing ScrollContainer and design canvas, no new layout framework |
| A single immediate contextual inspector | Read the hovered fact without blocking an action | Input events, hover/focus, typed readouts, ledger | Medium; shared routing and scrolling | Modifier swaps subject; sticky focus/pinned content; overlays obscure Supplies; stale future-state data | Extend HoverInspector; retain target facts in the existing dock |
| Shared action/enemy-move card and individual icon explanations | Compare cost, payload, target and outcome quickly | PreviewPanel, ActionReadout, IntentReadout, icon map | Medium; one renderer and hit regions | Unknown numbers leak; conditional status appears guaranteed; area damage mistaken for a total | Reuse filtered readouts and the same card, no per-move widgets |
| Dark spaced enemy icon tiles, removal of redundant selection line | Recognize intent/reaction availability on every backdrop | IntentSlot, UnitView, ledger | Low | Overlap, illegible art, unexplained red lines, color-only meaning | Existing icons and target brackets, no new textures |
| Deliberate confirm and exclusive Setup ownership | Commit only the intended action; return to combat directly | InputBindings, GUI actions, sandbox, safe pause points | Low/medium | Space both confirms and times an attack; host leaves a pause box/input running underneath | Replace built-in input mirrors; reuse safe-point pause and suspend the battle subtree |

## PLAYER EXPERIENCE

Practice and Lab have scrollable content with navigation outside the scroll. Display settings offer
1280×720, 1366×768, 1600×900, 1920×1080 and 2560×1440 window sizes. The existing 1280×720 design
canvas scales to the window; aspect changes reflow controls. Accessibility text size remains independent.
Fullscreen/borderless use the desktop resolution; windowed choices fit the monitor's work area.

Hovering gives immediate feedback. Small gaps retain the card for 140 ms; replacing an existing
subject settles for 65 ms. Each health, break, status, intent, target or reaction icon explains its
own fact. Alt expands this same card. Selecting a target does not create a persistent popup.

## RULES

- Mouse movement/clicks select pointer inspection. Deliberate direction navigation/confirm/back selects focus
  inspection. Shift, Ctrl, Alt and unrelated keys never switch inspection to keyboard focus.
  When keyboard target review releases GUI focus, the current target supplies inspection; pointer
  hover remains free to replace it. Alt expands that target's facts in the same card.
- Turn-order focus does not override subsequent pointer hover.
- Enter / gamepad A confirm by default; Space/Z remain command inputs. Saved explicit rebindings
  still apply. Built-in GUI accept/navigation actions exactly mirror the configured game actions,
  replacing their native defaults rather than appending to them.
- Pointer action previews do not steal keyboard focus. A hovered action's card and the dock use
  the picker's same default/reviewed target policy.
- Setup requests wait for an existing safe point during timing/playback. Once opened, Setup owns
  the screen; the battle subtree is suspended and its pause overlay is hidden. Back/Escape closes
  Setup and resumes directly. The normal Pause menu remains available separately.
- Popups stay within the stage above the dock, on the opposite side from the inspected control.
  They never cover Actions or Supplies. Entering a popup preserves it for scrolling.
  Explicitly expanded analysis also survives blank pointer travel to its scrollbar; a new hovered
  fact replaces it in the same card. Closing Setup clears stale inspection state before resuming.
  Fields inside an action/move card explain themselves in that card's footer, without a nested popup.
- Wheel scrolling works over the source or inside the card. Its scrollbar remains draggable.
  Page Up/Down scroll focused inspection. Re-rendering unchanged content must not reset its scroll.
- Timing disables inspection. Mid-playback unit and intent information comes from presented state;
  no whole-engine intent rebuild is permitted.

## UI REQUIREMENTS

Shared card positions: title at top-left; Focus cost/charges at top-right (enemy moves use threat);
status payload icons below the resource field; targets at left; damage/healing/break at right;
scope and assumed grade below the outcomes. Enemy moves include legal/crossed-out reactions and
channel countdowns. Conditional/doused statuses retain `?` and an honest explanation. Unknown
damage stays unknown; area results remain per target and are never summed.

Color vocabulary: bone-gold = title/selection/Focus, red = enemies/incoming or outgoing damage,
green = healing/ally health, lavender = break, cyan = targets/neutral information. Keep names,
symbols, counts and availability slashes so color is never the only signal.

At 150/200%, action grids use icons/costs with full names on inspection and supply slots stack
vertically. Standard text uses two action columns to avoid truncated names. The enlarged reaction
dock may cover scenery, with its impact meter fixed outside the card scroll. Short input prompts
must remain readable. Existing target brackets replace the removed intent-strip selection line.

## DATA REQUIREMENTS

- Additive global preference: `display/window_resolution: Vector2i`, restricted to the five
  supported sizes, default 1280×720. Absent/invalid values fall back safely. No progress-save migration.
- `IntentReadout.target_names: Dictionary[int, String]` captures public identities with the
  displayed intent; cards never derive a fresh intent from final resolved engine state.
- ActionMenu's preview provider delegates target selection to ActionPicker. Inspector providers
  receive the pointer position in the source control's local coordinates, derived from the input
  event rather than an unrelated OS cursor position.
- Canvas icon hit regions and popup state are transient presentation data. No new content Resources,
  art assets, inventory, combat rules or audio behavior are required.

## BALANCE PARAMETERS

No balance changes. Existing costs, grades, timing windows, damage ranges, status qualifiers,
reaction availability, break/kill claims and knowledge visibility remain unchanged. Hover settling
is UI-only and must never delay or freeze a combat clock.

## EDGE CASES

Empty/unaffordable supply slots remain inspectable and cannot submit. Explicit custom bindings are
honored. An invalid resolution falls back; a large resolution on a smaller monitor is fitted without
overwriting the preference. A queued Setup request never covers an active timing window. A defeated
unit's brief reads Defeated from the ledger. Closing/restarting frees any old inspection source.
Long analysis, multiple targets and enlarged type use bounded scrolling/explicit overflow rather
than allowing controls off-screen. The old DetailsPanel is retained hidden for compatibility.

## ACCESSIBILITY REQUIREMENTS

Preserve 100/150/200% text, minimum control sizes, focus scrolling, remapping, gamepad confirmation,
art-off behavior, reduced motion/flashing and sound-off parity. Inspection is not a modifier-only
feature. Exact values remain readable through per-icon explanations; advanced details use one card.
Physical controller, color-vision and fresh-player comfort checks remain human acceptance tasks.

## ACCEPTANCE TESTS

1. At all five sizes and 100/150/200% text, Practice's footer stays within the screen; content scrolls
   above it; Lab never inherits an empty Practice area. Settings keeps Back visible.
2. During reaction input, Setup waits; in planning it opens immediately. No pause box appears over
   Setup, no hidden battle input runs, and closing Setup resumes without another dismissal.
3. Hover an enemy and press Shift/Ctrl/Alt: the subject remains that enemy. Alt shows one inspector.
4. Click Turn Order, then hover an enemy/action/supply: each new subject replaces the prior one.
5. Overflow scrolls by wheel from its source and within the popup; entering it does not hide it.
6. Health, break and each reaction tile return different explanations. The move tile uses the
   displayed IntentReadout in the shared card. Popups never intersect Actions or Supplies.
7. Native Space no longer accepts a menu action; Space remains a command input. Rebinding Confirm
   removes the prior built-in Enter binding. Custom bindings remain authoritative.
8. Unknown/named intents, conditional/doused status, per-target damage, corpses and ledger event
   ordering retain existing regression coverage. Full script checks and tests must pass.
9. Inspect actual rendered standard/enlarged menus, cards and reaction screens, then playtest the
   whole mouse → target → command → reaction → Setup → resume flow before V0.2 release.
