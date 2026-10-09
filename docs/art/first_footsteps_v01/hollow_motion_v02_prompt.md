# Hollow movement supplement v02

9 October 2026 · built-in `image_gen` · identity reference:
`assets/art/world/first_footsteps_v01/sources/hollow_walk.png`.

Saved source: `assets/art/world/first_footsteps_v01/sources/hollow_motion_v02.png`.
Native export: `assets/art/world/first_footsteps_v01/atlases/hollow_motion_v02.png`.
Runtime frames: `assets/art/world/first_footsteps_v01/frames/hollow_motion_v02.tres`.

## Final prompt specification

```text
Production candidate pixel-art movement sprite sheet for Hollow Choir, a top-down three-quarter
RPG. Use the supplied original Hollow sheet as character identity and material reference.
Generate a supplemental sheet with convincing leg movement. Same cream hood, bone-white oval
mask with black eye holes, olive scarf, charcoal ragged coat, brown backpack and brown boots.
Keep the mask shape, face, torso, proportions and costume identical within each direction.
No weapon swinging, large arm motion, face morphing, ground shadows, dust or scenery.

Transparent RGBA canvas, exactly four columns and six rows. Cells 256 by 256, canvas 1024 by
1536. One whole character centered per cell, consistent scale and feet near baseline y=224.
Wide transparent gutters. No grid lines, labels, text or background color.

Rows from top: WEST, EAST, SOUTHWEST, SOUTHEAST, NORTHWEST, NORTHEAST. Correct back of hood
and backpack for the two rear diagonals. Same viewing angle and scale in every frame.

Four columns per row: left-foot-forward contact; narrow passing pose with feet close beneath
the hips; right-foot-forward contact; the opposite narrow passing pose. Clearly different leg
silhouettes: columns two and four MUST bring the feet together. Avoid keeping both legs spread
in every frame. Small counter-swing of arms and quiet scarf/coat follow-through only.

Restrained 16-bit pixel RPG craft, crisp square clusters, readable small silhouettes, warm
near-black outlines, cream bone, olive, slate charcoal and muted brown. Tiny upper-left material
highlights, no dramatic lighting, glow, smooth gradients or painterly antialiasing. Genuine alpha
outside all characters. No checkerboard, watermark, cast shadow or decorative frame.
```

The built-in result is preserved byte-for-byte as the source. `tools/prepare_hollow_motion.gd`
performs mechanical cell extraction, uniform nearest-neighbour reduction and feet alignment.
It does not repaint the mask or manufacture missing leg poses. The native sheet contains the six
new directions; the SpriteFrames resource also keeps the original north/south textures at 5 fps.
Standing uses a narrow held pose with a small runtime breath, frozen by Reduce motion.

These remain generated candidates. Alternating contact/passing silhouettes are present; exact
opposite-leg anatomy and mask continuity still deserve Adrian's movement review at game scale.
