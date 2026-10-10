# Equipment and effect icons v01

9 October 2026 · original Codex-authored repo-native SVGs extending the existing UI icon family.
All live in `assets/art/global/ui/items/`, with transparent 32×32 integer viewBoxes and stepped
paths, worn ivory/brass, peat/olive and muted cyan. No external images, generative bitmap tool,
third-party reference or embedded font was used. Default SVG imports are lossless, no mipmaps;
the UI inherits nearest filtering. Review at 32/48 px and on the uniformly scaled canvas.

| Asset | Purpose |
|---|---|
| `pilgrims_edge_v01.svg` | Sword; `WeaponDefinition.icon` |
| `mire_maul_v01.svg` | Maul; `WeaponDefinition.icon` |
| `reedbow_v01.svg` | Bow; `WeaponDefinition.icon` |
| `pilgrims_coat_v01.svg` | Garb; `ArmorDefinition.icon` |
| `storm_salt_charm_v01.svg` | Cloth/crystal charm; `ArmorDefinition.icon` |
| `satchel_v01.svg` | Permanent equipment-slot reward |
| `exposed_v01.svg` | Exposed weak-point effect; `CombatIcons.texture("state_exposed")` |

Unknown equipment keeps the earlier tied-parcel fallback. The exploration portrait reuses the
existing `hollow_head` texture. Authored battle/standing art, creature sprites and material
textures are preserved. Equipment icons are presentation data and never change combat identity.
