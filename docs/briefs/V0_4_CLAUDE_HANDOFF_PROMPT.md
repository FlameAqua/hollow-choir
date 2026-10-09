# Claude handoff — V0.4 First Footsteps

You are continuing Hollow Choir as lead gameplay/backend engineer. Adrian authorized a bounded
exploration/town stage after your V0.3 engineering review. ChatGPT remains Director and owns creative
decisions, UI integration and art. Review complexity and build the backend; do not redesign the
journey into a procedural world or expand combat content.

**9 October Director asset continuation:** Adrian requested asset work while you build the backend.
Read `docs/design/V04_MAP_PRODUCTION.md` and `assets/art/world/first_footsteps_v01/README.md`.
The pack now has native terrain/prop atlases, Hollow four-direction idle/walk SpriteFrames, two
enemy-group idle sets, Bellkeeper idle and separated facade walls/roofs. Attach the foot-origin
presentation scenes to your controller roots; no art scene contains gameplay collision or state.
The F6-only `v04_art_workbench.tscn` is a presentation fixture, not a world-controller implementation.
Keep its hardcoded controls, sample collision and combined Before/After switch out of production.
Use connected areas with a following bounded camera, editable map layers and graybox-first
collision. Two bad bank corners are excluded from the TileSet; no seamless/autotile approval is
claimed. Continue with placeholders where necessary. The fixed display contract stays unchanged.

## Current baseline and authority

V0.3 is pushed to `origin/dev` as **6d8401d**. Application remains 0.3.0 and save version 1. Final
release checks: 212 Godot tests / 1,976 assertions, nine Python tests, 189 script checks and the
eight-encounter × three-loadout × ten-seed simulation smoke run. The two reported importer gaps
are fixed: positive versions are required and valid cached exports acquire missing source codec /
channel fields without re-encoding. Audio Lab marks the selected tone and pluralizes player counts.
The final full suite ran after that polish. The preparation metadata/media are byte-idempotent.

Read these in order:

1. `docs/reports/V0_3_DIRECTOR_ACCEPTANCE.md` and your `V0_3_ENGINEERING_REVIEW.md`.
2. `docs/design/V04_FIRST_FOOTSTEPS.md` — current canonical scope, world rules, persistence and UI seam.
3. `docs/design/world/v04_layout.json` — authored topology, coordinate convention, stable IDs and portals.
4. `docs/design/V04_WORLD_ART.md` — art budget, copy and what the HUD study does/does not implement.
5. `docs/design/DISPLAY_PRESETS.md` — Adrian's latest fixed display/text policy, superseding earlier
   independent text scaling and arbitrary-resize requirements. The display correction is working-tree
   work after the V0.3 push: no font preference, a locked 1280×720 canvas, supported window presets only.
6. `docs/DATA_CONTRACTS.md`, `docs/TESTING.md`, the current V0.2 UI/timing contracts and art guide.
7. `docs/design/V04_MAP_PRODUCTION.md` and `assets/art/world/first_footsteps_v01/README.md` —
   latest Director asset/camera/layer continuation, with separate art evidence under `docs/reports/v0_4_art`.

The new contract explicitly supersedes the old world hold **only for this stage**, based on Adrian's
latest request. Human M1.1 clarity, controller and listening checks are still open; do not mark them
passed. The uncommitted V0.4 design/UI starter is intentional new work after the V0.3 release; preserve it.
The display correction also retires the old font-size test matrix; preserve functional UI coverage
on the fixed canvas. Current post-release validation is recorded in
`docs/reports/v0_4_preparation/README.md`, separately from the immutable V0.3 acceptance baseline.

## Build the first complete journey

Two small continuous top-down areas: Gloamstead and Briarfen Reedway. One Bellkeeper, a preparation
bench selecting existing owned starter weapons, two-way reed gate, two visible stationary encounter
groups, an outside bypass, one far-side shortcut, a wayside bell and one persistent home consequence.
Reuse `fen_patrol` (optional) and `rot_grove` (guards the bell) without changing their definitions.
The Mirebell boss, extra towns/zones, gathering, crafting, economy, puzzle frameworks, pressure,
attrition, companions following in the world and random/chasing encounters are out of scope.

Start by restating requirements and identifying reusable systems, proposed interfaces, edge cases
and costly assumptions. Challenge a disproportionate cost with a concrete cheaper proposal. Routine
implementation choices within the contract are authorized; continue into implementation after the
architecture review. Report true design conflicts rather than silently choosing new game rules.

Work in reviewable increments:

1. Typed world state/definitions; eight-direction movement and feet collision; bounded camera;
   named safe anchors; paired portals with re-entry/input guards; old saves start at the square.
2. Interaction ownership, short dialogue, bench loadout seam and discovered local-map readout.
   Provide filtered data to `ExplorationHUD` / `ExplorationReadout`; its Map/Menu signals request
   host modes. Preserve the existing shell rather than replacing it with a second HUD. Blockout
   visuals and a functional plain map/dialogue are fine until Director integration.
3. Encounter confirmation and the battle host seam; exactly one immutable entry; full reset HP /
   configured starting Focus / potion capacities per fight. No carried attrition. Reuse the battle
   presenter and deterministic engine; preserve its timing, research and input contracts.
4. Atomic victory/progression/world-clear transaction with duplicate-token rejection. The current
   `GameState.record_battle` saves immediately, so it cannot independently run before the world result
   commit. The standalone BattleScene Retry increments the seed, so it cannot supply exact world retry.
   World defeat has no failed-attempt research/mastery gains; retry uses the captured entry. Keep
   existing Sandbox defaults and opt-in recording intact. Describe the chosen adapter and prove it.
5. Independent bell/latch flags; restored town bell pose + lamp state; derived NPC copy/objectives;
   saved discoveries/cleared groups and safe-anchor resume. No duplicate quest/choice/event truth.
6. World menu returning from Field Guide/Settings to the paused world, explicit save/title return,
   failed-write recovery and focus/held-input boundaries. Do not overwrite real developer user data.

Save entry before launching battle. Mid-battle quit resumes at the approach without awarding the
attempt. Successful result and boundary publish only after the complete write succeeds. Invalid
anchors recover to the square while preserving valid progress; a failure is not a silent refill or
permission to advance. Assess whether a small optional world section can remain save version 1;
if migration is required, implement and test it. Do not serialize Nodes/mutable Resources into saves.

Default world actions are separately rebindable and context-owned; no existing combat binding is
changed. Map and other modals suspend movement; focus loss pauses; closing input needs release before
reuse. Map selection does not travel. Readouts contain only discovered landmarks and known enemy
facts; do not leak definition names or affinities through accessible labels, markers or file IDs.

There is no approved exploration song yet: silence in town/route is intentional. Existing battle
music still plays. Exploration/presentation RNG must not consume combat RNG. Application becomes
0.4.0 when the actual playable loop is integrated, not merely because the study exists.

## Verification and return report

Run isolated QA through `tools/qa_godot.py`; use a fresh `.godot/qa/<run>` home on this host. Import
new classes, compile every script, run the complete Godot suite alone (UI wall-clock tests are
sensitive to concurrent captures/simulations), then simulations and Python preparation/import tests.
Do not fix Windows editor safe-save diagnostics by changing system security settings.

Add meaningful tests for world state/boundary behaviour: portals cannot bounce, Cancel cannot launch,
an entry launches once, duplicate victory cannot award twice, failed save does not publish changes,
defeat/retry is exact, quitting during battle restores approach, clear flags survive reload,
far-side latch eligibility works independently of the bell, completing before dialogue works,
old slots preserve their real progress, unknown map facts stay hidden and modal input cannot move.
Preserve combat fingerprints across the new host and prove its UI/audio cannot alter battle outcomes.

Return a concise engineering report with implemented interfaces, changes from the contract, checks
and actual Godot captures of the fixed game layout for town, route, map, encounter card and dialogue. Identify
blockout art explicitly. List remaining Director integration and human acceptance work honestly.
Do not commit/push the new V0.4 stage unless Adrian authorizes it separately.

## Separate approved audio follow-up

The Director retained 0.1 s Audio Lab keyboard seeking and natural quiet joins for V0.3. A base /
intense v01 synchronized pilot is approved for technical validation and manual Audio Lab use,
independent of this world loop. If you undertake it after the world foundation, use shared sample
bounds, keep original media, verify alignment throughout the pair and test native synchronized
playback per deck. Supply measurements and listening requirements before making it a default.
Automatic battle intensity policy, loop-region edits and full-score layer migration remain separate
design work. Do not make this pilot a prerequisite for V0.4 exploration.
