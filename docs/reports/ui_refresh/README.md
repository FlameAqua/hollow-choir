# Combat UI integration review — 8 October 2026

Implemented in the existing working tree at the user's request. This record covers the UI/art
integration pass; unrelated uncommitted engine work was already present and was preserved.
Authority: [canonical UI contract](../../design/ICON_FIRST_COMBAT_UI.md),
[art library](../../../assets/art/README.md), and
[UI ownership/handoff](../../briefs/ICON_FIRST_UI_INTEGRATION.md).

## Verification

- Godot 4.7.2: **172 scripts checked, zero failed**.
- Regression suite: **142 tests passed, zero failed, 928 assertions**. Six new icon-UI tests cover
  immediate hover/gap settling, actual stage hover and keyboard supply focus, knowledge/legality,
  full-size four-enemy casts, disjoint wide-enemy targets, potion charge use, native art loading,
  and visual/reaction-rule window boundary parity.
- All resource paths under `data`, `scenes` and `assets/art` resolve. All semantic textures and
  the bundled pixel font load. Native CombatIconMap explicitly references 48 combat + 8 navigation glyphs.
- The six v01 individual PNG exports compare pixel-for-pixel with their original source rectangles.
  Original source art is retained; no repaint, quantisation or alpha cleanup is claimed.
- Whitespace validation passes. Deliberate invalid-save fixtures emit their expected diagnostics;
  the test runner reports zero unexpected errors. Editor preference safe-save warnings are confined
  to the sandboxed editor settings; runtime/script/resource checks complete.

Commands from the repository root (using the local Godot executable):

```text
godot --headless --path . --script res://tools/check_scripts.gd
godot --headless --path . --script res://tests/run_tests.gd
godot --path . --rendering-method gl_compatibility --script res://tools/capture_battle.gd -- --state=planning --reduced --out=res://docs/reports/ui_refresh/planning.png
```

Capture arguments are recorded in [captures.json](captures.json). These are actual Godot viewport
captures at 1280×720, seed 3 and reduced effects. The review harness answers intervening inputs and
holds the selected command/reaction near impact for inspection; this does not change interactive rules
or establish human timing performance. A faster enemy can legitimately act before the first party request.

## Runtime views

| View | Evidence |
|---|---|
| Four mixed enemies, normal text | [Planning](planning.png) |
| Enlarged text / Spore Fog | [150%](planning_150.png), [200%](planning_200.png) |
| Existing elite and boss | [Bramblejaw / Mirebell Cantor](elite_boss.png) |
| Target detail and red enemy framing | [Selected target](target.png) |
| Four duplicates with enlarged numbers | [200% target selection](target_200.png) |
| Actual legal reaction windows | [Standard](reaction.png), [200%](reaction_200.png) |
| Attack input framing / beat numbers | [Attack](attack.png) |
| Missing actor artwork fallback | [Art disabled](no_art.png) |

## Design-pillar review

**READ:** Full-size enemy bodies, compact team-colored stats, portraits, stable duplicate numbers,
condition icons and immediate detail replace repeated panels/prose. Wide artwork cannot enlarge a
neighboring mouse target. Functional checks pass; fresh-player symbol recognition remains unproven.

**REACT:** Real windows drive arcs, impact meter and NOW labels. Crossed-out reactions remain inert;
the first allowed fresh press locks. Existing graders/latches/focus-loss/pause semantics are retained.
Enlarged timed cards can cover decorative rings; the same horizontal meter and legal choices remain.

**ADAPT:** Public targets, statuses, channels, conditions and reaction legality remain inspectable;
unknown move families/affinities stay hidden. Selected targets pin their detail without requiring hover.

**EXPERIMENT:** Flat action/supply controls use the same ActionOption, targets, Focus costs and charges.
Actions sharing an icon keep names. No technique, potion or familiar behavior was added or rebalanced.

**AFFECT THE WORLD:** Deferred by the current milestone. This UI pass adds no world or persistence system.

## Remaining acceptance

Human READ/REACT sessions, physical controller usability, grayscale/icon comprehension and final pixel-art
cleanup remain open. Generated sprites still retain high-resolution detail and alpha residue. Cinder Pup
currently uses its procedural fallback. Shared icon families deliberately repeat; full names/rules are
available through focus/inspection. Enlarged action grids scroll rather than shrinking essential text.

These are explicit limits of automated and visual review, not a claim that the human milestone passed.
