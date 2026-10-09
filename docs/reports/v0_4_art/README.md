# First Footsteps — asset preparation evidence

9 October 2026 · application remains 0.3.0 · uncommitted Director preparation

Delivered [pack](../../../assets/art/world/first_footsteps_v01/README.md),
[map production contract](../../design/V04_MAP_PRODUCTION.md) and
[provenance/prompts](../../art/first_footsteps_v01/prompts.json).
Seven unchanged source PNGs produce seven native atlases, four SpriteFrames resources, four
foot-origin actor scenes, twenty-two prop/facade AtlasTextures and a fourteen-tile TileSet.
The two rejected lower bank-corner cells remain in the exported contact sheet but cannot be painted
from the TileSet. Source alpha is retained; nearest resampling is mechanical preparation, not cleanup.

## Verification

- `tools/validate_world_art.gd`: **204 checks, 0 failures**. Source SHA-256 preservation, actor
  animation/frame counts, native cell dimensions, region bounds, transparent corners, consistent
  foot baselines, external SpriteFrames references, actual playback advancement, static resource
  loads, rejected-corner exclusion, lossless/no-mipmap imports and a preview movement/collision pass.
- The preview pass walks east, retains east facing at rest, blocks feet against the bell, stops
  walking animation against that block and stops movement while the sheet panel is open.
- `tools/check_scripts.gd`: **195 scripts checked, 0 failed** after the final scripts/asset changes.
- Native 1280×720 captures use the Compatibility renderer, Dummy audio and isolated user-data homes.
  Capture and validation processes exited cleanly. Editor import reported the previously observed
  Windows safe-save warning but imported the textures; subsequent load/render/compile checks passed.
- No production gameplay/engine change was made in this asset task. The previous full game suite
  result remains 213 passing tests; it was not rerun or relabelled as a new asset-task result.

## Native visual review

- [Gloamstead bell square](gloamstead.png): Hollow, quiet bell/lamp, feet and prop footprint overlay.
- [Reedway fixture](reedway.png): rootcap group, willow, water and simple presentation geometry.
- [Native sheet inspection](sheets.png): four-direction walk sheet, two group idles, terrain atlas.
- [Facade construction](facade.png): separate roof/wall join, Bellkeeper, Hollow and solid base.

These are captures of `scenes/prototypes/v04_art_workbench.tscn`, **not production gameplay**.
The preview's large authoring toolbar explains its upward camera offset. Geometry reads the existing
Director planning layout and simple fixture collision; production boundaries, interaction eligibility,
portal arrival handling, map discovery, state flags and save transactions remain Claude's backend work.

## Remaining review

The fourteen terrain candidates still need seam/repeat cleanup, especially bank transitions.
No autoconnect rules are authored. Generated walk/idle poses and state pairs need final pixel review;
source poses can vary slightly beyond the intended change. Willow source foliage touches its cell
edge. Roof alignment is demonstrated for the stillroom; all final dressed modules need traversal
review. The open gateway still needs production post footprints and a separate portal trigger.
Human/controller traversal, final art approval and the complete V0.4 journey are not claimed.
