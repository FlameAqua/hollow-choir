# Claude execution prompt — V0.4 First Footsteps

You are continuing Hollow Choir as lead gameplay/backend engineer. Implement V0.4 First Footsteps
from the current working tree. ChatGPT is the Director and owns creative decisions, artwork and
final UI polish. Your task is to deliver the functioning exploration journey and connect the prepared
presentation assets to it. Begin with a concise architecture assessment, then continue into implementation
and verification in this session. A plan alone is not the deliverable.

Repository: `C:\Users\Adrian\Code\Games\hollow-choir`.

Inspect repository instructions and Git status first. V0.3 is already pushed to `origin/dev` as
`6d8401d`. The current uncommitted display correction, V0.4 contracts, HUD starter, artwork and
preview scenes are intentional Director work. Preserve them; do not reset or replace the checkout.

Read these before implementing:

1. `docs/briefs/V0_4_CLAUDE_HANDOFF_PROMPT.md` — complete engineering scope and acceptance requirements.
2. `docs/design/V04_FIRST_FOOTSTEPS.md` and `docs/design/world/v04_layout.json` — journey, rules,
   authored topology, stable IDs, progression and save boundaries.
3. `docs/design/V04_MAP_PRODUCTION.md` — latest camera, editable layers, graybox and collision decisions.
4. `docs/design/V04_WORLD_ART.md` and `assets/art/world/first_footsteps_v01/README.md` — prepared assets,
   animation/resource interfaces, dialogue copy and remaining art limitations.
5. `docs/design/DISPLAY_PRESETS.md` — fixed game display policy.
6. The supporting project/data/testing contracts referenced by the handoff, plus
   `docs/reports/v0_4_preparation/README.md` and `docs/reports/v0_4_art/README.md` for existing evidence.

The latest Director contracts supersede historical world-development holds and independent font-size
requirements. Routine implementation choices within this scope are authorized. Flag a genuine design
conflict with a concrete proposal; do not expand the scope to solve it.

Deliver one complete playable journey: enter Gloamstead from the title/continue flow, talk to the
Bellkeeper, prepare with already-owned starter weapons, walk through the reed gate into Briarfen
Reedway, explore the bypass, deliberately engage the existing `fen_patrol` and `rot_grove` encounters,
restore the wayside bell, open the return latch from its far side, and return to a changed town bell,
lamp and acknowledgement. The patrol remains optional. Bell and latch flags remain independent.
Support a discovered local map and the paused world menu, including Field Guide/Settings return paths.

Use connected areas larger than one screen, a following bounded camera, editable TileMapLayer nodes
and placed scene instances. Keep ground, decoration, depth-sorted actors/props, overhead roofs and
future lighting/effects separate. Start with readable graybox collision, then attach the prepared
foot-origin actor scenes and native atlases where suitable. Preserve `ExplorationHUD` and its filtered
readout seam. Supply functional plain map/dialogue/encounter/menu UI so the journey is playable before
Director polish. The two F6 prototypes are authoring fixtures; do not promote their hardcoded movement,
sample collision, combined state switches or `docs/` layout loading into production gameplay.

Hollow uses four-direction idle/walk SpriteFrames for eight-direction movement; walk animation follows
actual displacement. Enemy groups remain stationary with optional idles. The TileSet excludes two bad
bank corners and has no terrain-autoconnect rules. Use placeholders where needed rather than blocking
backend completion on final art cleanup. Collision follows feet and solid bases, independently of
sprite alpha, roofs and glow.

Treat persistence and battle integration as core acceptance work: capture one immutable encounter
entry, save it before launch, reset battle resources per the contract, atomically commit successful
research/mastery plus world clear state exactly once, and publish only after the write succeeds.
Defeat awards no failed-attempt gains; retry reuses the captured seed/loadout/knowledge. Quitting
mid-battle returns to the saved approach without an award. Test duplicate completion, failed writes,
invalid anchors and old saves. Preserve existing Sandbox behaviour and deterministic combat outcomes.

Keep world inputs separately rebindable and context-owned. Guard portals and modal closing against
held-input reuse; pause movement on modals/focus loss. Map/readouts expose only discovered or public
facts. Keep the fixed 1280×720 canvas, 22 px body text, supported resolution presets and locked window
resizing; do not reintroduce text-scale controls or arbitrary-size UI matrices.

Do not add new combat content, a boss, economy, gathering/crafting, attrition, pressure, follower AI,
chasing/random encounters or a seamless-world framework. Town/route silence is intentional until an
exploration track is approved; retain battle music. The synchronized-audio pilot is separate and must
not delay this task. Application version stays 0.3.0 until the actual V0.4 loop is integrated.

Verify through `tools/qa_godot.py` using isolated user data. Add meaningful world-boundary regressions,
compile all scripts, run the full Godot suite alone, then the relevant simulations/Python tests and
asset validation. Existing evidence is 213 passing game tests, 195 compiled scripts and 204 asset
checks; those are prior results, not a substitute for your final checks. Do not change system security
settings to suppress the known Windows editor safe-save warning.

Finish with `docs/reports/V0_4_ENGINEERING_REVIEW.md`: implemented interfaces, contract deviations,
actual verification results, native captures of town/route/map/encounter/dialogue, and remaining
Director integration or human review. Distinguish blockouts/candidate art from finished assets.
Human/controller/listening acceptance remains open until observed. Do not commit or push V0.4
without Adrian's separate authorization.
