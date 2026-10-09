# Material and idle art — second playtest pass

Created 2026-10-09 using the built-in image-generation tool. UI and reaction sheets were generated from descriptions with transparency; Hollow and Bell Crow were reference-image edits with transparency. Exact prompts are in `material_polish_v02_prompts.json` and `bell_crow_idle_v02_prompt.md`.

Immutable source PNGs:

- `assets/art/global/ui/material_v02/sources/materials.png`
- `assets/art/global/ui/material_v02/sources/reactions.png`
- `assets/art/world/first_footsteps_v01/sources/hollow_idle_v03.png`
- `assets/art/global/familiars/sources/bell_crow_idle_v02.png`

`tools/prepare_material_polish.gd` performs mechanical crop, uniform nearest-neighbour reduction and placement on transparent native canvases. It does not paint or synthesize artwork. Reaction regions use measured rectangles because the generated sheet's lower rows did not follow an exact grid. Run with `--images-only`, import the images, then run again to save tracked SpriteFrames resources. UI textures use lossless imports, nearest filtering and no mipmaps. Runtime UI references the cropped textures directly through `UICraft`; source sheets do not need to ship.

Hollow v03 retains the eight existing walking cycles from v02. Each idle direction uses a two-frame standing pair at 1.4 fps. Feet align at (32,60) in a 64×64 cell. No fractional sprite scaling is used in exploration. Reduce Motion holds the standing frame. Generated diagonal poses remain candidates for future art review; they do not imply a new character design approval.

Bell Crow v02 has four planted idle fidgets at 2 fps. The original single-frame sprite and portrait remain intact. Combat uses its new idle canvas without stretching and holds frame zero with Reduce Motion.

The map, leather pouch, woven panels, attack/technique/utility frames, portrait and intent sockets, reaction rings/medallions, meter track/needle/cursor and cracked break badge are raster assets. Nine-slicing keeps authored fittings intact; centre tiling avoids enlarging the fabric weave across large menus. Actual timing-window widths still come from the existing reaction specification and clock.
