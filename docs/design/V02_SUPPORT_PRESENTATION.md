# V0.2 support cards, familiar art and condition announcements

V0.5 follow-up: [journey/station UI](V05_UI_PROTOTYPE.md) reuses the shared inspection card for
items, recipes, fittings, potions and Character facts. Compact icons, Alt details, pinning and
scroll ownership stay shared; station background and socket diagrams do not create combat rules.
Bottom-right save/pickup cards are a separate passive presentation queue, with reduced motion.

8 October 2026. Director/UI integration follow-up, authorized by Adrian's action-card screenshots.
This supplements [the interaction contract](V02_UI_INTERACTION.md) and
[inspection follow-up](V02_UI_FOLLOWUP.md). Combat rules and content balance are unchanged.

## DESIGN INTENT

Make support actions as readable as enemy inspection, explain where battlefield information lives,
and replace the remaining equipped familiar placeholder using the existing art and UI systems.

| Player-facing purpose | Decision supported | Interacting systems | Implementation cost | Likely failure | Cheaper reuse adopted |
|---|---|---|---|---|---|
| Named support effects instead of an unexplained dash | Compare protection, healing and Focus before committing | ActionReadout, RuleNotes, PreviewPanel, inspector, item slots | Low/medium | Missing authored rules; misleading recipient or guaranteed conditional effect | Extend the shared action card and effect data, rather than individual Guard/potion widgets |
| Cinder Pup art, with a stable footing | Recognize the equipped familiar and inspect its existing trigger | FamiliarDefinition, FamiliarCard, art lookup | Low plus one generated asset | Stretching, transparent padding, accidental new pet mechanics | One portrait assignment and the same aspect-fit slot for both familiars |
| Compact condition card docks to its header icon | Locate and revisit the active terrain rule | Banner, ConditionRibbon, event player, presentation ledger | Medium | Removed/replaced icon, motion discomfort, duplicated intro, future-state leak | Reuse the banner, ledger and existing header buttons; no notification framework |
| Textured HP and break tracks plus beveled heart | Judge health, allegiance and break progress quickly | UnitView, shared frame kit, icon map, ledger | Low/medium | Ornamental fill at zero; bar overlap; moved creature baseline | Existing nine-patch textures and one shared bar painter |

## PLAYER EXPERIENCE

Guard shows its recipient, Guarding and +1 Focus. Expanded inspection includes the authored 40%
reduction and duration. Intercept shows Cover ally and Shielding, identifying self effects separately
from the protected target. Focus Tincture shows +4 Focus, with a recipient-cap explanation. Healing
keeps its heart/heal symbol and actual previewed value. No blank damage dash stands in for support.

At combat start, conditions appear once as compact framed cards, hold briefly, then shrink toward
their header icon. That icon remains available for immediate hover and keyboard inspection.

## RULES

- Always include the authored action/item description in expanded inspection. Omit empty headings.
- Shared support facts come from direct action effects. Flat Focus amounts may be displayed; complex
  scaling gets a named effect rather than an invented number. Conditions/chance use “May” wording.
- Buff names/descriptions come from BuffDefinition; recipients come from EffectTarget. Support
  fields do not evaluate combat formulas or consume RNG. Unknown effects retain authored prose.
- Cost/charges remain top-right; targets, payloads and outcomes occupy separate rows. Support
  effects use icon/name and recipient fields. Individual fields explain themselves within the
  existing inspector footer. Expanded analysis retains the existing scroll container.
- CONDITION_ADDED advances the ledger, refreshes the header, then announces that condition. Never
  pull later conditions from the engine to populate an earlier card. Resolve docking by condition ID.
- Condition summaries are no longer duplicated in the opening encounter banner.
- A missing/removed icon falls back to a stationary fade. Freeing the battle frees its tweens.
- HP uses a 12 px textured track; enemy break uses a 5 px track, 2 px below it. Break has no numeric
  stage label. Exact values remain inspectable. Fill stays inside the rim; zero means no visible fill.
- Familiar art preserves proportions and anchors to the existing slot floor. Art-off mode retains
  the intentional procedural fallback. The existing familiar trigger pulse and rules are unchanged.

## UI REQUIREMENTS

Use the existing native pixel font and 82% inspection/announcement content rendering, retaining the
user's accessibility text scale. Gold identifies Focus; green healing; red enemy health/damage;
lavender break; cyan recipients. Names/icons/position carry meaning alongside color. Use the global
Choir frame kit: stepped iron/stone with restrained brass corners, nearest filtering, no mipmaps.
The new slim track belongs beside the shared bar resources, not in a regional or per-enemy folder.
The lower action preview uses the same 82% canvas transform, with matching field-hit coordinates.
Terrain-caused status feedback uses compact rendering; floating text stays within the battlefield
instead of rising into the header. Announcements layer above floating combat feedback.

## DATA REQUIREMENTS

ActionReadout.support_effects is transient filtered presentation data: SupportNote has icon, label,
recipient, explanation and color. The adapter describes a deliberately narrow set of public support
effects; it is not a second resolver. Cinder Pup uses the existing FamiliarDefinition.portrait field,
with a clipped AtlasTexture over the preserved generated source. Condition buttons carry their
condition_id. There is no new save schema, effect type, catalog or audio requirement.

## BALANCE PARAMETERS

No damage, Focus, duration, targeting, research or timing-window changes. Presentation defaults:
condition hold 1.0 s; fade-in 0.15 s; flight 0.32 s with final 0.10 s fade after 0.24 s; stationary
fade 0.20 s. Condition timings scale with Combat Speed, never reaction/command windows. Generic
round/result holds retain their existing caller values.

## EDGE CASES

Single legal recipients still require explicit target review. Zero healing must not invent an
outcome. Conditional/chance effects must not promise an unconditional value. Multi-target effects
are not summed. Focus cap explanations refer to the recipient, not an unrelated actor. At enlarged
text sizes, details may scroll; Actions and Supplies continue owning their own list wheel input.
Refresh/replacement must remove old condition buttons immediately before resolving a new destination.

## ACCESSIBILITY REQUIREMENTS

Reduced motion uses no flight or compression: a stationary card plus steady header border, then
fade. No flashing arrival effect. Keyboard focus and immediate hover remain on each header icon.
Retain Hold/Toggle/Always inspection behavior, text scaling, allegiance symbols, exact health and
inspectable break values. Do not shrink native font raster sizes to squeeze labels into a row.

## ACCEPTANCE TESTS

- Guard expanded text includes 40% reduction, duration and +1 Focus, without empty Details heading.
- Intercept exposes cover plus shielding; Focus Tincture exposes +4 Focus, with no green dash.
- Support field hit regions fit their card and preserve individual explanations.
- Both party characters, nine enemies and both familiars have production art references.
- Familiar proportions are unchanged and paws share a stable baseline.
- Condition arrival targets the matching ID; reduced motion never changes card position/scale;
  missing destinations safely fade; the steady header highlight clears afterward.
- Zero/half/full bars have honest fills; break remains narrow and directly beneath HP.
- Existing full input, scrolling, knowledge/ledger and completed-battle tests continue passing.
- Terrain feedback stays below the header even at 200%; the lower action preview retains whole
  Guarding and +1 Focus labels at that scale without changing native font raster sizes.

Pillar review: READ improves through named outcomes and textured tracks. REACT retains existing
timing and legality information. ADAPT and EXPERIMENT retain deliberate target/cost decisions.
AFFECT THE WORLD is served by discoverable existing terrain rules; no new world interactions are added.
