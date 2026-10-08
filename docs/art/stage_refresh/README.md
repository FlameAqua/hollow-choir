# Stage art refresh — 8 October 2026

The [canonical contract](../../design/STAGE_PRESENTATION_REFRESH.md) governs these candidates.
[Exact prompt/asset manifest](prompts_manifest.json) records the built-in imagegen prompts,
reference images, hashes, dimensions, atlas regions and displayed corpse widths. All twelve PNG
deliveries are copied into the runtime art library unchanged; generated originals remain preserved.

- Three new day images pair with the three existing night images in
  [the flat environment catalog](../../../assets/art/environments/briarfen/catalog.json).
- Nine transparent defeated poses cover every existing Briarfen enemy in
  [the regional sprite folder](../../../assets/art/enemies/briarfen/sprites).
- The existing SpriteFrames resources include one nonloop `dead` frame as well as `idle`.
  Alpha >=24 bounds plus 2 px margin choose the AtlasTexture region; that operation does not repaint,
  quantize, resize or claim artist cleanup. Bottom-centre is the common idle/dead foot anchor.
- [Departure Mono](../../../assets/art/global/fonts/README.md) replaces the active UI font.

See [actual Godot evidence](../../reports/stage_refresh/README.md). State/dead review screenshots
use artificial presentation flags; they do not demonstrate a gameplay kill or future corpse action.
Generated art remains subject to final-size artist cleanup and human readability review.
