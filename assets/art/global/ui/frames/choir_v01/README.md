# Choir frame kit v01

Reusable stepped stone/iron edges with restrained tarnished-brass corner marks. Eleven authored SVG
textures, eleven StyleBoxTexture resources and one sample Theme. Flat, opaque centres keep labels clear.
The V0.2 support follow-up integrates the panel in compact announcements and bar textures in UnitView
through ResourceBarArt. Other panel styles and the sample Theme remain optional resources.

## Contract

- `panel`, `raised`, `selected`, `enemy`: 48×48 source, 8 px nine-patch margins; content 10 px
  horizontal / 6 px vertical, matching current default panel padding. No text or bindings baked in.
- `focus`: transparent centre; overlay only, never a substitute for accessible focus ownership.
- `bar_track`: 32×12 source, margins 4/3/4/3, content inset 2 px. Minimum review height 12 px.
- `bar_track_slim`: 16×5 source, margins 3/1/3/1, for break directly beneath HP. Never use the
  12 px health rim squeezed into a 3 px bar. Keep 2 px between HP and break.
- `hp_ally`, `hp_enemy`, `resource_focus`, `resource_stagger`: 16×8 source, horizontal stretch,
  vertical margins 1 px; no decorative endcaps or arbitrary value ticks.
- Nearest filter, no mipmaps. Stretch edges/centres; do not tile ornaments across labels.
- Health colours communicate team; heart icon and exact value stay. Focus/Stagger retain their symbols.
- A fill is clipped to its actual fraction; zero means zero visible fill. A full-width rim is only track.
- Duplicate/scale StyleBox resources for enlarged content margins. Do not change global font settings
  by applying the sample Theme directly; merge styles into UITheme and retain 100–200% text scaling.
- Frame textures never determine hit areas, target geometry, timing zones, resource values or team data.
- At 40 px button height / 24 px icons, decoration remains outside essential content. No extra panels.
- Keep the existing flat style fallback if imports fail or composed contrast/readability is worse.

`manifest.json` is a delivery inventory, not a gameplay database. `theme.tres` demonstrates native
dependencies and the EnemyHealthBar, FocusBar and StaggerBar type variations for review.

The kit rim uses `#718277` for at least 3:1 nominal contrast against the raised centre; this
is a local art token and does not replace UITheme.BORDER in the active UI. Text/centre contrast is
13.45:1 and focus/raised contrast is 8.02:1. Final composed review remains required.
