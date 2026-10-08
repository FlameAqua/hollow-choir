# V0.2 opening announcement and timing preview — 8 October 2026

Current authority: [revised design](../../design/V02_PRE_PUSH_POLISH.md),
[Claude implementation handoff](../../briefs/V02_PRE_PUSH_POLISH.md), D-035 in
[the decision log](../../DECISION_LOG.md). This supersedes the separate Get ready panel in
[the previous polish pass](PRE_PUSH_POLISH.md).

## Result

The first announcement retained a temporary tall minimum height while its autowrapped label was
laid out at a narrow width. Its later content was small, but the panel never shrank. Banner now
settles width while transparent, fits the final content height, positions within the viewport,
then fades in. Title-only reuse discards the old body height; empty title/body opens no card.
The reproduced 1280×720 title panel now measures 560×32.8 at normal text and 560×55.76 at 200%.

The existing hover inspector clears immediately when an announcement opens and stays suppressed
through its fade or condition docking flight. Hover and Alt details return afterward. Opening
condition explanations, their header destination and reduced-motion behavior are preserved.

Manual preparation now displays the actual attack meter or reaction ring/meter/legality cards,
with filtered identity/recipient, zones and bound keys already visible. Its marker stays at zero
and input is inert for the existing 400 ms real-time beat. The same widget then starts timing in
place. No separate preparation panel, buffered press, extra confirmation or replacement layout.
The enlarged-text reaction layout continues to use its existing expanded dock and scroll content.

Focus loss pauses preparation; restarting frees the wait and visible preview with the battle.
At activation, held keys must be released. Pause-before-reaction assist still waits for a fresh
Confirm after the beat, with the stationary reaction UI visible; only then does windup start.
Original timing specifications, grading, reaction legality/impact and battle rules are unchanged.

## Validation

- Godot 4.7.2: **180 scripts checked, 0 failed**.
- Full suite: **184 tests passed, 0 failed; 1,665 assertions** (38.52 s).
- Final focused V0.2 pass: **25 passed, 0 failed; 533 assertions** (17.26 s).
- Added regressions cover first/repeated title and body sizing at 100/150/200% across 1280×720 and
  1920×1080; empty announcements; actual opening/condition hover suppression and restoration;
  all four command types ignoring preview input then grading Perfect; assist Confirm/held-key
  boundaries; same-widget transition; zero preview time; focus freeze and restart cancellation.
- Existing wheel ownership, familiar sizing, explicit recipient review, ledger/knowledge, condition
  docking, input, save and completed-battle regressions remain green.
- Tests and captures use isolated QA user data under .godot/art_qa_home.

The full suite emits four intentional invalid-save errors and one illegal-Focus warning. No
unexpected errors or warnings occurred. Local document-link and scoped whitespace checks passed.

## Rendered evidence

Real battle scenes, OpenGL Compatibility rendering at 1280×720. The hidden QA window holds only
the announcement/preparation tween for a stable screenshot and supplies synthetic pointer/focus.
Production clocks/specifications/art are unchanged by capture tooling. Hover is deliberately over
an ally in the opening captures; no detail card covers the announcement.

- [Compact first announcement, normal text](opening_fit_1280.png)
- [Compact first announcement, 200% text](opening_fit_200.png)
- [Opening Flooded Ground card, 200%, reduced motion](opening_condition_200.png)
- [Actual attack meter during preparation](attack_preview_1280.png)
- [Actual reaction ring and legality cards during preparation](reaction_preview_1280.png)
- [Reaction preparation in the existing 200% dock layout](reaction_preview_200.png)

Human pacing/comprehension review remains open. No commit or push was made.
