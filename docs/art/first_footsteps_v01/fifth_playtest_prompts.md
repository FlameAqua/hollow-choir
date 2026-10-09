# Fifth playtest mask repair — 9 October 2026

Built-in image_gen, `precise-object-edit`, transparent output. Edit target: a mechanically cropped first south idle frame from the v04 source, registered to the existing 64×64 native frame and enlarged with nearest sampling to 512×512 for the tool. Original v04 sources and deliveries are preserved.

## Exact prompt

Use case: precise-object-edit. Edit target: the attached pixel-art Hollow standing sprite, shown enlarged 8 times from a 64x64 native sprite. Fix ONLY the two black eye apertures on the small ivory mask inside the hood: make both apertures matching size, equally visible, gently oval, and symmetrically placed, as in a calm hollow spirit. Preserve the exact hood silhouette, head position, mask outline, cream shading, scarf, clothes, boots, stance, pixel grid and transparent padding. The face is near the upper-middle center of the sprite. Do not add a mouth, eyebrows, expressions, extra eye details or highlights. Keep the coarse native pixel grid: edit at the same apparent pixel size, no additional finer resolution details. The two eye holes should each read as approximately two native pixels wide and two native pixels high. Keep everything outside the mask unchanged. Transparent background. No text, no additional subjects.

## Delivery and integration

- Original tool delivery: `C:/Users/Adrian/.codex/generated_images/01a11fe4-0691-77d0-8912-1119eb42fdab/exec-e48c0e47-8383-4551-8808-9522841a7901.png`.
- Project source: `assets/art/world/first_footsteps_v01/sources/hollow_mask_v05.png`.
- Native atlas: `assets/art/world/first_footsteps_v01/atlases/hollow_idle_v05.png`.
- Runtime frames: `assets/art/world/first_footsteps_v01/frames/hollow_motion_v05.tres`, consumed by `scenes/hollow.tscn` in the same art package.
- `tools/prepare_fifth_polish.gd` resizes the generated delivery to the native 64×64 canvas and integrates only the mask insert at `(27,27,7,5)` in the two south cells. Every pixel outside these two small rectangles is identical to v04. Both apertures now occupy two-by-two dark pixels. Runtime head/boot stabilization and all authored torso breathing remain intact.
- Turn banners reuse the existing generated `utility.png` and `attack.png` frames; no geometric placeholder frame or additional generated UI atlas was introduced.
