# Character menu follow-up captures

Actual Godot Compatibility viewport renders, isolated QA data, 9 October 2026. All 1280×720,
except `inventory-1920.png` at 1920×1080. Opened for visual review; these are seeded UI fixtures.

- [Starting inventory](inventory-start.png): four starter items, ten cells, two rows of five.
- [Expanded inventory and Alt details](inventory-expanded.png): five items, fifteen cells;
  the fixture has the restoration claim and charm owned, without changing the saved loadout.
- [Actions](actions.png), [Magic](magic.png), [Skills](skills.png): current loadout facts.
- [Bell reward](bell-reward.png): the real restoration command, compact charm and +5 slots.
- [Preparation](preparation.png): real equip command, scrollable facts, no reading buttons.
- [Exploration](exploration.png): the portrait at the top right.
- [Exposed hover](exposed-hover.png): presentation-ledger exposure fixture, no sprite banner,
  pointer over its actual effect region; the existing combat dock explains it.
- [1920×1080 inventory](inventory-1920.png): the complete fixed canvas scales uniformly.

Use `tools/capture_world.gd` with `--state=inventory-start|inventory|character-actions|character-magic|
character-skills|charm-reward|bench-charm|town`. Item inspection accepts
`--inspect=Equipment_storm_salt_charm`, `--details` and `--size=1920x1080`.
Use `tools/capture_battle.gd -- --state=planning --exposed --inspect-exposed` for the combat fixture.
Always launch through `tools/qa_godot.py` with an isolated `--home` and a concrete `--out` path.
