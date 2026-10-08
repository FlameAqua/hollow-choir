> **Superseded integration status, 8 October:** sprites and UI lookup are now integrated.
> Current ownership, resource paths, layout, font and acceptance are in
> [the UI handoff](ICON_FIRST_UI_INTEGRATION.md). The remaining text is the original art brief/provenance.

# Briarfen v0.2 — bounded art handoff

Game Director · 8 October 2026

## IMPLEMENTATION BRIEF

Use the [canonical style guide](../../assets/art/STYLE_GUIDE.md),
[pack manifest](../../docs/art/briarfen_v02/manifest.json) and
[review gallery](../../docs/art/briarfen_v02/review.html). This pack extends the six already-defined
enemies without adding combat content. Generated art is a candidate: preserve the source files and
complete final-size pixel/alpha cleanup before shipping approval.

The working tree inspected for this request contains UnitView support for optional `sprite_frames`,
`display_height` and `faces_left`, plus existing v0.1 data assignments. Six v0.2 SpriteFrames are bound
through existing enemy data only; no production GDScript is supplied by this art pass. Verify against
the actual merge target; do not implement a second renderer if the M1.1 work is already present.

Add one optional presentation texture lookup for the combat UI. Prefer a compact shared mapping over
one registry/widget per family. Use the manifest's textures as candidates and retain IconPainter as
fallback. Consume it from status/buff readouts, action rows and the intent/reaction surfaces. Do not
change the combat definitions, enum vocabulary or resolver to accommodate art.

Player purpose: recognise a current actor/effect/action. Decision: identify whose threat to answer and
which existing action or defense to choose. Systems: optional SpriteFrames, UnitView, event ledger,
action/readout presenters, knowledge policy, IconPainter and timing widgets. Cost: low data binding;
low/medium shared UI hookup; medium/high final art cleanup and human readability review. Main failure:
clipped/oversized art, status ambiguity, a hidden move revealed by its icon, stale event state or a
second impact cue. Cheaper alternative: keep procedural symbols wherever candidates read worse and
reuse the current opaque panels and generic event motion. No bespoke animation is justified here.

## DATA CONTRACT

- Existing `CombatantDefinition.sprite_frames` accepts the supplied `frames/<enemy>_idle.tres`.
  Each has one `idle` frame, existing display-height/facing metadata and an explicit measured region.
  Review source dimensions are not the final 64×64 / 96×96 production cells.
- `manifest.json` is an art/presentation mapping, not an engine or save schema. `sprites` records
  identity, native facing, region, anchor, provisional height and assignment. `atlases` records measured
  regions and `AtlasTexture` resources. `mappings` names current IDs/enum values and shared symbols.
- Status lookup uses the existing StatusId value. Buff/action lookup uses stable definition IDs.
  Intent lookup uses IntentCategory; reactions use ReactionType. Missing/unknown key uses the current
  procedural symbol and current text, without a runtime error.
- Enemy move-family mappings are available only after the current presenter says the move is known.
  At UNKNOWN/OBSERVED/STUDIED use the public intent-category symbol. Never use a secret move's damage
  family to choose its early icon or accessible label. Status payloads remain public per M1.1.
- Keep duration, charges, instance names, channel activations, scope, cost, target, bindings and reaction
  legality live. No labels or key glyphs are baked into the textures. Broken belongs to Stagger UI.
- No renderer may infer rule values from an icon. A category icon is not a declaration of legal defense,
  interruptibility or damage affinity. Conditions retain their descriptions and Battlefield symbol.

## STATE FLOW

Load existing content → optional enemy idle resource or silhouette fallback → existing stable stage
slot/feet anchor → generic event transforms driven by the current playback ledger.

Current action/effect/intent readout → apply existing knowledge visibility → choose shared texture or
procedural fallback → draw live name/numbers/legality → update when its event is presented → reconcile
at batch end. A cleansed/expired effect cannot retain an icon. Restart cancels prior presentation work.
Art adds no battle phase, input ownership transition, reaction window or save migration.

Source candidate → file/resource QA → final-size artist cleanup → composed-UI contrast/readability
review → existing M1.1 fresh-player gate. File validation does not advance the last two gates.

## ACCEPTANCE TESTS

Use ART-01–ART-07 in the style guide and the existing M1.1 regression/human protocol. Specifically:

1. Import all new PNGs losslessly; load every SpriteFrames/AtlasTexture and all six bound definitions.
   Confirm exact regions, one idle frame, left-facing enemies and no missing references.
2. In Training Yard, Rot Grove, Mire Shrine, Bramble Den and the Cantor encounter, check actual runtime
   actor recognition, feet placement, four-enemy fit and boss overlap. Use existing presets only.
3. Check every current status/buff/action/move mapping, missing-texture fallback and removal on its
   actual event. Compare final batch display with engine state; do not introduce early state leaks.
4. At UNKNOWN, swapping actions with the same public category never reveals their hidden family/name.
   Inspect/UNDERSTOOD unlocks only the current permitted information. Public payload/reaction cues stay.
5. Check 24/32 px, grayscale, pale/dark/stage backdrops, sound off, reduced effects, keyboard/controller
   focus and 150%/200% text layouts. Record failures rather than claiming the source sheet proves them.
6. Same setup/seed/inputs with art on/off yields the same targets, damage, statuses, Focus, Stagger,
   timing and outcome. Sprite bounds do not redefine the existing selection hit area.

## KNOWN EDGE CASES

Actual [four-enemy capture](../../docs/art/briarfen_v02/runtime_mixed_cast.png) exposes an unresolved
layout constraint: the 2×2 intent rail leaves roughly 50–60 px of enemy body height at 1280×720.
Detailed candidate silhouettes become tiny, and four-enemy HP/Stagger labels crowd each other.
Increasing `display_height` cannot fix the shared vertical shrink. Address this inside the existing
M1.1 layout/readout work, preserving essential text and stable input/target slots. Do not approve
ART-02 or F1-A from these captures. The [two-enemy elite/boss view](../../docs/art/briarfen_v02/runtime_elite_boss.png)
has substantially more readable bodies; it does not prove the four-enemy case is solved.

Sources retain more colours and partial alpha than final pixel targets. Low-alpha edge residue can
survive rectangular clipping; `filter_clip` does not clean it. Atlas layout is measured, not the
requested 1024×1024 grid. Some texture silhouettes need further simplification at 24 px.

Duplicate enemies intentionally share artwork. Sporecaller's three caps are one unit. Bramblejaw
shares Thornhound anatomy. Cantor's bell must remain readable without widening the enemy hit area.
Rooted/effigy actors still use the existing event motion; avoid suggesting new positioning.

Guarding, Shielding, Shelled and Taking Cover differ; readable text remains necessary. Shock status
and Storm damage are separate concepts. Broken is not a status, and field conditions are not silently
applied statuses. Invalid reactions remain labelled and inert. Active rendering work in this checkout
is uncommitted and belongs to its author; this brief does not certify its tests or human acceptance.

## NON-GOALS

No new enemies, familiar, attacks, statuses, buffs, encounter, phase, damage type, progression, world
state, save field, balance tuning, secret telegraph, new icon-specific rules, full animation library,
bespoke per-move VFX, shader or art-driven timing. No replacement of existing v0.1 sources, ornate
panel skin, font acquisition, procedural-icon removal or declaration that M1.1 has passed.
