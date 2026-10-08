# Claude handoff — M1.1 combat clarity

Design owner: Game Director. Engineering owner: Claude. Status: **ready for implementation**.
Full requirements: [M1.1 specification](../design/M1_1_COMBAT_CLARITY.md).
The [review](../reviews/M1_DIRECTOR_REVIEW.md) separates observed source issues from untested hypotheses.

## IMPLEMENTATION BRIEF

Make the current combat sandbox understandable before building another system. Keep BattleEngine,
its input requests, seeded resolution, existing balance and trait vocabulary. Implement in this order:

1. Shared knowledge-filtered presentation and honest preview scope; stable intent slots and selected
   action context. This fixes information leaks before art polishing.
2. A common decision dock for action/target selection, command and reaction; binding-aware labels,
   fresh-press ownership and safe focus-loss timing. Preserve ReactionRules/CommandRules.
3. Reuse the event ledger for Focus, statuses and familiar readiness; surface condition consequences.
4. Practice/Lab views using one BattleSetup. Preserve Lab capabilities; Practice resets only its explicit
   overrides and retains user difficulty/assist preferences.
5. Hook optional SpriteFrames into UnitView and the staged backdrop into Battlefield. Use shared
   presentation transforms. Final art cleanup is a separate acceptance gate.

Suggested edit surfaces: `scenes/battle/battle_scene.gd`, `scenes/sandbox/combat_sandbox.gd`,
`src/ui/ui_theme.gd`, existing battle widgets, `battle_event_player.gd`, and a small typed presentation
adapter if needed. Keep code-built UI for this pass (D-016); migration to authored scene trees has no
demonstrated player benefit. Do not rewrite component architecture to implement new spacing.

Plan approximately 6–10 engineer days after accounting for shared work, plus pixel cleanup and human
testing; stop and identify any requirement that materially exceeds this estimate. Do not substitute
the HTML study for a Godot implementation. It has fixed illustrative state and no gameplay logic.

## DATA CONTRACT

### Existing sources of truth (unchanged)

| Data | Owner / use |
|---|---|
| `BattleEngine` request + input log | Only engine advances/submits choices; preview inspection never mutates it |
| `ActionOption.legal` / reason + target IDs | Action availability; disabled actions remain readable |
| `ActionPreview` grade arrays / affinity_known | Exact underlying values; filter before any widget uses hidden-derived data |
| `IntentPreview` detail_level / allowed / target_uids / covered_by / turns_until_release | Public threat/targets/reaction legality, gated detail and redirection |
| `ResearchRules.detail_level` + revealed_affinities | Knowledge policy; no second research progression |
| `ReactionSpec`, `CommandSpec`, `BalanceConfig` | True windows, legality, assist and grade rules; never literals in labels |
| `InputBindings` + active input device | One mapping for names and glyphs; no independent binding table |
| `BattleEvent` + presenter ledgers | Visual state changes follow events, reconcile at end of batch |
| `CombatantDefinition.sprite_frames` | Optional SpriteFrames; use `idle`, safe placeholder if absent |

### Proposed presentation-only contracts

One typed adapter, exact class name chosen by engineer, supplies these meanings to all widgets:

| Field / concept | Type / requirement |
|---|---|
| actor / target identities | Existing unit IDs plus display names; duplicates get instance suffixes |
| visible action label | String; named move at UNDERSTOOD, category otherwise |
| knowledge state | Existing research enum; affinity visibility separately per target and damage type |
| preview scope | Explicit direct-hit / per-target / qualitative; never imply a computed total |
| numeric visibility | Boolean per quantity; unknown-derived fields absent, not zero or “?” plus hidden-answer styling |
| outcome qualifiers | Required grade, chance and affected target scope where available; unknown completeness suppresses guarantee |
| reaction rows | Existing enum order, actual bound key/glyph, allowed flag, modified effect and condition caveat |
| familiar readiness | Derived from existing per-round trigger event state; no copied gameplay limit |

Do not add a general expression system for UI text. If compound results cannot be predicted cheaply,
use factual effect descriptions with explicit limits; don't approximate silently. If a displayed value
depends on a hidden affinity, hide the value and every derivative (Focus bonus, break/kill, formula,
bar ghost, comparison) until learned. Public status rules remain visible.

### New art and optional resource fields

- `docs/art/briarfen_v01/manifest.json` is an **authoring manifest**, not a runtime database. Atlas
  rectangles are irregular, in source pixels, within the 1536×1024 PNG.
- `frames/{hollow,mara,bogshell,thornhound,fen_wisp}_idle.tres` are valid single-frame SpriteFrames
  candidates. Assign to existing combatant resources only when the renderer consumes them.
- `frames/bell_crow_idle.tres` is for preview. FamiliarDefinition currently has no texture field;
  if needed add optional `portrait: Texture2D` with null default and an AtlasTexture crop. It remains
  a SidePanel portrait and event accent, never a controllable unit.
- Backdrop uses `briarfen_stage.png`. Prefer an exported optional texture on Battlefield for this
  single-biome pass; no biome renderer/resource hierarchy. Existing condition cues remain independent.
- Frame anchors and desired display heights are art metadata; don't derive targeting or timing from
  frame bounds. Party source faces right, enemies left. Missing frame → placeholder, not crash.
- No save version change. Optional settings (Details toggle mode) must load absent keys safely;
  existing hold and Always preferences migrate without changing their meaning.

## STATE FLOW

```text
Practice or Lab form → validate existing BattleSetup → existing BattleScene
  → engine advances → drain/play events → reconcile displayed state
  → ACTION_SELECT: action focus → target focus where needed → commit
       Back from target → same action focus; no resource spent
  → ACTION_COMMAND: consume commit → wait for release → fresh timed input
       → submit existing grade once → event playback
  → REACTION: show attacker/targets/legal responses
       → optional readiness pause (consume start input)
       → clock begins → first allowed fresh press locks
       → result or existing no-input/auto-Brace → submit once → playback
  → outcome → factual recap → Retry same setup / Change setup
```

Details is a planning subview, not a combat turn. It cannot steal target focus through hover.
Unavailable reaction input is inert. Manual pause during timing queues until resolution; application
focus loss freezes elapsed timing and re-arms only after release. Resuming does not reset a window.
Restart frees presenters and cancels outstanding timers/tweens without submitting to an old engine.
Settings affecting an in-flight request apply at the next safe request, visibly, not midway through grading.

## ACCEPTANCE TESTS

Implement or adapt focused tests for F1-A…F3-D in the specification. Do not create tests mirroring
every style constant. Reuse the current UI/content suites and deterministic fixtures.

Required regressions: UNKNOWN knowledge cannot leak through any view; known direct previews match
resolution; AoE/multi-hit claims are qualified; first legal reaction wins; disallowed input is inert;
confirm does not enter command; pause-before does not attempt a reaction; focus loss preserves
elapsed input; restart cancels late results; event ledger never shows future Focus/statuses; defaults
don't enable simulation or write progress. Sprite fallback and atlas resources must load.

Validation commands use the retained Godot 4.7.2 environment:

```sh
source /workspace/.hollow-choir-env/activate
godot --headless --path . --import
godot --headless --path . --script res://tools/check_scripts.gd
godot --headless --path . --script res://tests/run_tests.gd
```

After focused tests and the full regression suite pass, perform visual checks at 1280×720 and 1920×1080,
100/150/200% text, keyboard/controller, four enemies, boss, no sound and reduced effects. Record actual
screenshots. Run the specification's five-player gate; do not mark fun/comprehension accepted from
headless results. No broad balance sweep is needed unless rules or data change.

## KNOWN EDGE CASES

Duplicate enemy names; enemy death/retarget; Intercept; broken/channelled units; uninterruptible
channels; conditional statuses; Focus at cap; multi-hit and AoE with mixed knowledge; tiny window
after assist/equipment modifiers; disabled Parry then valid Brace; A/X shared binding; held release
command across focus loss; input device changes during a prompt; display scale changes; log during
timing; window deactivation; restart during a feedback await; placeholder art alongside new sprites.

The current reaction widget uses a SceneTree timer for final feedback despite D-014's node-bound wait
intent. Review/correct its lifetime handling while touching it and test restart during that await.
Do not misreport this source concern as an already reproduced crash.

## NON-GOALS

No production combat changes from the Director's artifact pass. No new enemy/action/status,
affinity values, reaction grade, damage tuning, mandatory aim, turn-order redesign, prediction engine,
autopilot policy, expedition persistence, world state, save-slot UI, new tutorial battles, art-based
hit detection, bespoke per-move animation, music, localization pipeline or wholesale scene rewrite.
Animation does not determine the resolution clock. Tactician doesn't read future input. Generated
art is not declared final simply because it imports.
