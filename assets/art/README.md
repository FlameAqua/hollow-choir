# Art library

Runtime assets are organised by purpose. Region assets live under their region; reusable UI,
party members, familiars and fonts live in `global`. Content uses stable IDs and optional
SpriteFrames; paths and decorative pixel bounds never determine combat rules.

```text
enemies/briarfen/{sprites,frames}/       nine existing enemies, idle and dead poses
environments/briarfen/                 three numbered day/night pairs, no nested runtime art
global/characters/{sprites,frames}/    Hollow and Mara
global/familiars/{sprites,frames,portraits}/
global/ui/combat/{atlases,icons}/       48 reusable combat glyphs
global/ui/combat/icon_map.tres          semantic presentation mappings
global/ui/navigation/                  pixel geometry: toolbar and stat symbols
global/fonts/                          active Departure Mono and OFL; historical Pixelify
sources/briarfen/v01/                  unchanged original cast atlas (excluded from imports)
world/first_footsteps_v01/              exploration candidate atlases, SpriteFrames and presentation scenes
```

The old `briarfen_v01` and `briarfen_v02` generation batches are provenance records in
[`docs/art`](../../docs/art), not competing runtime folders. The v01 cast now has six lossless,
individually packaged PNGs and the same one-frame `idle` resource contract as v02. The original
atlas remains available for provenance; it is no longer required by the renderer.

Read [STYLE_GUIDE.md](STYLE_GUIDE.md) and the
[combat UI contract](../../docs/design/ICON_FIRST_COMBAT_UI.md) before extending the library.
Use [path_migration.json](../../docs/art/path_migration.json) to resolve historical pack paths.
Generated artwork remains candidate art pending final pixel cleanup and human review.

## Additional environment/frame deliveries

- [Briarfen day/night pairs](environments/briarfen/README.md): original marsh, bell causeway and root hollow.
- [Shared frame/bar kit](global/ui/frames/choir_v01/README.md): native SVG/nine-patch resources and sample Theme.
- [Direction and acceptance](../../docs/design/ENVIRONMENT_FRAME_ART.md).

The latest [stage refresh](../../docs/design/STAGE_PRESENTATION_REFRESH.md) integrates defeated poses,
font, title frames and compact combat bars. Night 1 remains the default; the other five backgrounds
are available for explicit assignment. The support follow-up now integrates the shared health/break
tracks and compact announcement panel; remaining frame styles stay optional. Cinder Pup fills the
last equipped creature art gap; see [its provenance/prompt](../../docs/art/CINDER_PUP_V01.md).
Source prompts and art data for the earlier stage refresh are in
[the manifest](../../docs/art/stage_refresh/prompts_manifest.json).

[First Footsteps](world/first_footsteps_v01/README.md) adds top-down exploration art while Claude
builds V0.4. Its sources/provenance, generated-candidate status and isolated art workbench are separate
from combat assets and the production world host.
