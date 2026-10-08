# V0.2 scrolling, familiar scale and preparation beat

Director/UI integration, 8 October 2026. Authorized by Adrian's final pre-push playtest. Supplements
[support presentation](V02_SUPPORT_PRESENTATION.md) and supersedes unconditional list-wheel priority
when an action's detailed inspector is expanded.
Adrian's subsequent opening-banner screenshot and preparation feedback supersede the separate
Get ready panel: display the actual timing UI throughout preparation.

## DESIGN INTENT

Reduce friction and give players a brief moment to orient before each manual timing sequence.

| Player-facing purpose | Decision supported | Systems | Cost | Failure cases | Cheaper reuse adopted |
|---|---|---|---|---|---|
| Scroll expanded action details without chasing the popup | Read the action before committing | HoverInspector, ActionMenu/Supplies, ScrollContainers, Alt preferences | Low | Both panes scroll; collapsed action list loses navigation | Change the existing shared wheel arbitration; no new popup |
| Make Cinder Pup easier to see | Recognize/inspect the equipped familiar | FamiliarDefinition, FamiliarCard, stage layout | Low | Paws float, sprite stretches or clips off-stage | Data-driven display scale over the existing image and floor anchor; no replacement art |
| Brief preparation with the actual attack meter/reaction ring | Read the timing zones, input and reaction legality before responding | BattleScene, bound tween, existing widgets/latches/clocks | Low/medium | Early input grades; preview clock advances; UI swaps away at start; focus/restart strands a wait | Static preparation state in the existing widgets; one shared wait; no duplicate interface or grading logic |
| Compact opening/round/condition announcements | Read the current announcement before inspecting a unit | Banner, autowrapped labels, HoverInspector, condition ribbon | Low | Temporary narrow wrapping leaves a giant blank panel; hover covers text; stale body height persists | Fit the existing panel after layout settles; use the existing inspector suppression callback |

## PLAYER EXPERIENCE

While Alt details are expanded, the wheel scrolls that card from either the card itself or the
hovered action. Releasing Alt restores normal Actions/Supplies list scrolling. Toggle/Always modes
use the same expanded-card behavior. Enemy-source scrolling remains available as before.

Cinder Pup occupies a roughly 20% larger slot beside the companion, with the same paw baseline.
Before each manual attack or defensive timing sequence, its actual meter/ring and instructions are
already visible, stationary at the starting position. The player can scan the zones, move/recipient
and reaction legality for 400 ms before the same UI starts timing. A short Prepare note belongs to
that UI; no separate Get ready interface replaces it.

Encounter, round and condition announcements fit their content before fading in. Hover/Alt details
clear while an announcement is showing and become available again afterward. Conditions retain
their existing header docking and reduced-motion behavior.

## RULES

- Expanded inspector owns wheel input over its current source, including buttons inside lists.
  Collapsed inspection leaves menu wheel ownership unchanged. One wheel event moves only one pane.
- Familiar display_scale defaults to 1.0. Cinder Pup uses 1.2: rounded slot 62×70 instead of 52×58.
  Aspect fit and bottom anchor remain unchanged. Clamp its left edge to the battlefield.
- Before manual ACTION_COMMAND or REACTION, show the actual widget in preparation mode for 400 ms.
  Its clock stays at zero and its inputs are inactive. After the beat, start_timing() starts the
  original clock in the same widget; no replacement, re-layout or extra input confirmation.
- The beat uses a scene-bound tween with ignore_time_scale; Combat Speed and Engine.time_scale do
  not shorten it. Focus loss pauses the remaining beat. Restart/free cancels it with the scene.
- Presses during preparation are not buffered. Keys still held at start_timing() use the existing fresh
  press latch and require release. Reaction impact, legality, grades and command windows are unchanged.
- The existing Pause-before-reaction assist still waits for Confirm after preparation; Confirm
  starts the existing sequence, without another automatic preparation delay.
- Pause/Setup requests retain existing safe-point ownership and queue until the current action ends.
  No timing clock runs under Setup. Automated/simulated execution and untimed actions add no beat.
- Announcement panels remain transparent while autowrap widths settle, then shrink to the final
  content height before fading in. Title-only cards discard previous body height. Empty title/body
  opens no card. Inspector suppression lasts through the full fade or condition docking flight.

## UI REQUIREMENTS

Reuse the actual command meter and reaction ring/meter/legality cards, with the same filtered
move/recipient and bound instructions. The real timing marker stays at zero during preparation;
no NOW invitation or result can appear before activation. Retain stage target highlights. Assist
pause continues to show the stationary reaction UI until a fresh Confirm starts its sequence.
Opening announcements use the shared frame and 82% native-font transform, without empty filler.

## DATA REQUIREMENTS

FamiliarDefinition.display_scale is optional presentation data, positive, default 1.0; not saved
progress or targeting geometry. BattleScene.PREPARATION_MS is the single 400 ms presentation constant.
No CommandSpec/ReactionSpec, engine phase, balance, save schema or new setting is required.
CommandWidget.begin and ReactionWidget.begin gain an optional preparing=false argument; true
initializes the real UI without advancing or grading. start_timing() activates it once and
is_preparing() exposes presentation state for capture/input checks. Banner sizing and inspection
suppression require no authored data or notification system.

## BALANCE PARAMETERS

400 ms real-time preparation, once per manual timing request. Cinder Pup display_scale 1.2. Existing
result-feedback holds, lead-ins, reaction windups/windows, Focus costs and all combat outcomes stay
unchanged. Tune the single preparation constant if human playtesting prefers a shorter/longer beat.

## EDGE CASES

Held inputs cannot cross the boundary as fresh presses. Focus loss preserves the remaining pause;
it does not spend a timing window. Restart during the pause creates no orphan grading widget or
resumed coroutine on a freed battle. Enlarged analysis still scrolls. Cancelled target review never
enters preparation. A familiar's decorative size never makes it a combat target.

## ACCESSIBILITY REQUIREMENTS

Static timing preview works with reduced motion/flashing and without audio. Text scale and rebound controls
remain supported. Hold/Toggle/Always use the same expanded scroll rule. Keep the existing indefinite
Pause-before-reaction assist and automatic Brace behavior; the new beat is not a replacement for them.

## ACCEPTANCE TESTS

- Wheel down/up over an Alt-expanded action scrolls details, leaves its list still, and list
  scrolling returns on collapse. Existing enemy/card wheel tests remain green.
- Pup slot is 62×70, retains the old floor and remains inside the stage; both familiar portraits
  retain proportions and production art references.
- Actual manual command/reaction flow shows the same timing widget during preparation and live
  input, with stationary zero-time markers and inert preview inputs. Fast presentation cannot
  shorten the beat. All four command types retain their original grading.
- Focus loss freezes preparation; a key held through it is latched; a fresh exact-impact reaction
  still succeeds. Freeing/restarting during preparation cancels its bound wait cleanly.
- A held Confirm cannot skip the assist pause; one fresh Confirm starts windup exactly once.
- First-use and repeated banners fit their settled contents at 100/150/200% and both tested window
  sizes. Opening/condition announcements suppress hover/Alt; normal hover returns afterward.
- Full gameplay, input/scroll, ledger/knowledge and accessibility regression suite passes.

Pillars: READ gets a clear preparation cue; REACT gets orientation time without changed grading;
ADAPT/EXPERIMENT retain deliberate action/target choices and easier repeat practice. AFFECT THE WORLD
retains the existing outcomes and terrain rules. No new combat mechanic is introduced.
