# Salvage icons v01

9 October 2026 · Codex-authored native SVG extension of the existing world/UI icon family

| Content ID | Runtime asset | Shape and color |
|---|---|---|
| `bog_iron` | `assets/art/global/ui/materials/bog_iron_v01.svg` | Two broad peat-iron lumps; rust/brass faces, olive flecks |
| `storm_salt` | `assets/art/global/ui/materials/storm_salt_v01.svg` | Tall stepped crystal cluster; ivory/cyan planes |
| Generic item fallback | `assets/art/global/ui/materials/parcel_v01.svg` | Tied cloth parcel, neutral ivory/olive; no potion silhouette |

Original code-drawn vector artwork by Codex for Hollow Choir. No downloaded image, generated
painting, raster reduction, third-party source or external font is embedded. All have a 32×32
viewBox, transparent background, stepped integer paths and a warm dark contour; intended review
sizes are 32 and 44 px. SVG raster imports use the existing lossless/no-mipmap convention and
the game's nearest-filtered UI. `MaterialDefinition.icon` owns the resource reference; reward
and inventory widgets use only the supplied `icon_path`. Missing paths use the neutral parcel.

Names and quantities remain live 22 px text, never painted into icons. Broad lumps and upright
crystals distinguish the pair independently of color. The generic parcel also
serves equipment without authored icons, including the charm; no claim of new charm art.
Rendered inventory/victory fixtures are in `docs/reports/v0_5a_presentation/`.
Final human small-size/art acceptance remains open. No optional new reward/equip SFX was produced;
successful equipment saves reuse AudioManager's UI-confirm cue.
