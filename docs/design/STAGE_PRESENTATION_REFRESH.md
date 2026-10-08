# Stage presentation refresh

Canonical Director/UI integration addendum · 8 October 2026. Incorporated by the GDD.
This latest user request supersedes earlier font sizes, idle-only art limits and background naming
in the icon-first UI/art documents. Combat rules, knowledge gates and the human M1.1 gate remain.

## DESIGN INTENT

Make the existing combat easier to read and the marsh feel like a place the actors occupy. Preserve
the pixel vocabulary, full-size silhouettes and one reusable presentation path across the whole cast.

| Feature | Player-facing purpose | Decision clarified | Interacting systems | Cost | Failure / exploit | Cheaper reuse selected |
|---|---|---|---|---|---|---|
| Three paired day/night backgrounds | Vary the marsh without hiding the fighting plane | Find actors; no new time/weather choice | Existing backdrop, crop, condition tint | Three new images; rename/catalog existing three | Painted ledges imply rules; bright details swallow actors; lexical sorting misorders 10 | One renderer, shared crop and footing; no new encounters, clock or cycling system |
| Clearer font and title screen | Read names, G/5 and entry actions immediately | Enter combat sandbox, adjust settings or quit | UITheme, existing menu navigation, shared frames | One licensed font; one menu layout; enlarged-text repairs | Blurred fractional glyphs, clipped prompts, decorative controls with no function | Bundled Departure Mono; existing controls/scrolling; no new menu state or expedition button |
| Thin break bar directly below HP | Compare remaining HP and break progress without a second text row | Damage, interrupt or exploit a break | UnitView, ledger, immediate inspector, stable stage lanes | Shared draw/layout change | Zero fill looks nonzero; status overflow; art moves when selected | Same values and inspector; 6 px HP and 3 px break tracks, no persistent break number |
| Broken and exposed markers | Distinguish disabled enemies from attackable weak points | Exploit the existing opening | Existing broken/weak_point ledger flags | Shared static marks and labels | Flash-only cue; overlap with intent; hidden knowledge leak | Cracks/tilt versus bullseye, lower-body labels; no new stun status or bespoke state sheets |
| Nine static dead poses | Make defeat legible and leave a coherent body in the scene | Select surviving threats; no corpse action today | Existing SpriteFrames, UNIT_DEFEATED, ledger, unit IDs | Nine art candidates, shared draw path and regression tests | Early death from resolved HP; corpse becomes legal target; missing art; overlaps | One nonloop dead frame each and shared foot anchor; no corpse manager or new simulation fields |

## PLAYER EXPERIENCE

Enemy HP stays red; the narrow lavender track beneath it is break progress. Hovering or focusing an
enemy still reveals exact HP/Stagger and the public effect details. Selection does not move its feet.
Broken has lavender cracks and a BROKEN label. An exposed weak point has a static gold bullseye and
EXPOSED label at normal scale. Enlarged text uses the same bullseye/cracks and a Broken icon, with
complete words in inspection, so state labels do not cover the creature. A defeated creature
collapses into its own artwork and remains dimly visible in its lane.

The title uses the marsh and shared stepped frame family with a quiet reading surface. Only existing
working entry actions appear. Day/night variants preserve the same composition number and foreground.

## RULES

- Day/night is decorative. It never changes conditions, affinities, AI, encounter selection or time.
- Keep all six runtime PNGs directly in `assets/art/environments/briarfen/`, named
  `briarfen_marsh_day_N.png` / `briarfen_marsh_night_N.png`. Equal N identifies a composition pair.
  Sort numerically within each lighting set. No nested alternatives folder or directory-driven rules.
- Preserve the existing 0.62 backdrop crop focus and shared lower foreground actor plane. Never shrink
  an actor for its intent strip, health text or a particular painting. Text-size accommodation remains
  the existing short-stage fallback; death/status changes do not alter lane or view bounds.
- The enemy break number is inspection-only; HP retains its heart and current value. Both bars clip
  fractions to [0,1], and zero draws zero fill. The break track remains narrower in height than HP.
- Broken and exposed visuals consume existing public ledger flags, including when both coexist.
  No inferred affinity, secret move, new stun duration or vulnerability multiplier comes from art.
- Select dead art on the presented UNIT_DEFEATED event, never from the final resolved unit state or
  an HP tween reaching zero. A zero-HP DAMAGE event alone cannot skip ahead to a corpse.
- Keep defeated enemies visible at 0.72 view opacity, with the dead sprite's own subdued tint. Hide
  their health/effect tracks and selection bracket. Keep instance UID and input lane stable; existing
  engine target policy still excludes defeated units from living-target options.
- A missing dead frame uses the shared flattened-body fallback. Art-off mode preserves the same
  events, target eligibility and timing. Fallen allies retain their existing dim/fallback treatment.
- Bodies last for the current battle presentation. No cross-battle persistence, revival, consumption,
  corpse targeting, decay, loot or post-death trigger is added by this contract.

## UI REQUIREMENTS

Departure Mono v1.500 is the active bundled font. Body and secondary text use 22/33/44 px at
100/150/200%, matching its native 11 px grid. Keep nearest texture filtering and the font's disabled
antialias/subpixel settings. Live names/numbers/bindings are never baked into art. Ellipsised labels
retain complete immediate hover/focus detail and selection feedback; scaled text is not reduced to fit.

The shared compact plate is 52 px at normal text size. Its height depends on text scale, never on
selection, damage, effects or life state. Effects move above the plate when HP digits occupy the row;
overflow counts stay within the lane. Normal state labels occupy the body rather than covering the
intent strip. At 150/200%, use state shapes/icons and inspection words; enemy selection keeps its
brackets and preview target name without an oversized TARGET tag. Shared title frames are integrated;
combat frame/bar texture assignment remains staged, since its current code-drawn bars are clearer small.

The title column scrolls and follows keyboard focus at enlarged text sizes. Command title and input
instruction have separate rows. Action previews fit their actual content rectangle and preserve the
assumed Good grade and direct-hit/per-target distinction. Enlarged timing docks can cover decorative
scenery; reaction meter/header stay fixed and unusually long card/caveat content can scroll.

## DATA REQUIREMENTS

- `assets/art/environments/briarfen/catalog.json`: six explicit paths, lighting/index/pair IDs,
  dimensions, hashes, crop, decorative status, source prompt records and runtime assignment.
  Night 1 remains the default. Other variants are available for explicit assignment through existing
  `defaults.battle_backdrop`; this pass adds no random or automatic background rotation.
- `assets/art/enemies/briarfen/sprites/<enemy_id>_dead.png`: transparent generated source, unchanged.
  Each existing `<enemy_id>_idle.tres` SpriteFrames now includes `idle` and one nonloop `dead` frame.
- `display_height` and `faces_left` keep their existing idle meanings. New optional
  `dead_display_width` is measured in screen pixels before the stage shrink factor. The dead AtlasTexture
  preserves aspect ratio and anchors bottom-centre at the idle feet without changing the view rect.
- Dead atlas bounds use alpha >=24 plus a 2 px margin. That is region selection, not pixel cleanup.
  Exact prompts, references, dimensions, hash, region and width live in the art manifest.
- `assets/art/global/fonts/DepartureMono.otf` plus its SIL OFL license are explicit export dependencies.
  Pixelify remains as historical material; no active runtime text depends on it.
- PresentationLedger remains the life/state source. No BattleUnit, Resource definition class or save
  schema is extended for future corpse interactions.

## BALANCE PARAMETERS

None. HP, Stagger, recovery, weak-point exposure, damage, target eligibility, reaction windows and
execution grading are unchanged. Presentation-only tunables are bar heights/gaps, plate padding,
corpse width metadata, tint/opacity and label placement. They cannot become gameplay parameters.

## EDGE CASES

An HP tween may be nonzero after defeat is presented, or zero before it: use ledger life. Restart and
reconciliation must restore dead visibility rather than fade it out. Two identical enemies use their
stable UIDs, not art names. Large corpses may extend beyond their lane visually but never enlarge click
bounds or move surviving actors. Fen Wisp's extinguished pose still anchors to the same presentation
plane. Both Broken and Exposed must be visible together and disappear on their own events or defeat.
At 200%, three-digit HP and long effects cannot spill into a neighbour. Long names, range values,
AoE previews, condition caveats, narrow windows, missing textures and art-off fallback need review.

## ACCESSIBILITY REQUIREMENTS

Check G/C, 5/S, 0/O and 1/I/l at all three supported text scales. Preserve keyboard/controller focus,
40 px minimum interactive controls, full inspection text, current bindings and sound-off operation.
Reduced motion/flashing retain Broken cracks/labels and the static exposed bullseye. A timed input's
truth remains its existing clock; decoration and scrolling do not change or answer it. Keep essential
text and graphic contrast targets from the style guide; final human/colour-vision review is still open.

## ACCEPTANCE TESTS

STAGE-01: Six flat PNGs resolve and match catalog dimensions/hashes; pairs are day/night N=1..3.
No runtime reference uses the removed alternatives paths. Art changes do not create conditions.

STAGE-02: Actual 1280×720 captures show four mixed enemies on the day variants and night default,
with enlarged text/conditions, intended full-size silhouettes and shared footing. No bar number for
enemy Stagger appears on the stage; exact value remains in hover/focus/target detail.

STAGE-03: All nine existing enemy resources load exactly one nonloop dead frame. DAMAGE at zero
presented HP retains idle until UNIT_DEFEATED. Defeat switches artwork even while HP tween is nonzero.
Dead and idle keep the same view size; surviving lanes/feet do not move.

STAGE-04: Defeated units remain addressable by instance UID, while every living-target option excludes
them. No revived target, healing consumption or post-death rule is available. Restart/reconcile show
the correct life state; art on/off cannot change rule outcomes.

STAGE-05: Broken, exposed and simultaneous flags are statically distinguishable without covering the
intent strip or relying on flashing. State/death review overrides must be identified as artificial
presentation tests, not gameplay evidence or a fresh-player result.

STAGE-06: Title, planning, reaction and attack captures use the new font at supported scales. Title
focus/scroll remain reachable; preview and attack title/instruction do not overlap. Reaction content
cannot expand outside the viewport; fixed meter and keys retain the existing input/timing semantics.

STAGE-07: Run script validation and the existing regression suite, including the new event/life/target
tests. Record results and visual limits. Generated images remain candidates pending artist cleanup
and human clarity review; passing automation cannot close READ/REACT acceptance.

Pillar review: READ improves glyph/state/life recognition; REACT preserves timing truth and legal
defenses; ADAPT and EXPERIMENT expose existing openings without new rules. AFFECT THE WORLD gains
visual continuity only. Future corpse interaction is a separate design decision, not implied scope.
