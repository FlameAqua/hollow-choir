# V0.2 final scrolling, familiar and pacing checks — 8 October 2026

Historical pass. The later [opening/timing preview follow-up](OPENING_AND_TIMING_PREVIEW.md)
supersedes the Get ready panel with the actual timing UI during preparation and fixes banner sizing.

Authority: [design contract](../../design/V02_PRE_PUSH_POLISH.md),
[implemented Claude handoff](../../briefs/V02_PRE_PUSH_POLISH.md).
This supplements [the previous support presentation pass](SUPPORT_PRESENTATION.md).

## Changes

- Expanded action/supply details now scroll with the wheel over their source button as well as
  the card. The action list stays still. Collapsing details restores normal list scrolling.
  Hold, Toggle and Always modes share the expanded rule; enemy-source scrolling is preserved.
- Cinder Pup uses the existing familiar fitting with display_scale 1.2: rounded slot 62×70 instead
  of 52×58. Its floor anchor and proportions stay intact; the existing source artwork is unchanged.
- Before every manual command or reaction, the existing transition panel shows “Get ready” plus
  the filtered move/recipient for 400 ms real time. The original timing widget and clock begin
  afterward. Combat Speed cannot shorten this beat; focus loss pauses it and restart cancels it.
  Held input must be released before a fresh press. Simulated execution and untimed actions skip it.

Original command/reaction specifications, grading windows, windups, feedback holds and combat
outcomes remain unchanged. Pause-before-reaction assist still waits for Confirm after preparation;
Pause/Setup retain their existing safe-point ownership. No new balance setting or save field.

## Validation

- Godot 4.7.2: **180 scripts checked, 0 failed**.
- Full suite: **180 tests passed, 0 failed; 1,475 assertions** (35.03 s).
- Focused V0.2 suite: **21 passed, 0 failed; 343 assertions** (14.55 s).
- Added actual-scene regressions cover expanded action wheel down/up and collapse, Pup scale/floor,
  manual command and reaction preparation, real-time duration under accelerated presentation,
  no grading widget during preparation, held-input suppression, focus freeze, unchanged reaction
  impact/exact-impact success, and restart cancellation.
- Tests/captures use isolated QA user data under .godot/art_qa_home.

Four invalid-save fixture errors and one illegal-Focus warning are expected suite checks. The full
suite completed without unexpected script errors. Scoped whitespace and document-link checks passed.

## Rendered evidence

Actual OpenGL Compatibility captures at 1280×720. The QA harness accelerates the intro and freezes
only the preparation tween for a stable snapshot; this does not alter production timing or data.
The 200% view also uses reduced motion. Both preparation cues fit in the existing transition dock,
and the larger Pup retains its companion-side footing.

- [Larger Cinder Pup at normal text size](cinder_polish_1280.png)
- [Attack preparation at normal text size](prepare_attack_1280.png)
- [Reaction preparation at 200%, reduced motion](prepare_reaction_200.png)

These checks verify behavior and layout. The preferred preparation duration still needs Adrian's
hands-on comfort check; tune the single PREPARATION_MS constant if needed. No commit or push was made.
