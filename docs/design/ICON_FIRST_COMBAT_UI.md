# Icon-first combat UI — 8 October 2026

V0.5 follow-up: [Character Combat prototype](V05_UI_PROTOTYPE.md) combines Actions/Magic/Skills
as filters with six preview positions and two locks. It reuses CombatIcons and HoverInspector.
It does not change the actual battle menu or grant actions; persistent arrangement is explicitly
assigned in [Claude's handoff](../briefs/V0_5_UI_BACKEND_HANDOFF.md). Equipment, Inventory and both
stations now reuse this same docked inspection behavior instead of visible text dumps.

Canonical presentation addendum, implemented in the working tree at the user's request.
ChatGPT owns UI direction, art consistency, presentation integration and visual verification.
This supersedes the older M1.1 layout table, four dock columns, enemy context panels, delayed native
tooltips, default font, and full-cast art staging restriction. M1.1 knowledge, input ownership,
determinism, balance and human acceptance requirements still apply.

## DESIGN INTENT

Make the battlefield readable at a glance and reserve detailed text for deliberate inspection.
Preserve the decisions the existing engine already supplies; no new inventory, pet action, defensive
reaction, enemy move, or timing grade is introduced.

| Presentation change | Player-facing purpose / decision | Existing systems | Cost | Failure cases / cheaper reuse |
|---|---|---|---|---|
| Enemy icon strips and full-size bodies | Recognise who threatens whom; choose a target or interrupt | IntentReadout, ledger, UnitView, ActionPicker | Medium presenter work | Hidden move-family leaks, reaction legality errors, crowded channels; reuse existing readout and sprites rather than encounter-specific panels |
| Immediate shared inspector | Understand an unfamiliar symbol without waiting; compare options | Native tooltip strings, focus, UnitDetails | Small reusable component | Flicker, clipping, stale playback state; one inspector for every surface |
| Flat actions / supplies | Compare available actions and remaining charges | ActionOption, existing potion slots, normal selection flow | Medium layout work | Illegal focus costs, accidental use, zero charges; reuse the same choice/cost pipeline, no inventory system |
| Portrait order / header icons | Read team and initiative; inspect the next-round forecast or field rule | Existing timeline order, forecast and conditions | Small | Duplicate identities, current vs forecast confusion; reuse existing art plus stable enemy numbers |
| Familiar with allies | Understand allegiance and trigger readiness | FamiliarDefinition, ledger trigger count | Small | Mistaking it for an actor, absent portrait; no turn/target slot, procedural fallback |
| Reaction arcs / attack meter | Choose a legal defense and time an input | ReactionSpec, TimingClock, FreshPressLatch, existing command graders | Medium visual work | Misleading windows, color-only cues, flashing; reuse the actual windows and one clock |

## PLAYER EXPERIENCE

Header: encounter identity, round number, focusable condition icons and icon buttons for setup,
restart, log and pause. Turn order: miniature unit portraits, red enemy borders, gold acting underline,
stable enemy numbers. Dimmed portraits after an hourglass are a separate next-round forecast.

Stage: full-size idle sprites face their opponents. Each enemy carries a compact intent/target/status
strip with three fixed reaction positions. A slash marks an unavailable reaction. Four threat ticks
encode Light through Severe; the inspector names the level. Channel hourglass + number counts that
enemy's activations; a slash on the hourglass means uninterruptible. HP bars and enemy target brackets
are red; Stagger stays lavender and Focus bone-gold. Shape, position and inspection also encode meaning.
Effects use glyphs plus remaining turns/charges and `+N` overflow; full effects remain in details.

Dock: a wider action grid at left, selected action/result in the middle, existing potion slots at
right. Action names remain short labels beside family icons to distinguish actions sharing a symbol.
Costs use the Focus glyph and number; potion slots use different functional glyphs and charges.
The redundant party card is hidden. An equipped familiar stands beside the companion (or sole hero).

Hover or keyboard/controller focus immediately shows the same readable details. Selecting a target
pins its details in the left stage area, leaving the enemies visible. Leaving inspection briefly
retains the card; moving onto the card permits scrolling. Timed input and modal menus suppress it.

## RULES

All combat calculations, timing windows, action costs, potion charges, AI, turn order, knowledge
thresholds and familiar triggers remain in existing rules/data. The shared icon map is presentation
data. Unknown enemy moves use public intent categories; named family symbols require UNDERSTOOD or
Inspect. Unknown outgoing affinity shows `?`, with its explanation in details; it never leaks a range,
weakness bonus or guaranteed kill/break. Concise damage estimates explicitly assume Good timing and
state direct-hit/per-target scope. The detailed existing preview retains per-grade numbers and caveats.

The first allowed fresh defensive press still locks type and timing. Each stage arc and reaction
card becomes active only within `window_for(reaction) / 2` either side of impact. Disallowed reactions
stay crossed out. Active arcs thicken and cards say NOW; there is no strobe or separate Perfect Parry.
Attack tracks retain true Good/Perfect bands and add a fixed impact line, ticks and stepped framing.

## UI REQUIREMENTS

At 1280×720 / 100%, use a 52 px portrait strip, roughly 358 px stage and 186 px dock. Actions use
47% of the available dock width, supplies 190 px, preview the remainder. No enemy context rectangle
reserves stage height. Sprite scaling is only a short-viewport accommodation, never a response to
intent text. Enlarged text increases the timeline, uses two action columns and scrolls options;
essential font sizes remain scaled. Enlarged timed panels prioritise readable reaction cards and the
same horizontal timing meter, and can cover the decorative stage rings.

The inspector has no initial dwell, 65 ms settling when replacing visible content, and 140 ms exit
grace. It is clamped to the viewport and scrolls long rules. Native delayed tooltip painting is
suppressed within battle only. Full analysis remains available through the existing Details binding.

## DATA REQUIREMENTS

- `assets/art/global/ui/combat/icon_map.tres`: statuses/buffs/action IDs, public categories, known
  enemy families, reactions, potion functions and conditions. No gameplay resource schema change.
- Optional `SpriteFrames` still uses `idle`, `display_height`, `faces_left`. v01 now uses individual
  lossless cropped PNGs, matching v02 packaging; source regions and migration history are retained.
- Runtime art folders follow [the library index](../../assets/art/README.md). New region art gets
  its own enemy/environment region folders. Global symbols must not be copied into biome packs.
- Bundled Departure Mono + OFL license; live text, numbers and current input bindings, never baked labels.

## BALANCE PARAMETERS

No balance changes. Visual-only tuning: base icon 24–32 px; 65/140 ms inspector settling/grace;
red enemy accents; gold acting/focus accents; intended SpriteFrames heights. Adjusting visual parameters
must never alter a grader, action cost, chosen target, collision, RNG or knowledge gate.

## EDGE CASES

Duplicate enemies keep start-of-battle slot numbers after deaths. Acted/Broken/Defeated strips clear
their pending readout and expose the correct state on inspection. Channel counts are activations,
not seconds or rounds. Illegal actions stay focusable to explain their reason but cannot be used.
Supply selection uses existing target confirmation and spends exactly one charge. No equipped familiar
means no stage pet; Cinder Pup currently uses the procedural fallback. No active condition means no
empty banner. Sprite alpha residue and missing final pixel cleanup remain art limitations.

Playback details use displayed ledger values; full engine unit details are used only at stable planning
points. Focus loss, held confirmation keys, pause-before-reaction, assists, remapped bindings and queued
pause semantics remain unchanged. Long inspection content scrolls; it does not stretch outside the viewport.

## ACCESSIBILITY REQUIREMENTS

Mouse, keyboard and controller share details; target selection automatically exposes unit information.
Toolbar, conditions, timeline and familiar accept focus. Supplied actions keep names to distinguish
shared symbols. Stat icons have live numbers; unavailable reactions use strike marks, active cards
say NOW, and the impact line is static. No rapid flashing is introduced. Reduced motion/flashing and
sound-off preserve windows, legal choices and the horizontal timing marker. At 200%, scroll focused
action rows into view. Human grayscale/icon comprehension and controller usability still require playtest.

## ACCEPTANCE TESTS

UI-01: First inspection appears without dwell. Gaps under 140 ms keep it visible; replacements settle
for 65 ms. Leaving clears it; modal/timed input suppresses it; keyboard focus and target selection work.

UI-02: Four mixed enemies retain intended stage heights at 1280×720 / 100%. Four duplicates keep IDs
and disjoint target slots. Inspect 100%, 150% and 200%, boss/elite, no-art fallback and reduced effects.

UI-03: UNKNOWN icons reveal public categories only. Three reaction glyphs exactly match the readout's
boolean legality array; known move family appears only when named. Unknown affinity previews leak no numbers.

UI-04: Action and supply controls use existing selection, targeting and costs. A potion click spends
one charge once; zero-charge/insufficient-Focus actions explain their reason and remain unusable.

UI-05: Reaction arcs/cards match actual window boundaries, unavailable keys remain inert, the first
allowed fresh press locks, and held keys/focus loss/pause behavior is unchanged. Attack grades match rules.

UI-06: Migrated resources, all semantic textures and bundled font load. v01 extraction preserves source
pixels/regions. Restart and absent familiar/condition leave no stale artwork or details.

UI-07: Run script checks, full regression suite, actual Godot captures, and fresh-player READ/REACT
sessions. Automated results do not certify the human comprehension or final pixel-art gates.
