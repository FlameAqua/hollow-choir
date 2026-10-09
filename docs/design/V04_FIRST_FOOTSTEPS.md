# V0.4 — First Footsteps

Director contract · 8 October 2026 · **authorized for backend implementation**

Adrian explicitly requested exploration, a map and towns after Claude's V0.3 return. This authorizes
the bounded stage below and supersedes the previous world hold **for this stage only**. The human
combat clarity, controller and music-listening gates remain open. V0.3 was pushed as `6d8401d`;
this document describes new work, not features already present in that release.

## Design intent

Turn the battle foundation into a place. The player should remember the square, choose a path
through the fen, recognize a landmark without an arrow and return to evidence of their action.
V0.4 is one compact authored journey: **Gloamstead → Briarfen Reedway → wayside bell → Gloamstead**.
It starts the original world milestone; gathering, puzzle frameworks and the wider zone follow later.

| Feature | Purpose and decision | Systems / cost | Failure risk / cheaper choice |
|---|---|---|---|
| Two connected walkable areas | Orient by a home landmark, then follow or leave the main path | Movement, collision, camera, portals / medium | Getting stuck or spawning inside a portal; small authored areas, no streaming |
| Two visible encounter groups | Read a threat, choose to engage or explore around it | Existing BattleSetup/BattleScene, return boundary / medium | Duplicate battles/rewards or input bleed; stationary groups and explicit confirmation |
| One bell errand and one shortcut | Change the route and see a consequence at home | Typed flags, interaction, save / medium | Cosmetic claim without persistence; one binary restoration and one gate, no quest framework |
| Local map and small world HUD | Relate the current location to discovered landmarks | Filtered presentation readout / low–medium | A hidden encounter spoiled by a map label; discovered locations only |
| Short dialogue and preparation | Give departure a purpose and a tactical choice | One NPC, existing owned weapons/loadout / low–medium | Building an economy or Lab disguised as a town; one small preparation panel |

## Player experience and route

Target a first visit of roughly **10–15 minutes**, including one or two existing fights. This is a design
target, not a measured playtime. Maps are spaces for direct movement, not a node-selection board.
The overview study is a planning diagram; clicking its landmarks does not specify runtime travel.

**Gloamstead:** arrive beside the cold town bell, speak to the Bellkeeper, inspect the preparation
bench and head through the reed gate. Three buildings establish a lived-in settlement through
closed facades; no interiors or simulated residents are required. The bell anchors the square, and
continuous readable paths lead to the bench and eastward gate. The gate must come into view before
its exit trigger; it need not share one camera frame with the square. The preparation bench offers the three already-owned starter weapons, with honest
action differences using existing shared readouts. Keep Mara, the current familiar and potion
definitions; do not make a new equipment, shop or crafting screen.

**Briarfen Reedway:** a bent boardwalk follows the water north. A fork exposes a safe-looking side
path and a visible patrol. The player can scout the outside loop before deciding to fight. The
wayside bell is held by a second group. Beyond it, a latch opens the short southern return route
from the far side. A small overlook is optional discovery, with descriptive text and a map entry;
no material reward or stat unlock is attached.

**Homecoming:** ringing the wayside bell restores the town bell's response. Back in Gloamstead,
the bell's clapper is raised, the square's lamp is lit and the Bellkeeper acknowledges the new
sound. It does not cure the Bloom, lower regional Pressure or select CLEANSE/CULTIVATE/STABILIZE.
This is a small, legible event in the world, not a moral verdict or global corruption system.

Canonical planning coordinates, paths and IDs are in [the layout](world/v04_layout.json).
Coordinates are tile centres on a 32 px grid, with y increasing downward. They are blockout targets;
Claude may adjust individual collision cells for clearance while preserving sightlines and topology.

| Location / ID | Area | Function |
|---|---|---|
| Bell square / `town_bell` | Gloamstead | Initial spawn and visible consequence |
| Bellkeeper / `bellkeeper` | Gloamstead | Errand, then acknowledgement |
| Preparation bench / `preparation_bench` | Gloamstead | Existing owned starter weapons; departure rule |
| Reed gate / `reed_gate` | Gloamstead | Two-way portal to the route |
| Fork / `reedway_fork` | Reedway | Main path versus outside loop |
| Patrol / `reedway_patrol` | Reedway | Existing `fen_patrol`; optional, bypassable |
| Bell approach / `bell_guard` | Reedway | Existing `rot_grove`; blocks only bell interaction |
| Wayside bell / `wayside_bell` | Reedway | Restore after guard victory |
| Return latch / `return_latch` | Reedway | Open from the north/east side; persistent shortcut |
| Listening stones / `listening_stones` | Reedway | Optional quiet discovery |

Reuse `fen_patrol` and `rot_grove` unchanged, including their authored battlefield conditions and
current advantages. World approach supplies no extra surprise damage or initiative bonus. The
Mirebell boss stays outside this first route. Two stationary silhouettes may represent their groups;
no patrol AI, chasing, stealth meter or random encounters are needed.

## Rules and boundaries

1. **Move and interact:** continuous eight-direction movement with normalized diagonals, feet-based
   collision and a bounded camera. Keyboard arrows/WASD and left stick/D-pad are defaults in world
   context only; expose separate rebindable world actions without replacing saved combat bindings.
   Confirm interacts with the nearest eligible object in a short fixed radius; ties use stable IDs.
   No mouse click-to-move. Held portal/interaction input cannot activate the arriving area.
2. **Engage deliberately:** reaching an enemy's interaction radius shows an encounter confirmation
   with its public threat category, group count and authored battlefield conditions. Before species
   are known, no exact species, moves, stats or hidden weakness comes from the map or prompt. Cancel
   costs nothing. Confirm takes one captured encounter entry, freezes exploration and launches once.
3. **Resources:** choose **control C, all-reset encounters** from the resource candidate. Each battle
   begins with full HP, the existing configured starting Focus, fresh potion capacities and cleared
   transient effects. No carried HP or charges, injuries, currency, consumable inventory or pressure.
   Copy: “The party regroups between fights. HP, Focus and potion uses reset for each encounter.”
4. **Preparation:** change among already-owned starter weapons at the town bench. Changes take effect
   on the next entry snapshot; no field equipment UI. Do not make new rewards to justify the bench.
   Persistent chosen IDs use the existing loadout representation and validation.
5. **Victory:** atomically commit existing successful-battle research/mastery, the encounter's cleared
   flag and the return boundary exactly once. The group stays absent on revisits and after reload.
   No respawn clock, clear-region button, enemy-loot table or repeat farming in this stage.
6. **Defeat/retry:** world mode offers **Retry encounter** / **Return to Gloamstead**. Retry recreates the
   captured loadout, seed, knowledge, encounter and settings references; no fresh seed and no failed
   attempt's research/mastery or route progress. Return retains previously committed victories,
   discoveries, the shortcut and bell; it returns to the square with no fee. These are world-host rules;
   preserve the Sandbox's existing recording and retry behaviour.
7. **Bell:** guard victory permits restoration; restoring is a separate deliberate interaction. Store
   `wayside_bell_restored` once. The errand can be completed even before speaking to the Bellkeeper;
   dialogue derives from the same flag and cannot reset it. No separate quest-stage truth is necessary.
8. **Shortcut:** open `return_latch_open` only from its far-side interaction area. Opening removes its
   collision and updates the discovered map link immediately. It persists even if the bell is unlit.
   A closed, near-side latch says “The latch is on the far side.” There is no timed traversal puzzle.
9. **Save/resume:** safe boundaries are area arrival, completed discrete interaction, successful result
   commit and explicit world-menu save. Do not write every movement frame. Resume at the last valid
   named safe anchor, not arbitrary coordinates. Save encounter entry before launch; quitting during
   battle resumes at its approach with the encounter available and no failed-attempt gains. Mid-battle
   suspension is not promised. Explain this in the world menu.
10. **Failure:** failed save/result commit keeps the result pending and offers retry-save or return to
    title; do not announce committed progress or continue walking. On load, validate IDs against the
    approved area/anchor/content set, fall back to the square for an invalid anchor and keep valid
    progress. Unknown future fields must not become invented unlocks. Preserve old saves and backups.

## UI and interaction ownership

Follow [the fixed display contract](DISPLAY_PRESETS.md): 1280×720, 22 px Departure Mono body text,
existing `UITheme`, frame resources and focus treatment. Supported presets scale the whole canvas.
Map art is world-space pixel art; labels and controls are full-resolution UI. The preparation study
in `scenes/prototypes/v04_world_study.tscn` is presentation only and has no production menu entry.

- **World HUD:** compact area name and one current objective at upper left; Map and Menu at upper
  right; one contextual interaction prompt near the lower edge. No combat HP bars, minimap, quest
  checklist, inventory row or permanent navigation arrow. Objective is “Find the wayside bell”,
  “Restore the wayside bell”, then “Return to Gloamstead”; restored town shows “The town bell answers
  again.” These derive from area/guard/restoration state, with no extra quest stage to keep in sync.
- **Local map:** opened from the HUD/menu and a rebindable Map action (default M / gamepad Back in
  world context). Pause movement. Show current area and player position, discovered landmarks and
  traversed links. Unknown space is blank texture; no undiscovered object labels, enemies, loot or
  guard identity. Map selection provides descriptions, never fast travel. Back closes and refocuses.
- **Dialogue:** one speaker, at most two short paragraphs and one Continue/Close or clearly named
  choice. No dialogue graph editor, voice acting, portrait requirement or typing delay. Cancel closes
  optional conversation; event application is independent of text advancing.
- **Encounter card:** Engage / Leave, no countdown and no surprise collision battle. Use existing
  filtered knowledge and condition readouts. The world host alone hands input ownership to battle.
- **World menu:** Resume, Field Guide, Settings, Save and return to title. Nested screens return to the
  paused world, not the title; preserve the same live boundary. Reuse existing screens with an explicit
  return route. No “New game” overwrite control is introduced; Continue journey starts a default world
  section on an old slot while preserving earned research/mastery/loadout.
- **Focus:** use the fixed game layout; there is no independently resizable text. Longer objectives wrap;
  dialog/map detail content may scroll with fixed reachable closing controls. Prompt bindings follow
  the active device and remaps. World movement is released when any modal opens. Menu/Confirm used
  to close a modal must be released before exploration can use that input again. Focus loss pauses.

## Data and engineering seam for Claude

These are conceptual shapes, not a demand for these exact class names. Prefer small typed data over
a generic quest/event framework. Runtime definitions belong under `data/world`, not `docs/`.

| Boundary | Minimum content / invariant |
|---|---|
| Area definition | Stable ID; scene/resource; collision/camera bounds; named spawn anchors and paired portals; optional presentation music cue |
| Landmark / interaction | Stable ID, world position, public label, radius and explicit eligibility; no arbitrary executable expression strings |
| Encounter entry | Unique completion token; encounter and return anchor; actual seed; immutable resolved loadout, knowledge and selected difficulty/assist |
| World save section | Area/anchor; discovered landmark/link IDs; cleared encounter IDs; two restoration/gate flags; pending entry or null; last applied token |
| Presentation readout | Already-filtered area/objective/prompt; discovered map geometry and labels; dialogue/encounter card data; no raw engine or mutable save reference |
| Result transaction | One progression + world snapshot written successfully before publication; duplicate token is a no-op |

Reuse `ProgressState`'s existing fields where meanings match. Do not store the same bell flag in
quests, world choices and region events. A small optional `world` section can default older saves to
the square; Claude must assess whether additive save-version-1 compatibility is sufficient. If a
version bump is necessary, supply an explicit migration and old-save fixtures; never discard saves.

`BattleLaunch` already carries setup/return/recording, and embedded `BattleScene` exposes result and
restart/setup signals. World completion needs its own host/transaction seam: simply setting
`record_progress=true` would save before the world clear flag is committed. Simply using the current
standalone Retry would increment the seed. Reuse the engine/presenter, intercept these world-mode
boundaries explicitly and keep legacy Sandbox defaults. UI code must not duplicate research rules.

Exploration randomness and soundtrack shuffle use their own RNG. Existing combat setup+input replay
must stay deterministic. Regional Pressure remains untouched. Static dusk is art direction, not time
simulation. In town/route, use silence until an approved exploration cue exists; existing battle cues
still play during battle. Do not turn a battle song into permanent town ambience merely to fill silence.

## Art direction and production order

Follow [the art guide](../../assets/art/STYLE_GUIDE.md). Start with readable collision blockouts,
then replace surfaces after a real movement pass. Do not stretch the side-on combat backdrops into
walkable maps or use combat portraits as walking sprites. The [world art brief](V04_WORLD_ART.md)
defines the limited asset budget and actual HUD study. Art never changes collision or save truth.

Adrian subsequently authorized asset preparation in parallel with Claude's backend. The
[map production contract](V04_MAP_PRODUCTION.md) refines camera/layers/collision and the
[first exploration pack](../../assets/art/world/first_footsteps_v01/README.md) supplies integration
candidates. Production dressing still follows graybox traversal; its isolated art workbench does not
implement this journey's world systems.

## Acceptance and staging

1. **Claude foundation:** architecture review, typed world state, movement/camera, two-way portal and
   save-safe anchors. One journey starts from an old save without erasing progress.
2. **Claude loop:** public encounter confirmation; unchanged fights; exact retry; idempotent successful
   result; bell, latch and home consequence; discovered local map data; paused modal return paths.
3. **Director integration:** replace blockouts, integrate finished HUD/map/dialogue using typed readouts,
   tune sightlines and collision readability, capture the fixed game layout and review the complete loop.
4. **Shared verification:** demonstrate the bypass, far-side shortcut, quit/reload at each boundary,
   cancelled encounter, duplicate result, save failure, defeat/retry/return, old-slot compatibility,
   hidden-map knowledge and focus/input boundaries. Existing suite/simulations remain clean.
5. **Human pass:** walk the route without coaching, identify the home change and return shortcut;
   separately continue the M1.1 clarity/controller/listening sessions. Automated evidence never fills
   those observations. Bump application to 0.4.0 when the playable world loop is integrated, not now.

Defer other zones/towns, boss expansion, procedural events, gathering/crafting, shops/currency,
day/night simulation, follower AI, traversal abilities, two puzzle frameworks, attrition, pressure,
fast travel and automatic adaptive music. The aligned-audio pilot has separate authorization in
the V0.3 acceptance report; it must not become a dependency of walking through this first route.
