# Claude return queue — updated 10 October 2026

**Director checkpoint: implementation and targeted rendered review complete; human acceptance and backend regression closure remain open.** See [Director implementation report](../reports/V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md) and [failure inventory](../reports/v0_5_playtest_revision/FAILURE_INVENTORY.md).

**Godot execution window returned to Claude.** No Godot process remained active at this checkpoint. Codex has stopped at Adrian's usage-limit request.

Actual host code now integrates countdown, Journal, Loadout, station commands, learning receipts and OperationFeedback; duplicate success cues have been removed. The backend report's transfer-time progress table is stale. Protected backend/routing files and tests were not edited by Codex.

Latest presentation regressions: 11 tests / 187 assertions / zero failures in Compatibility/Dummy. Earlier Director world suites: 28 tests / 450 assertions, headless. Earlier all-script check: 350 scripts / zero failures. Latest recorded broad Compatibility run: 511 passed / 8 failed while backend tests were being edited; this is not a stable green acceptance result. Exact failures and source-change limitations are in the failure inventory.

Additional user feedback implemented: continuous control strips, circular sword/triangle Anvil, empty stock cells, Help in title row, text shadows, initial reaction centering, source-exit tooltip dismissal, tiny non-pinnable exploration hints, and Character/Map/Journal/Menu order. Six targeted follow-up captures reviewed; no further title captures. Human playthrough, listening/input feel and visual acceptance remain open. Application 0.5.0/save 1 and all dirty work preserved.
**Assignment authority — V0.5 human-review revision:** Adrian supplied a new feedback
pass. Start with [the new backend prompt](V0_5_PLAYTEST_BACKEND_PROMPT.md) and
[shared revision plan](../reports/V0_5_PLAYTEST_REVISION_PLAN.md), not the historical completed
assignments below. Six usable/two locked combat positions are confirmed; brewing now produces
finite paid stock. Claude owns rules/save/data and the shared host/battle routing files; Codex owns
presentation and sound assets. The plan defines exact parallel file/test ownership. No gameplay
fixes were implemented by the preceding planning task. [Codex fresh-chat prompt](V0_5_PLAYTEST_DIRECTOR_RESTART_PROMPT.md).
Application 0.5.0/save version 1; preserve all shared uncommitted work and current human gates.

**V0.5 UI Director return (Codex, 10 October 2026; uncommitted on `dev`):** Backend decisions
1–6 are accepted in [the Director note](../reports/V0_5_UI_DIRECTOR_ACCEPTANCE.md), with D-049–D-054
in the Decision Log (D-009 and D-046 amended). Save choices/replacement review and placeholder
copy are restyled; station/Character save confirmations use reserved footer space, leaving Close
visible. Combat visibly names the unplaced action, initially Kindle. Internal bench and click-to-place
remain; drag and drop is deferred. [Presentation and rendered evidence](../reports/V0_5_UI_PRESENTATION.md).
Return the integrated 0.5.0/save-1 tree to Adrian for [the full human test](../playtests/V0_5_INTEGRATED_TEST.md).
Human/controller/art/listening gates remain open. No further backend work is required for this scope.

**V0.5 UI backend returned (Claude, 10 October 2026; uncommitted on `dev`):** every item of
[the UI backend handoff](V0_5_UI_BACKEND_HANDOFF.md) is a real transaction now
([report](../reports/V0_5_UI_BACKEND_IMPLEMENTATION.md)):
- New Journey with difficulty, an approved preset and an explicit slot step. An occupied slot needs
  a deliberate Replace; the journey is adopted only after its write.
- Hardened, typed save summaries: UTC, newest first, damaged and newer saves handled without errors.
- One save-event owner (`WorldSession.commit`, after adoption); host pushes removed; cards hidden
  in battle.
- Field Equipment and potions (blocked only by an encounter).
- Typed Forge and Stillroom services that reject each other's work.
- A saved six-of-eight Combat arrangement, captured by entries and reconciled with gear in the same
  write.

Save version 1 (optional `campaign` and `combat` sections); application 0.5.0.

Verified on the final tree (report §5):
- headless and rendered suites 450 passed, 0 failed;
- battles and the simulation identical to `35c8763`;
- 28 of 28 mutations caught.

Final verification also fixed a tool startup compile error, a flaky station test (one line in
Codex's test) and new editor warnings in my code. Codex's own files keep a few warnings, listed in
§5. A separate task fixed the inherited `validate_world_art.gd` failure (it expected
`hollow_motion_v03`); it now reports 376 checks, 0 failures.

**Decisions to confirm** (report §0):
- difficulty is per journey (a D-009 amendment);
- Kindle starts outside the six positions for every starter;
- older saves default to Adventurer;
- freed positions refill in grid order;
- no-op equipment writes nothing.

Codex: restyle the slot step, the replace card and all placeholder copy; note save cards over the
station's Close button. Human, controller, art and listening gates remain open.

**Newest assignment — V0.5 UI iteration (Adrian, 10 October):** Read
[the concrete backend handoff](V0_5_UI_BACKEND_HANDOFF.md) and
[the frontend prototype](../design/V05_UI_PROTOTYPE.md). Complete safe New Journey setup/slot
creation, unified adopted-state autosave events, field Equipment changes, distinct Forge/Stillroom
service validation and persisted six-of-eight Combat arrangements. This explicitly supersedes
the no-blocker statement below for these new requests. Art and frontend are supplied; preserve
all uncommitted work and B/C mechanics. Do not silently enable a preview or bump versions.

**V0.5A/B/C integrated (Codex, 10 October 2026; uncommitted):** Forge/Stillroom screens now call
the typed station commands, preserve rejection/retry context, show costs/mastery/refund/trait
facts and prepare both distinct potion slots. The [bounded C specification](../design/V05C_EXPLORATION.md)
is accepted and placed in production, with scene-state art and saved rune feedback. Director
confirms all five backend policy decisions, including legacy potion reconciliation. No concrete
backend blocker was found. [Full human test](../playtests/V0_5_INTEGRATED_TEST.md) and
[integration evidence](../reports/V0_5BC_PRESENTATION.md) supersede the unplaced/no-screen notes below.
Application 0.5.0/save 1 unchanged. Human/controller/art/listening acceptance stays open.

**V0.5B + V0.5C returned (Claude, 10 October 2026; uncommitted on `dev`):** Adrian asked for both
stages in one session. **B** ([report](../reports/V0_5B_BACKEND_IMPLEMENTATION.md)): fitting kit and
both Stillroom recipes exactly as specified; Merciful Grip / Hollow Echo / none on Pilgrim's Edge,
free and reversible, by trait reference; exact kit refund (cap-safe); campaign potion preparation;
typed station commands, receipts and readouts; fittings captured by entries and proven in real
battles. Codex: station screens (API guide in §9). **C** ([report](../reports/V0_5C_BACKEND_IMPLEMENTATION.md)):
no Codex C brief existed, so this is the reusable backend (gathering node with an explicit
once-per-save policy, revealable secret, rune-sequence grammar, reward hooks, persistence/reset
policy, host routing) plus a tested content **proposal** in `tests/fixtures/exploration_kit.gd`.
Nothing is placed in `data/world` or scenes; Codex/Director decide placement, rewards and copy,
then promote the data. Application 0.5.0, save 1 (additive `crafting` section and world keys).
Human/controller/listening gates remain open.

**Current V0.5 continuation (Codex; uncommitted):** Adrian requested application **0.5.0**;
save version remains **1**. Character-menu slots and rows now use the existing cloth/leather and
dark/gold atlas frames. Read the [current continuation handoff](V0_5_CONTINUATION_FOR_CLAUDE.md),
then implement [V0.5B Forge/Stillroom](V0_5B_BACKEND_HANDOFF.md). Codex integrates its presentation
and bounds V0.5C; Claude then implements that exploration stage. The full integrated human test
follows both stages and presentation, with automated checks and focused review at each return.
This supersedes the older version hold and interim human-test sequence below. No new Claude run
or V0.5B/C implementation is claimed.

**V0.5A character-menu follow-up (Codex; uncommitted):** Adrian's portrait/menu, ten-cell equipment
grid, ingredient icon/quantity stacks, shared combat inspector, compact loot and Exposed effect
icon are integrated. Adrian chose specific progression rewards for capacity; first bell
restoration grants five permanent slots through its existing claim. See the
[current follow-up](../reports/V0_5A_CHARACTER_MENU.md) before extending V0.5B. Preserve the menu,
icon fields and reward-derived capacity. Earlier reading-button/list-inventory descriptions are historical.

**V0.5A Director integration returned (Codex, 9 October; uncommitted):** four-slot preparation,
charm equip/remove, inventory, reward cards, encounter previews and saved catch-up notice are now
connected. See [Director acceptance](../reports/V0_5A_DIRECTOR_ACCEPTANCE.md) and
[presentation report](../reports/V0_5A_PRESENTATION.md). The next bounded backend specification
is [V0.5B Forge/Stillroom](V0_5B_BACKEND_HANDOFF.md). Preserve the entire shared tree and application
0.3.0/save 1. Human/controller/listening gates remain open. The older entries below are historical;
their missing UI/review notes describe their return time, not the current tree.

**V0.5A returned (Claude, 9 October 2026; uncommitted on `dev` after `35c8763`):** see
[the implementation report](../reports/V0_5A_BACKEND_IMPLEMENTATION.md). The fifth engineering review
was already complete and committed in `35c8763`; its baseline reproduced (328/0). Implemented: the
three V0.5A rewards (two materials, Storm Salt Charm) granted once inside the victory/bell writes,
claims kept by Reset journey, world-entry catch-up and loadout repair for older saves, ownership-
and station-aware equipment commands, typed reward/inventory/preparation readouts and a demo
fixture. Application 0.3.0, save version 1 (additive `rewards` section). Connected for players:
rewards, catch-up, receipt lines on the victory card and rung bell, the bench's station context.
Not yet connected: any screen to equip the charm or see materials (Codex). Human gates stay open.

**Latest assignment prepared — fresh Claude / V0.5A:** Adrian requested a backend continuation plan after the previous Claude instance exhausted its usage. Read [the fresh-instance implementation brief](V0_5A_BACKEND_HANDOFF.md) and [GDD-based staged roadmap](../design/V05_BACKEND_ROADMAP.md) first. Recover the partial fifth engineering pass (new tests and corresponding fixes exist; its review report is still absent), then implement the bounded Salvage and Preparation backend: deterministic persistent rewards, claim receipts, ownership-aware equipment commands and typed readouts. Later Forge/alchemy, exploration frameworks and regional Pressure stages remain separate assignments. This is a prepared handoff, not an implementation or a claim that a new Claude instance has run. Keep the shared uncommitted dev tree, application 0.3.0/save 1, authored presentation and all-reset battle policy.

**9 October fifth playtest return:** Start with the [fifth continuation brief](V0_4_FIFTH_PLAYTEST_ENGINEERING.md) and [fifth presentation results](../reports/V0_4_FIFTH_PLAYTEST_POLISH.md), extending the fourth brief below. Fixed eight-action capacity, larger docks, separate ally/enemy turn banners, right-click inspection pinning with local field help, spacing/alignment/status fixes and localized idle-mask repair are complete. Full suite **304/0**, 4,117 assertions; rendered fifth pass **5/0**. Test integration boundaries and fix concrete engineering issues while preserving completed backend and art work.

**9 October fourth playtest return:** The [third engineering review](../reports/V0_4_THIRD_PLAYTEST_ENGINEERING_REVIEW.md) is acknowledged and its requested fixes are complete. Start with the [fourth continuation brief](V0_4_FOURTH_PLAYTEST_ENGINEERING.md) and [fourth presentation results](../reports/V0_4_FOURTH_PLAYTEST_POLISH.md). The requests below are historical; preserve completed action switching, reset, collision and backend fixes. Review the new integrated presentation and fix concrete engineering defects found.

**9 October third playtest return:** Start with
[third playtest engineering continuation](V0_4_THIRD_PLAYTEST_ENGINEERING.md) and
[third presentation results](../reports/V0_4_THIRD_PLAYTEST_POLISH.md). Adrian explicitly delegates
action switching during recipient selection and a player-facing exploration reset to Claude.
Implement these, finish the previous willow/root collision correction, and fix integration issues
found. Preserve the new controls/wordmark, quiet crow with occasional fidgets, public-recipient
hover markers and scrolling log. Final full suite: 272/0, 2,843 assertions; scripts 235/0;
material checks 264/0. Existing uncommitted `dev`, application 0.3.0 / save 1.

**9 October second playtest return:** Start with
[second playtest engineering continuation](V0_4_SECOND_PLAYTEST_ENGINEERING.md) and
[presentation results](../reports/V0_4_SECOND_PLAYTEST_POLISH.md). Implement the remaining willow
root collision correction and integration fixes, then test. The earlier generic willow expansion
was insufficient. Preserve the new bitmap UI, standing/crow idles, one inspection dock and revised
footsteps. Full behavior suite: 271/0; application 0.3.0 / save 1; shared work uncommitted.

**9 October first playtest return:** Adrian has tested the initial journey. Presentation polish is
in the working tree; Claude owns the backend bug/collision follow-up. Start with
[playtest engineering continuation](V0_4_PLAYTEST_ENGINEERING.md) and
[polish evidence](../reports/V0_4_PLAYTEST_POLISH.md), which supersede the older presentation
details below. All work remains uncommitted at application 0.3.0 / save 1.

**9 October integration return:** First Footsteps backend and Director presentation are implemented
in the uncommitted `dev` tree after `6d8401d`. Read [Director acceptance](../reports/V0_4_DIRECTOR_ACCEPTANCE.md)
and [post-integration brief](V0_4_POST_INTEGRATION.md) first. Earlier implementation requests below
are historical. Preserve the authored scenes and transactional boundaries; human gates remain open.

**Latest:** V0.3 is pushed as `6d8401d`. Adrian now authorizes
[V0.4 First Footsteps](V0_4_CLAUDE_HANDOFF_PROMPT.md), superseding the historical world hold below
for that bounded journey. Follow [fixed display presets](../design/DISPLAY_PRESETS.md); independent
text-size and arbitrary-window qualification are retired. Read the latest handoff before this older queue.

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
