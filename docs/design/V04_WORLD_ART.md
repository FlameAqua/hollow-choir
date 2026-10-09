# First Footsteps — world presentation and art brief

Director · 8 October 2026 · accompanies [the V0.4 contract](V04_FIRST_FOOTSTEPS.md)

**9 October asset continuation:** Adrian explicitly requested asset production while Claude builds
the backend. [The delivered pack](../../assets/art/world/first_footsteps_v01/README.md) supplies
generated movement/idle candidates, terrain, props and separated walls/roofs. Follow
[map production](V04_MAP_PRODUCTION.md) for connected areas, following camera, editable layers and
graybox-first collision. This supersedes the earlier requirement to wait before preparing artwork;
final dressing/approval still follows the actual traversal pass. The original schematic remains an
authoring aid; the new F6 art workbench renders native sprites without production world systems.

## Visual identity

Gloamstead is a small working settlement keeping a familiar ritual alive. Use low stone footings,
patched ivory cloth, soot-dark timber and tarnished brass; an unlit bell structure anchors the square.
Give the workshop and stillroom distinct roof silhouettes. The route's gate is a visible break in a
reed fence, not a glowing portal. Keep entrances, feet and walking surfaces clear in value.

Briarfen is wet, tangled and quiet. Its bent boardwalk should remain the strongest continuous shape
against peat water and olive reeds. Roots interrupt the bank without visually disguising collision.
The outside loop is narrower and rougher but equally readable; it is a path the player can choose,
not a hidden passage requiring pixel hunting. The wayside bell shares Gloamstead's material language,
with the Bloom growing around the structure. The listening stones frame a view of the water.

Static late dusk unifies both areas. Warm light is reserved for the restored home lamp and a small
bell highlight; cold fen lights stay sparse and decorative. No day/night clock, occluding fog, animated
lighting framework or implied moral palette. Restore the bell through a raised clapper and lit lamp
as well as colour. Reduced motion keeps the same stable before/after poses.

## Limited production pack

Prepare candidates in parallel with backend work, then integrate after collision and sightline review.
The table records the initial budget; the delivered pack and its documented frame sizes now govern
integration. Generated bitmap candidates keep their provenance and require final-size artist review.

| Asset family | Initial budget | Technical direction |
|---|---|---|
| Terrain | One shared 32×32 tile atlas | Peat, shallow water, bank edges, packed path, straight/corner boardwalk, reed border; no animated water needed |
| Town dressing | Three facade modules, one fence/gate family | Reuse wall/roof pieces; no interiors or enterable decorative doors |
| Landmark props | Town bell, wayside bell, bench, latch, lamp, listening stones | Two bell/lamp states; separate base and overhead pieces where occlusion requires them |
| Player | One 32×48 overworld sprite, four directions, idle + short walk | Foot anchor bottom centre; collision comes from a small independent feet shape; keep the recognizable protagonist silhouette |
| NPC | One Bellkeeper idle sprite | No walking, schedule, portrait or lip sync required |
| Threat groups | Two simple overworld silhouettes | Readable group markers; do not shrink the side-on portraits into top-down actors; combat retains existing art |

Nearest filtering, lossless imports, no mipmaps; visual clusters at their intended pixel grid. The
world camera may use a consistent integer zoom while the UI stays full resolution. Avoid baking
labels, interaction prompts, light cones, hitboxes or gameplay symbols into terrain art. Roof/reed
occlusion cannot hide the player, the prompt's source or a usable path; use an unambiguous depth
layer and a simple local fade only if a movement pass demonstrates a need.

## UI starter and presentation study

`ExplorationHUD` receives an `ExplorationReadout` with area, objective, interaction label and the
already-resolved active binding. It emits Map/Menu requests. It stores no world state, chooses no
objective and calculates no eligibility or knowledge. Claude can supply this seam from the world
host; map/dialogue/encounter readouts remain a backend deliverable before their final UI integration.

The development scene [v04_world_study.tscn](../../scenes/prototypes/v04_world_study.tscn) can be run
directly (F6). It displays the real HUD over a deliberately plain layout diagram and has local study
controls for town/route and before/after. Map/Menu open explanatory study panels, not implemented
game features. It writes no saves/settings and is absent from the production title menu. “After”
illustrates a completed journey with both bell and shortcut changed; runtime flags remain independent.
Its layout source is under `docs/`, excluded from game exports. Runtime area data must live elsewhere.

The interaction prompt sits above the study controls here; production uses the normal 24 px inset.
The actual world will occupy the viewport behind the HUD. The small central diagram is an inspection
aid, not the proposed in-game camera zoom or a playable map. Do not report study captures as gameplay.

Use [the fixed display contract](DISPLAY_PRESETS.md). The separate font-size setting and scale
matrix were retired at Adrian's request; do not build a responsive app interface for this game.
Actual Godot captures and their limits: [preparation evidence](../reports/v0_4_preparation/README.md).
The interactive conversation layout study is likewise a schematic for design review, not game art.

## Copy ready for the first errand

**Bellkeeper, before restoration:** “The fen bell has gone quiet. Ours has nothing to answer.
Follow the old boards beyond the reed gate. If the bell still hangs, give it a voice.”

**Wayside bell, before the guard is cleared:** “Roots crowd the bell's frame. The creatures at its
foot have not moved.” Action: **Leave**; the separate visible group owns encounter confirmation.

**Wayside bell, after guard victory:** “The bell is whole beneath the roots. Its rope is within
reach.” Actions: **Ring the bell** / **Leave**. After restoration: “A thin note carries home.”

**Near-side latch:** “The latch is on the far side.” Far-side action: **Open the return gate**.

**Listening stones:** “The boards end here. Beneath the reeds, water keeps its own slow rhythm.”
Discovery label: **Listening stones**. No item notification or fabricated research award.

**Bellkeeper, after restoration:** “There. Did you hear it? Not loud, but ours answered.
We can keep a place for that sound.” Action: **Close**.

These lines do not infer a new faction allegiance, named companion history or corruption choice.
Localize labels and prose through the same future presentation boundary; do not embed branching
conditions in the text or require the opening conversation before completing the route.
