# V0.5 character-menu atlas captures

9 October 2026 · real game viewports · Compatibility renderer / Dummy audio

These isolated fixtures render the existing atlas frames in the actual character menu. They seed
presentation state; they do not constitute a human playthrough or listening/controller acceptance.
The earlier V0.5A captures remain historical evidence.

| Capture | Visible state |
|---|---|
| [Starting inventory](inventory-start.png) | Four starter items, ten slots in two rows of five |
| [Expanded inventory](inventory.png) | Ingredient strips, five owned items, fifteen slots, charm inspection |
| [Actions](actions.png) | Dark rows and gold keyboard focus with shared inspection |
| [Magic](magic.png) | Spell row and contextual information |
| [Skills](skills.png) | Weapon mastery and equipped passives |
| [1920×1080 inventory](inventory-1920.png) | Expanded inventory with Alt details at the larger preset |
| [Title](title.png) | Application version v0.5.0 |

World captures use `tools/capture_world.gd` with `--state=inventory-start`, `inventory`,
`character-actions`, `character-magic` or `character-skills`. The charm is focused with
`--inspect=Equipment_storm_salt_charm`; the larger capture also uses `--details --size=1920x1080`.
Title uses `tools/capture_battle.gd -- --state=title`. Every capture runs through the isolated
QA launcher with `--hidden --rendering-method gl_compatibility --audio-driver Dummy`.
