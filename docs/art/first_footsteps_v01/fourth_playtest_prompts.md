# Fourth playtest art — 9 October 2026

Built-in image_gen tool. Reference: `assets/art/world/first_footsteps_v01/sources/hollow_idle_v03.png`. Original outputs preserved; new source siblings copied into the project. Transparent idle alpha retained. Native export and icon format conversion are performed by `tools/prepare_fourth_polish.gd` and the ICO conversion step. Runtime idle renderer holds the canonical head and boots while the authored torso frames breathe.

## App icon

Create one finished square app icon for Hollow Choir, a melancholy hand-painted pixel-art marsh RPG. Reference image is the existing protagonist: retain its ivory oval mask with two large simple black eye holes, pale linen hood and moss-green scarf. Tight centered head-and-shoulders portrait, cropped below scarf, extremely clear silhouette readable at 16 and 32 pixels. Dark deep-green marsh background, subtle aged bronze rim with clean thin edge. Muted ivory/moss/charcoal palette and one tiny warm amber highlight. Textured painterly pixel-art matching reference. NO text, no letters, no Godot logo, no collage. Opaque square icon, no external mockup or drop shadow.

Source: `assets/art/global/icon/sources/hollow_choir_v01.png`; game PNG and Windows ICO: `assets/art/global/icon/hollow_choir_v01.*`.

v02 (9 October 2026, Adrian's request; no new generation): `tools/prepare_icon_alpha.gd` makes the black background outside the rounded bronze frame transparent. It flood-fills near-black from the source border, so the mask's eye holes stay opaque. Alpha is the area coverage of that mask; every colour is unchanged from v01. Project settings use `hollow_choir_v02.png` / `.ico`; the v01 files are kept.

## Idle repair

Edit this exact 4x4 transparent game sprite sheet for stable breathing idle animation. Preserve 4 equal columns and 4 rows, all sixteen full-body characters, orientations and exact first-frame character designs. Each horizontal pair is one direction: row1 south/north, row2 west/east, row3 southeast/southwest, row4 northwest/northeast. Fix every SECOND sprite in each pair: its mask, eye-hole shapes, hood, head size, polish and pixel softness must match the FIRST frame exactly, and its head/feet/stance must stay at identical relative pixel coordinates. NO swaying or sideways translation, no stretching, no walking stance, no head movement, no changing facial features or eye sizes. The only change between frames is a very subtle shoulder/scarf/upper-coat breathing movement. Keep feet planted. First frames remain canonical. Preserve smooth painted pixel shading across all frames, avoid sharp black specks/fringing. Retain generous transparent gaps and true alpha background.

Source: `assets/art/world/first_footsteps_v01/sources/hollow_idle_v04.png`; registered native atlas `atlases/hollow_idle_v04.png`; runtime frames `frames/hollow_motion_v04.tres`.
