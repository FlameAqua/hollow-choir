# First Footsteps — exploration art pack v01

Director delivery · 9 October 2026 · **generated candidates for integration and movement review**

This pack extends Hollow Choir's existing ivory/charcoal/olive/rust material language into top-down
exploration. It does not replace combat art. Sources were created/edited with the **built-in image_gen
tool**; exact prompts, reference roles and measured regions are in
[provenance](../../../../docs/art/first_footsteps_v01/prompts.json) and
[source regions / SHA-256](../../../../docs/art/first_footsteps_v01/regions.json).

## Delivered resources

| Asset | Native resource | Contract |
|---|---|---|
| Hollow v02 | `frames/hollow_motion_v02.tres`, `scenes/hollow.tscn`, `atlases/hollow_motion_v02.png` | Eight directional four-frame walks + held idles; 64×64 cells; body up to 48 high; foot (32,60); 5 fps; original north/south retained |
| Fen Patrol | `frames/fen_patrol.tres`, matching scene/atlas | Four-frame group idle; 128×96; foot (64,92); body height 64; 2 fps |
| Rot Grove | `frames/rot_grove.tres`, matching scene/atlas | Four-frame group idle; 128×96; foot (64,92); body height 80; 2 fps |
| Bellkeeper | `frames/bellkeeper.tres`, matching scene/atlas | Two-frame idle; 64×64; foot (32,60); body height 44; 1.5 fps |
| Sixteen props | Individual `atlases/<id>.tres` in `atlases/props.png` | 128×128 cells; foot (64,124); art only |
| Three facade modules | `<stillroom/home/workshop>_walls.tres` + `_roof.tres` | Separate pieces, 192×192 cells; foot (96,188); widths 128/112/160 |
| Terrain | `terrain.tres`, `atlases/terrain_32.png` | 32×32 grid, fourteen paintable candidates; two rejected corner cells excluded |

Presentation scenes put local origin at the actor's feet. Attach them under Claude's existing
controller/interaction roots. Keep SpriteFrames external so edits apply to instances. Props and roofs
are AtlasTextures; position their top-left at `-foot` relative to their intended contact point.
For the facade study, roof contact sits 76 px above the wall's ground contact; finalize the overlap
per module after the movement pass. No collision is embedded in the presentation scenes or textures.

Hollow animations: `walk_south`, `walk_west`, `walk_east`, `walk_north`, `walk_southwest`,
`walk_southeast`, `walk_northwest`, `walk_northeast`, and equivalent `idle_` names.
Idle retains facing and has subtle foot-anchored breathing; walk follows actual displacement.
NPC/enemy optional breathing holds its first frame under reduced motion. No enemy pursuit/walk,
combat attack/death, follower or NPC schedule is included in this stage.

Props: `town_bell_quiet`, `town_bell_answering`, `wayside_bell_quiet`, `wayside_bell_restored`,
`preparation_bench`, `return_latch_closed`, `return_latch_open`, `listening_stones`, `lamp_unlit`,
`lamp_lit`, `reeds`, `fallen_root`, `fence`, `reed_gate`, `willow`, `boulders`.
Bell/lamp/gate pairs use common scale and ground contact. Generated pairs are not guaranteed to be
pixel-identical apart from the changed component; review state changes at final gameplay scale.
The reed gate uses a separate open-gateway source with a visibly empty centre. Its preview scene
scales it 1.5× for a roughly two-tile walking gap; collision/trigger placement remains backend work.
The earlier closed decorative panel remains unchanged in the source prop sheet as provenance.

## Preview

Open [v04_art_workbench.tscn](../../../../scenes/prototypes/v04_art_workbench.tscn) and run F6.
WASD/arrows walk the preview; Gloamstead/Reedway changes the fixture; Before/After swaps examples;
Footprints overlays selected solid bases and feet; Lighting changes world-only tint; Sheets inspects
the native atlases. Close Sheets using the same button to resume walking. Camera follows and clamps.

This is an **art fixture**, not the playable V0.4 world. It reads the Director's layout under `docs/`,
has simple fixture collisions and never changes saves/settings, discovers locations, starts battles
or operates production portals. Its combined After switch does not redefine independent world flags.
Do not promote its hardcoded preview movement or terrain boundaries into production backend code.

## Source and export policy

The 9 October playtest motion supplement uses the built-in image generator, with the original
Hollow source as an identity reference. Source, export and prompt are versioned separately:
`sources/hollow_motion_v02.png`, `atlases/hollow_motion_v02.png`,
`frames/hollow_motion_v02.tres`, and [motion prompt](../../../../docs/art/first_footsteps_v01/hollow_motion_v02_prompt.md).
The new side/diagonal rows alternate contact and narrow passing poses. Original four-facing
sources/frames stay intact. North/south animation uses the original art at 5 fps rather than 7.
No face pixels were manually retouched; remaining mask/contour continuity needs motion review.
Export this supplement with `tools/prepare_hollow_motion.gd` after its atlas has been imported.
The historical `prepare_world_art.gd` rebuilds the original v01 resources; do not run it over
the authored production resources as a routine cleanup.

`sources/` preserves all seven generated images unchanged, including the earlier enemy extraction
attempt. It is excluded from Godot imports using `.gdignore`. The accepted enemy export uses
`encounter_groups_cutout_attempt.png`; the earlier `encounter_groups_generated.png` is provenance only.
Actual source dimensions differ from requested dimensions. The town sheet's object columns are
uneven, so measured rectangles explicitly isolate every wall, roof and NPC rather than guessing a grid.

[prepare_world_art.gd](../../../../tools/prepare_world_art.gd) mechanically crops those regions,
resizes with nearest sampling, preserves alpha and aligns pivots. This is **not artist pixel cleanup**.
Keep the original sources and version any later approved replacement exports. Native PNGs use
lossless import, nearest filtering and no mipmaps. The manifest maps stable presentation IDs.

Rebuild with the isolated launcher (set `--godot` to the local executable):

```sh
python tools/qa_godot.py --headless --script res://tools/prepare_world_art.gd -- --world-export-images-only
python tools/qa_godot.py --headless --editor --import
python tools/qa_godot.py --headless --script res://tools/prepare_world_art.gd
python tools/qa_godot.py --headless --audio-driver Dummy --script res://tools/validate_world_art.gd
```

## Remaining art work

The generated walk/idle frames need artist review for pose continuity and tiny contour changes.
Terrain needs quieter repeat texture, explicit seam cleanup and carefully authored bank/corner joins.
The two lower bank corners were rejected and are absent from `terrain.tres`; the sheet keeps them
for provenance. There are no terrain/autoconnect rules. Do not infer they are seamless from the PNG.
Willow foliage touches its source cell edge and is a dressing candidate, not a final canopy cutout.
Walls/roofs need final joint alignment. Decorative doors remain closed; no interiors are promised.

Integrate after the graybox traversal pass under the
[map production contract](../../../../docs/design/V04_MAP_PRODUCTION.md). Lighting occluders,
portal triggers, collision footprints and state-driven visibility belong to the map/backend,
not to source image alpha. Human art approval and completed gameplay remain separate gates.

## 9 October production scene integration

The playable area scenes now use this pack with native shoreline joins, boardwalk detail layers,
tile flips and tuned roof overlap. Bell/lamp states share the quiet frame/post outside limited
changing regions; the reed gate reassembles two source-post regions along its east–west opening.
These are scene/AtlasTexture compositions, not replacement source PNGs. The art workbench still
shows the original complete candidate textures. See [Director review](../../../../docs/reports/V0_4_DIRECTOR_ACCEPTANCE.md)
for native captures, source-art limits and the outstanding human art/movement gates.
