# V0.2 inspection and targeting follow-up — 8 October 2026

Owner: Director/UI integrator. Canonical companion to the GDD and
[interaction contract](V02_UI_INTERACTION.md). This user-authorized follow-up supersedes persistent
stage reaction rows, numeric `!1` threat, repeated YOUR TURN/TARGET tags and automatic submission
when an explicitly targeted action has only one legal recipient.

## DESIGN INTENT

Remove repeated information, make each field legible and keep inspection from stealing navigation
or commitment. Extend the existing inspector, readouts, target picker and pixel-art vocabulary.

| Change / player purpose | Decision created or supported | Systems | Cost | Likely failure | Cheaper reuse |
|---|---|---|---|---|---|
| Remove stage reactions and turn/target words | Read the move or selected recipient without duplicated labels | IntentRail, UnitView, timeline, PreviewPanel | Low | Removing the only reaction legality cue | Preserve legality in the existing move card and active reaction UI; retain brackets |
| Named threat badge; separated unit fields | Compare danger, health, break and learned affinities | IntentReadout, UnitReadout, knowledge gates, ledger | Medium | Long labels overlap; research or future health leaks | Shared typed readout/card; no per-species UI |
| Compact rendered inspection text | Scan details without shrinking native font raster sizes | InspectionContent, theme, scroll geometry | Low/medium | Transformed text/input bounds disagree; 200% loses access | One 82% content transform, existing font and accessibility scales |
| Explicit review for a sole ally/enemy | Commit to the recipient deliberately, or cancel | ActionPicker, help, target brackets | Low | Double-submit, wasted Focus on cancel, wrong side prompt | Existing target state; no new confirmation modal |
| Wheel ownership and honest details hints | Navigate lists or expand only information that exists | ActionMenu, HoverInspector, input bindings | Low | Inspector steals list scrolling; Alt release remains stuck | Existing ScrollContainers and one inspector |
| Heart silhouette, pet marker removal, terrain effects | Recognize HP, familiar state and environment quickly | Shared heart SVG, FamiliarCard, ConditionArt, ledger | Low/medium | Heart still reads as shield; decoration hides a tell or implies targeting | Edit one existing SVG; reuse existing familiar hover and shared backdrop drawing |

## PLAYER EXPERIENCE

An enemy's stage strip shows its move, recipient and public status payload; channel indicators
remain when needed. Move inspection contains Brace/Evade/Parry legality. Creature brackets and
portrait turn order communicate selection/turn ownership without text across the sprite.

Threat reads “Light threat”, “Moderate threat”, “Heavy threat”, “Severe threat” or “No threat” in
the top-right badge. The title uses a separate row when there is insufficient horizontal room.
This is relative danger, not a damage number.

Expanded unit inspection has distinct name, type, knowledge, health, break/Focus and effects.
Damage affinities are grouped under Weakness, Resistance, Normal damage and Unknown. Normal
damage explicitly means no affinity bonus or reduction. Affinity symbols keep their names.
The declared move uses the same move card, without rebuilding a live engine intent.

The inspector renders its existing native pixel-font sizes through an 82% content transform.
The 100/150/200% accessibility preference still applies. Action buttons and timing UI retain their
control sizes. This changes presentation density rather than reducing the font resource size.

## RULES

- SINGLE_ENEMY, SINGLE_ALLY and SINGLE_OTHER_ALLY actions enter target review even with one legal
  recipient. A click on that recipient or configured Confirm submits. Back spends nothing.
- Self, group and untargeted actions retain existing behavior; no universal extra confirmation.
- A temporary prompt in the turn-order strip's center says “Pick an ally” or “Pick an enemy” only
  during target review. It stays above contextual inspection.
- Wheel over an action/supply button scrolls its list while inspection is collapsed. Expanded
  details own the wheel over their current source, per [the later polish contract](V02_PRE_PUSH_POLISH.md).
  Wheel inside inspection or over a non-scrollable inspection source scrolls the card.
- Alt in Hold mode follows actual held input and clears on focus loss. Toggle/Always settings
  retain their explicit behavior. Releasing over the card collapses the same card.
- Simple fields do not advertise advanced details. A scroll hint appears only for real overflow
  and reads “Scroll for more” or “Page Up / Down to scroll” (shortened to “Scroll” / “PgUp/PgDn” at
  enlarged text); never the unexplained word “Wheel”.
- Familiar readiness/limits remain explicit on hover. The unexplained floating readiness circle
  is removed; existing trigger feedback remains.

## UI REQUIREMENTS

Retain semantic colors and positional consistency: red enemy HP/threat/damage, lavender break,
gold knowledge/Focus/selection and cyan identity/recipient information. Unit resource fields have
separate labels and values, and text wraps rather than sharing an overflowed header sentence.
No color is the sole explanation. No extra popup is opened within the inspector.

The shared health SVG has two stepped lobes, a deep center notch and tapered pixel edges.
Flooded Ground uses sparse horizontal reflections and square-edged ground ripples in muted cyan/
slate. Spore Fog uses low broken haze and sparse olive flecks. Effects stay behind actors, on a
two-pixel grid, with slow stepped motion and no pulsing bright circles or flashes. Reduced motion
keeps a static terrain signature; missing/new conditions use a quiet ground tint.

## DATA REQUIREMENTS

UnitReadout is transient presentation data: identity, public displayed resources/life/effects,
filtered role/knowledge/affinity categories, notes and an already-displayed IntentReadout reference.
Resources/effects come from PresentationLedger. Research queries run only at stable planning points;
outside planning the card omits newly queried knowledge/affinities. No progress-save fields change.
UnitView's source-local provider returns a unit readout only for the body; individual HP/break/status
hit regions retain their own small explanations. InspectionContent reports transformed content
height to scrolling and keeps local/global pointer transforms consistent.

ConditionArt is decorative presentation selected by existing condition IDs. It consumes announced
ledger conditions and never changes an effect, target, timing window, stat or terrain rule.

## BALANCE PARAMETERS

No damage, cost, health, break, AI, knowledge threshold or command/reaction timing changes.
82% inspection content scale, existing 140 ms exit grace/65 ms replacement settle and 64px menu
wheel increments are presentation constants. Explicit recipient review costs no game resource.

## EDGE CASES

Long known move names wrap to a separate row below the threat badge. Multiple recipients retain
per-target damage. Unknown damage stays `?`; hidden affinities stay Unknown. Defeated units show
Defeated, without new corpse interactions. Changing a target or cancelling never spends resources.
Alt release over the popup, while crossing a gap, or after focus loss must collapse Hold mode.
Toggle/Always must not be silently treated as Hold. Overflowing action buttons remain scrollable.
Environment removal removes its decoration through the ledger; reduced motion freezes decoration.

## ACCESSIBILITY REQUIREMENTS

Keep remapping, keyboard/gamepad target confirmation, Back, focus scrolling and 100/150/200% text.
Labels duplicate icons/colors. No flashing or motion is required to recognize a condition. Keep
original native font sizes and nearest texture sampling; compare transformed text on an actual
display. Physical controller, color-vision and human comfort checks remain human acceptance.

## ACCEPTANCE TESTS

1. Stage strips have no persistent reaction row. Hovered move card still explains all three
   reactions, shows a named threat badge within bounds, and retains the displayed intent reference.
2. A real Intercept with one legal ally enters review and shows “Pick an ally”; Back leaves Focus
   and the action log unchanged. Clicking the ally submits once and clears the prompt.
3. With inspection collapsed, wheel over real buttons in a constrained action dock scrolls the action list. Simple HP
   inspection contains no Alt or Wheel hint. Long inspection still scrolls inside its own card.
4. Release Alt while over the source and inside the popup: expanded state clears. Native font
   raster sizes remain unchanged under the compact transform.
5. Resolve engine HP/research ahead of presentation: UnitReadout retains ledger HP and omits
   newly queried affinities outside planning. Inspect in planning reveals the proper categories.
6. Render standard/enlarged known and unknown enemy/move cards, a single-target review and both
   environmental effects. Hearts read as hearts; no pet circle or repeated turn/target labels.
7. Existing full engine, presentation-ordering, timing and accessibility regressions pass.

Pillar review: READ improves through stable fields and less repeated text; REACT keeps legality in
the move/timing UI; ADAPT and EXPERIMENT keep all filtered previews and choices. AFFECT THE WORLD
gains no new rule in this UI pass. Bespoke enemy UI and new environment mechanics are rejected.
