# Briarfen alternatives and shared frame art

Director addendum · 8 October 2026. Extends the canonical art guide and icon-first UI contract.

**Latest user revision:** [Stage presentation refresh](STAGE_PRESENTATION_REFRESH.md) supersedes this
pass's staging/font/naming requirements where they disagree. Runtime backgrounds are now six flat,
numbered day/night PNGs; night 1 remains default. Departure Mono uses 22/33/44 px. The title uses the
shared frame family; combat frame textures remain staged and compact HP/break tracks stay code-drawn.
The remainder records the original asset-pass scope and acceptance rationale.

## DESIGN INTENT

Vary the existing marsh setting and give reused controls a deliberate pixel-material edge while
preserving actor recognition, quiet text fields and honest resource values. The user authorizes this
bounded frame kit despite the older blanket hold on ornate panel skins. No new context boxes return.

| Feature | Player-facing purpose | Decision clarified | Systems | Cost | Failure / exploit | Cheaper reuse |
|---|---|---|---|---|---|---|
| Sunken Bell Causeway / Root Hollow | Give repeated existing fights distinct scenery | Locate actors and recognize regional atmosphere; no terrain choice | Existing Texture2D backdrop/crop, condition tint, actor lanes | Two images plus optional future assignment | Bright details hide actors; scenery falsely implies cover or hazards | Same Battlefield renderer; no parallax, scene scripts or encounter-specific logic |
| Stepped frame family | Separate actions, supplies and detail through material hierarchy | Recognize selected/focused/inspected control | Existing Theme, panels, focus and scaling | Ten small native textures/styles; shared later hookup | New decoration recreates clutter or consumes text margin | One nine-patch family for existing boxes, no bespoke frame per mechanic |
| Resource track/fills | Make actual remaining resources easier to scan | Compare HP, Focus and Stagger | Existing numeric values, team symbols and draw path | Four fill colours and one track | Endcaps exaggerate low HP; track looks filled at zero | Same geometry, semantic colour and live numbers |

## PLAYER EXPERIENCE

The marsh has several recognizable places, while combatants remain the strongest foreground shapes.
Frames carry a worn stone/iron and tarnished-brass vocabulary. Team colour and a heart distinguish
enemy HP; gold focus highlights identify current interaction without relying on ornament alone.

## RULES

- Backdrops are decorative alternatives for existing fights. Architecture, water and roots create no
  cover, hazards, movement, condition, faction alignment or new encounter.
- Preserve dark open actor lanes and low-contrast footing. Use the existing 0.62 vertical crop focus;
  no special camera adjustment or actor shrinking to accommodate a particular painting.
- Opaque panel centres stay flat. Keep small ornaments in stepped corners, not under text or icons.
- Existing panels alone receive frames. Enemy intent/stat strips remain unboxed.
- Gold focus/selection and red opponent accents retain their live semantic source. Texture names never
  determine allegiance, target legality or hidden move identity.
- Bars clip fills to actual values; zero has zero fill. Keep heart/Focus/Stagger symbols and values.
- Current defaults and production UI remain unchanged in this parallel asset pass. Native kit and
  review scenes can be assigned later without new architecture. Flat fallback remains acceptable.

## UI REQUIREMENTS

Use nearest filtering, source nine-patch/content margins from the kit manifest, 40 px minimum
interactive height and existing 18/16 px typography. At 150/200%, scale content margins deliberately;
never apply the sample Theme over current accessibility settings. Focus texture is an overlay with a
transparent centre. Bars target at least 12 px track height; avoid ornament at tiny intent strips.

## DATA REQUIREMENTS

Alternative catalog records stable IDs, exact source dimensions/hash, reference/hash, tool, prompt
record, intended crop, decorative status and pending runtime assignment. Generated PNGs are preserved
unchanged; imported candidates are not claimed to be final pixel-cleaned exports. Frame manifest
records all texture/style paths and margins. Native dependencies are explicit, not dynamic directory
scans. Review scenes/captures are separate from runtime assignment.

## BALANCE PARAMETERS

None. No HP/Stagger/Focus numbers, timing windows, hit areas, target geometry, conditions or encounter
selection change. Decoration must fit existing layout and may be omitted where it reads worse.

## EDGE CASES

Four enemies, large sprites, duplicate actors, bright/pale clothing, conditions, 200% text and missing
art must remain readable. A backdrop is a single texture, not layered scenery. Focus cannot double
border thickness enough to hide a binding. Fill edge/corner pixels must not survive an empty value.
Godot import success cannot establish artistic quality or final composed contrast.

## ACCESSIBILITY REQUIREMENTS

Retain symbols, exact values, focus ownership, hover/keyboard detail and red enemy cues alongside colour.
No animation, flashing or sound is required by the kit. Keep the current reduced-effects and art-off
fallback. Check final composed text at 4.5:1 and essential boundaries at 3:1 before human approval.

## ACCEPTANCE TESTS

ENV-01: Both PNGs resolve, match catalog hashes/dimensions and reference provenance. Runtime default
remains unchanged. No painted UI/actors or implied mechanical markers.

ENV-02: Actual Godot stage captures show four mixed enemies and the existing party without extra
shrinking, special camera work or actor-plane obstruction. Inspect condition-tinted and enlarged-text
compositions before assigning alternatives to encounters. Human art approval remains pending.

FRAME-01: Ten textures/styles and sample Theme load in Godot. Render native nine-patch examples at
normal control sizes. No stretched corners, repeated ornaments or grain under labels.

FRAME-02: Empty/partial/full allied HP, enemy HP, Focus and Stagger render correctly. Focus overlay
centre is transparent. Later runtime assignment preserves exact resource semantics and mouse targets.

FRAME-03: Current icon-first regressions and enlarged/focused views remain required on integration.
Native review captures prove resource rendering only, not combat assignment or a passed human gate.
