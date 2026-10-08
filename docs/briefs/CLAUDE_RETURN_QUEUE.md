# Claude return queue — 8 October 2026

**Ready:** M1.1 implementation brief. **Prepared:** policy evidence and human test protocol.
**Held:** expedition resource candidate and all world/content expansion.

## IMPLEMENTATION BRIEF

Start with [M1.1 combat clarity](M1_1_IMPLEMENTATION.md), whose requirements and implementation order
remain authoritative. The Director preparation here adds evidence and test material; it does not
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
