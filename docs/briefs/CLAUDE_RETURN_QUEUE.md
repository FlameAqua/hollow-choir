# Claude return queue — 8 October 2026

**Current:** [icon-first UI integration](ICON_FIRST_UI_INTEGRATION.md) is implemented in the working tree; ChatGPT owns UI integration.
The new UI contract supersedes historical layout/pending-art statements below. **Ready:** M1.1 engineering review. **Prepared:** policy evidence and human test protocol.
**Held:** expedition resource candidate and all world/content expansion.

**V0.2 UI fixes:** [Implemented handoff](V02_UI_FIXES.md) and [current interaction contract](../design/V02_UI_INTERACTION.md)
supersede older pinned target/Alt-overlay/native-confirm/layout statements. Claude's completed
[engineering review](../reports/M1_1_ENGINEERING_REVIEW_2026_10_08.md) remains the prior baseline;
this UI pass addresses the user's subsequent playtest blockers. Read its
[fresh evidence](../reports/v02_ui/README.md) and preserve the shared filtered readouts/ledger boundary.
The latest [inspection/targeting follow-up](../design/V02_UI_FOLLOWUP.md) removes stage reaction rows,
numeric threat and sole-target auto-submit; adds structured unit fields and compact inspection;
fixes wheel ownership/Alt release and refreshes shared HP/terrain visuals. Keep these UI decisions.

**Latest handoff:** [Stage presentation refresh](STAGE_PRESENTATION_REFRESH.md) is implemented:
Departure Mono, refreshed title, compact break tracks, shared state markers, nine defeated poses and
six flat day/night backgrounds. It supersedes older pending-art/font/idle-only statements below.
Read [the canonical stage contract](../design/STAGE_PRESENTATION_REFRESH.md) and its
[recorded evidence](../reports/stage_refresh/README.md) before changing presentation. The recorded
baseline is 173 script checks and 147 passing tests/1010 assertions; rerun the current tree rather
than treating that earlier result as proof of subsequent changes.

**Audio received:** [Six music candidates](AUDIO_DELIVERY_INTAKE.md), two variants each for title,
Briarfen battle and Mirebell boss, are cataloged with unchanged originals and comparison Oggs.
Catalog v2 distinguishes candidates from the still-null selected cue fields. `source/review/` is
excluded from Godot and is not a runtime asset source. Musical fit, default choices, loop review and
playback integration remain pending. Continue the existing M1.1 engineering review; these updates
authorize no corpse mechanics, automatic background/music selection or new audio architecture.

Canonical GDD and agent prompts now live under `docs/`; preserve that relocation and current edits.

**8 October art addendum:** the user authorized staged artwork for the remaining six existing
enemies and shared combat UI textures. See [art handoff](BRIARFEN_V02_ART_INTEGRATION.md),
[style guide](../../assets/art/STYLE_GUIDE.md) and [QA](../../docs/art/briarfen_v02/QA.md).
The current working tree now contains M1.1 renderer/readout work; the historical commit description
below is not a statement that today's checkout still lacks it. Six new enemy SpriteFrames are bound
through data; UI texture lookup and the revised layout are integrated. This limited art extension supersedes the
full-cast staging hold only, and does not pass the human gate or authorize new gameplay content.

## IMPLEMENTATION BRIEF

Start with [M1.1 combat clarity](M1_1_IMPLEMENTATION.md), whose combat/input requirements remain authoritative alongside the current UI addendum. The Director preparation here adds evidence and test material; it does not
represent runtime UI work. Commit `455ec50` staged docs/art/HTML only. Running Godot at that commit
still shows the old UI; opening another scene or clearing imports cannot enable an unimplemented UI.

1. Deliver the existing knowledge/preview, input and decision-dock work in reviewable increments.
2. Wire the staged optional SpriteFrames and backdrop into the existing presentation surfaces; retain
   fallback. Generated single frames still need pixel cleanup and visual review. Do not report HTML
   reference screenshots as Godot screenshots or start a full animation/content expansion.
3. Run the existing functional checks and capture actual Godot planning/reaction/setup states.
4. Use the [session pack](../playtests/M1_1_SESSION_PACK.md) for human validation. Its blank sheets
   are intentional; automated results have not filled or passed them.

Read the [policy audit](../reports/M1_DIRECTOR_POLICY_AUDIT.md) before proposing balance changes.
SMART/BASIC_ONLY/RANDOM comparisons are action-policy evidence with shared automated defenses,
not human difficulty measurements. Keep the current numbers until readable human play identifies
a concrete issue. Do not add enemy abilities merely because a heuristic never used an existing one.

The [expedition boundary candidate](../design/EXPEDITION_RESOURCE_CANDIDATE.md) is for later feasibility
review only. Report interface conflicts if useful; do not implement it while M1.1 remains ungated.

## DATA CONTRACT

M1.1 uses the existing engine requests, typed previews, knowledge policy, bindings and optional art
Resources in its full brief. This preparation adds **no production schema or data changes**.
The audit's manifest identifies commit/version/settings/seeds because engine JSON labels omit some
of them. CSV observations are manual research artifacts, not a proposed telemetry API.

## STATE FLOW

Current Sandbox → integrated Practice/Lab → existing battle requests + common decision dock →
functional checks → actual runtime visual review → fresh-player gate → Director go/revise decision.
The HTML study is a reference branch of this work, not a launchable combat mode.
No expedition state transition is approved by the existence of a draft document.

## ACCEPTANCE TESTS

Use the full M1.1 brief and specification, plus R1–R5 and the separate ten-fight pacing pass in the
session pack. Preserve manual inputs and chosen assists. Show exact commit, commands, test results,
runtime screenshots and remaining failures in the implementation report. Missing human evidence
means incomplete human acceptance even when the regression suite passes.

## KNOWN EDGE CASES

Saved Lab preferences can enable autopilot/simulated execution/progress recording; reset test fields
explicitly. Starter weapon presets change other build parts; use the pack's weapon-only override
for controlled comparison. CLI base seed is not the same number as the first battle seed. Inspect
changes knowledge; do not treat a later known preview as an initial Unknown-state test. A simulator
timeout is an outcome, whereas a shell timeout is an incomplete batch and contributes no report.

## NON-GOALS

No world slice, new encounter, potion economy, persistent supplies, save rewrite, new AI policy,
telemetry infrastructure, balance patch, full-cast art expansion or claim that M1.1 already runs.
