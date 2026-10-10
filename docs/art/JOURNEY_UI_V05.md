# Journey UI art — V0.5 prototype

10 October 2026. Generated with the **built-in image generation tool**, four separate calls.
Original outputs remain in `C:/Users/Adrian/.codex/generated_images/01a12413-1ee4-7a22-8d73-2a798a37e9ff/`.
Project copies are byte-identical, versioned new assets, with original alpha preserved. No Python
image editing, CLI generation or downloaded third-party imagery was used. Art is integrated for
Adrian's prototype review; this is not a final human art-acceptance claim.

All final images are saved in `assets/art/global/ui/journey_v05/`:

| Final filename | Original output filename | Actual size / mode | SHA-256 |
|---|---|---|---|
| forge_backdrop_v01.png | exec-44858e25-986f-4bcf-b6c0-dfc721468e54.png | 1536x1024 RGB | 1498cec93c711b1f7f8ebdfb04b8bc39f2a8dde4f41ae1c7bd527a1ee7f76690 |
| stillroom_backdrop_v01.png | exec-5e33ec0f-b246-43f2-93b0-5e7734cde117.png | 1536x1024 RGB | 34d62e7e13d0e599811bbc661de04011020c4551648f83f2718c8b4cd77f89d9 |
| forge_station_v01.png | exec-227e3618-7e37-4fff-84d6-7f9161e17e4e.png | 1254x1254 RGBA | 2d16019bfa29d2914b9b11b3d122bbab894217548727dd7a4a55abfd932c8d1a |
| stillroom_station_v01.png | exec-428ee53c-846d-491e-af77-e162919190b3.png | 1312x1199 RGBA | 1ae357124b2c2e11d28a3576fc4461bb17b9b0e69bc0f99372ddaad4c75a2418 |

The props contain genuine alpha (range 0–255), rather than a painted checkerboard. Backdrops are
opaque. Godot imports use lossless texture mode, no mipmaps, no premultiplication and no size
limit. Props use nearest filtering and authored display scale/offsets in Gloamstead; collision is
separate. Backdrops aspect-cover the existing station modal. Generated pixels were not resampled
or repainted on disk. The forge keeps the legacy station footprint and ID. The Stillroom gets a
separate footprint/interaction marker without regenerating terrain or moving safe anchors.

## Reproducible prompt set

These normalized design records preserve each generation's requested content and constraints;
they are not a claim to reproduce the original API text byte for byte. No reference images were
submitted. `transparent_background` was false for backdrops, true for both standalone props.

**Forge backdrop:** Landscape 1536x1024 dark folk-fantasy RPG Forge interface background for
Hollow Choir. Worn stone, soot, iron tools, restrained warm embers, anvil toward the far upper left.
Keep the central 80% dark, quiet and readable for overlaid equipment icons and information cards.
Chunky stepped pixel-art material detail, charcoal, peat brown, ivory, olive and aged brass palette.
No character, typography, UI, sockets, labels or bright magical glow.

**Stillroom backdrop:** Landscape 1536x1024 dark folk-fantasy RPG Stillroom interface background
for Hollow Choir. Shelves of dried herbs and bottles, small copper alembic toward the far upper
left, old wood and plaster. Central 80% quiet and dark for the interface. Match chunky stepped
pixel-art materials and charcoal/peat/olive/ivory/aged-brass palette. No character, text, UI,
magical slots or bright glow.

**Forge station:** Standalone anvil workstation on a genuinely transparent square canvas. An
iron anvil on a cut wooden stump, with hammer and tongs. Top-down RPG three-quarter view to match
32 px terrain and an approximately 60 px adventurer; read clearly around 64 px runtime size.
Chunky stepped dark fantasy pixel-art shapes, near-black outline, charcoal iron, worn brown wood,
small brass details. No floor, ground shadow, backdrop, text, interface or extra scenery.

**Stillroom station:** Standalone herbalist distillation table on genuine transparency. Copper
alembic, two potion bottles and bundled herbs on a worn wooden tabletop. Top-down RPG three-quarter
view for 32 px terrain, around 80x64 px runtime size. Chunky stepped dark folk-fantasy pixel art,
near-black outline, muted brown/olive/brass and small ivory cloth. No floor, shadow, text, interface,
bright glow or surrounding scene.

## Native additions and reuse

Thirteen original 48x48 SVGs extend the existing repo-native stepped item family in
`assets/art/global/ui/journey_v05/icons/`: kit, merciful_grip, hollow_echo, anvil, stillroom, lock,
save, help, empty, mending_draught, fen_water_flask, clotting_salve and focus_tincture.
`tools/build_journey_ui_icons.py` is their reproducible source. `map_track.svg` is an original
48x16 board/pebble path stamp. These are native vector assets, not raster generation substitutes.
Existing weapon/armor/material icons, Hollow idle art, ring/ring_open, frames, parchment, font and
shared inspector are reused unchanged. No new portrait or combat animation was necessary.

Runtime checks and screenshots are listed in [the presentation report](../reports/V0_5_UI_PROTOTYPE.md).
Audio reuses approved music and existing UI cues. The three earlier exploration stone SFX retain
their own manifest. This UI iteration requires no new musical delivery or new audio playback system.
