# First Footsteps — map construction and asset seam

Director · 9 October 2026 · responds to Adrian's request to produce exploration assets while
Claude builds the backend. This authorizes parallel asset preparation before final collision review;
it does not freeze untested graybox boundaries or claim that generated art is finished pixel cleanup.

## World structure

Use **connected, continuous areas with a following camera**. Gloamstead is one area, Briarfen Reedway
another. Each is larger than one screen. A deliberate, named exit connects them; reaching an arbitrary
screen edge does not flip to a new screen. No seamless continent, streaming framework or screen grid
is needed. Future areas join through the same portal contract, retaining local identity and save anchors.

The [authored layout](world/v04_layout.json) remains the topology authority. Use its 32 px world grid,
80×56 and 96×88 tile area bounds. A 2× world camera is the initial art-preview scale: the fixed
1280×720 game canvas sees 640×360 world pixels before HUD coverage. This zoom is an art starting point
for the real movement pass, not a player zoom setting. Keep UI at its existing full canvas resolution.
The preview's upward camera offset accommodates its large authoring toolbar; production should tune
framing against the compact exploration HUD. Clamp camera to area bounds and keep pixel positions crisp.

## Editable area structure

Use a scene per area with native TileMapLayer nodes and individually placed scene instances.
Do not flatten the map into a giant background PNG. The same tile library can support both areas.

| Layer / node | Content | Sorting / ownership |
|---|---|---|
| Ground | Peat, water, packed path, paving | Fixed behind actors; editable 32 px cells |
| GroundDetail | Boardwalk pieces, shallow ripples, small surface marks | Below feet; does not automatically imply collision |
| LowDecoration | Small reeds, mushrooms, scraps, ground decals | Below actors; minimal visual noise |
| DepthSorted | Player, NPC, encounter groups, walls, prop bodies, tree trunks | One shared Y-sort group, origins at ground contact |
| Overhead | Detached roofs, appropriate canopy/front foliage pieces | Explicit foreground; never hide a usable exit or interaction |
| WorldLighting | Ambient tint, future local lights and shadow occluders | World canvas only; UI excluded |
| WorldEffects | Future mist, weather, color/post processing | Separate optional presentation pass; no gameplay truth |
| Collision / Interactions | Solid footprints, area limits, portals, eligible interaction radii | Backend-owned geometry and state; independent of painted alpha |
| Interface | Existing HUD, map, dialogue, menus | Separate CanvasLayer, fixed display policy |

Y-sorted actors and props must share a comparable Z index. A roof placed in Overhead deliberately
does not participate in foot sorting. If a large canopy needs partial sorting, split its trunk and
canopy rather than changing the player's depth arbitrarily. Begin with clear sightlines; add a small
local occlusion fade only where the real movement pass proves it useful. No new general shader or
weather framework is required for V0.4. Keep before/after prop changes to the existing stable IDs.

Godot supports separate [TileMapLayer nodes](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html),
tile collision/occlusion data and [Y-sort origins](https://docs.godotengine.org/en/4.5/tutorials/2d/using_tilemaps.html).
Future light shadows use their own
[LightOccluder2D geometry](https://docs.godotengine.org/en/latest/classes/class_lightoccluder2d.html),
which is separate from movement collision. These are engine facilities, not requirements to build
every lighting feature now.

## Graybox and collision order

1. Preserve the authored routes, bypass, encounter approaches, far-side latch and paired exits.
   Walk the graybox with the actual feet shape and camera. Keep comfortable clearance for diagonal
   movement; start main routes at four tiles, outside loop at three to four, and door/gate openings
   at two tiles. Do not tune every passage around the sprite's scarf or hood.
2. Paint blocked ground using tile physics; use simple closed polygons/rectangles for irregular banks,
   building bases and large props. Avoid hundreds of tiny traced contours. A solid map boundary is a
   closed boundary, not an unconnected set of decorative lines. Use separate Area2D triggers for
   portals and interactions; they are not solid walls.
3. Keep the player's collision near its feet: the preview uses a **10×6 rectangle** on a 32 px grid,
   positioned immediately above the foot origin. Treat that as an initial tuning value for Claude,
   not an immutable gameplay hitbox. Battle target/hit rules remain unchanged.
4. Replace graybox surfaces with tiles and props. Set the visual foot origin to match the existing
   boundary, then tune collision only for legibility and clearance. A lamp's glow, broad roof,
   branch or empty transparent margin is never a solid footprint.
5. Review near-side/far-side latch use, path corners, wall sliding, camera limits, keyboard/controller
   traversal and both arrival anchors. Save IDs, trigger ownership and progress remain backend truth.

The facade rectangles in the layout reserve building **lots and sightline space**. The delivered
facade modules are smaller building fronts within those lots; their image size does not turn the
entire reserved rectangle into a collision block. Claude should finalize those footprints in the
graybox before Director dressing fills the lots.

## Delivered pack and integration

The pack is [first_footsteps_v01](../../assets/art/world/first_footsteps_v01/README.md).
Its native atlases, SpriteFrames and foot-origin presentation scenes are ready for integration trials.
Hollow uses 64×64 frames with an approximately 32×48 body and extra scarf/stride clearance. Enemy
groups use 128×96 frames; they animate at their feet without changing encounter state. Bellkeeper
uses 64×64 frames. World sprites are separate from the existing combat portraits.

Claude should attach a presentation scene to its controller/interaction root. Direction names are
`idle_south/west/east/north` and `walk_south/west/east/north`. Eight-direction movement uses four
facing animations; preserve the last facing at rest and avoid alternating facing on equal diagonals.
Walking animation follows actual movement, not held input into a wall. Required walking remains
visible under reduced motion; optional NPC/enemy breathing stays on its first frame.

The F6-only [art workbench](../../scenes/prototypes/v04_art_workbench.tscn) demonstrates native assets,
following camera, foot alignment, simple fixture collisions, world-only tint, sheet inspection and
before/after examples. It has **no** production route entry, encounter activation, portal, discovery,
save or progression. Its paths/geometry are presentation fixtures and cannot replace Claude's world
controller, validated collision map or state-driven bell/latch visibility. “After” changes both
fixture flags together only for review; production flags remain independent.

No need to pause the backend for this pack. Retain simple placeholders where a tile edge or animation
is less readable. Terrain has fourteen paintable candidates; two bad generated lower bank corners
remain visible in source/export provenance but are deliberately absent from the TileSet. No terrain
autoconnect rules or seamless-border approval is claimed. Final bank joins, roof joins, sprite
cleanup and collision dressing follow the playable graybox pass.
