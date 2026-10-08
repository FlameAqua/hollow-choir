# Hollow Choir — canonical art direction

Director specification · 8 October 2026 · v1.0

This guide is incorporated by [the GDD](../../docs/DESIGN_DOCUMENT.md). It extends
[M1.1 F5](../../docs/design/M1_1_COMBAT_CLARITY.md#f5--art-direction-and-production-limit).
The visual references are the original [Briarfen cast](sources/briarfen/v01/cast.png) and
[stage](environments/briarfen/briarfen_marsh_night_1.png). The [v0.2 pack](../../docs/art/briarfen_v02/README.md) adds art for
existing content only. Generated source paintings establish direction; they are not finished,
palette-cleaned pixel sprites. Art approval and runtime integration are separate gates.

> **Current UI integration addendum:** [Icon-first combat UI](../../docs/design/ICON_FIRST_COMBAT_UI.md)
> supersedes older text-heavy panels and dock placement. Use [the art library layout](README.md),
> Departure Mono, shared native CombatIconMap, immediate hover/focus details, red enemy accents and
> stage familiars. Icons may replace persistent text when the same detail is reachable by focus and
> target selection. This does not waive knowledge gating, final pixel cleanup or human review.

> **Latest stage refresh:** [Canonical contract](../../docs/design/STAGE_PRESENTATION_REFRESH.md).
> Flat `briarfen_marsh_day_N.png` / `briarfen_marsh_night_N.png` pairs replace nested alternatives.
> Departure Mono v1.500 uses 22/33/44 px at 100/150/200%, superseding the older 18/16 px guidance below.
> Nine existing enemies now have one static `dead` frame alongside `idle`, with bottom-centre footing
> and explicit width metadata. Broken cracks and an exposed bullseye use public ledger flags only.
> No corpse mechanics, day/night rules, new animation system or automatic final art approval follows.

## DESIGN INTENT

Make an actor, threat or interaction recognisable before the player reads its detail. Protect
READ and REACT first; support ADAPT and EXPERIMENT through consistent symbols. Retain the world's
ambiguity: neither Choir materials nor Bloom growth indicate moral alignment. AFFECT THE WORLD
remains outside the combat milestone; weathered scenery is not evidence of a world-state system.

The user's 8 October request authorizes a bounded extension of staged artwork beyond Fen Patrol.
It does not authorize new enemies, abilities, encounters, statuses, or a passed M1.1 clarity gate.

| Art feature | Player-facing purpose | Decision clarified | Interacting systems | Implementation cost* | Failure / exploit | Cheaper reuse selected |
|---|---|---|---|---|---|---|
| Six missing enemy idle candidates | Recognise the existing cast | Which actor to target or watch | Optional SpriteFrames, UnitView, stable target/intent slots | Low resource hookup; medium/high artist cleanup across six silhouettes | Boss obscures a neighbour; elite looks like an unrelated species; wrong facing | One static frame each, existing lean/lunge/hit/down transforms |
| Effects atlas | Recognise four active statuses, eleven buffs and Broken | Cleanse, exploit or wait out a visible effect | Status/buff readouts, ledger, focus details, Stagger meter | Low/medium shared texture lookup; medium small-size art cleanup | Wet/Bleed confusion, Broken mistaken for a new status, stale duration | One symbol per existing effect, numbers/text rendered live |
| Action-family atlas | Recognise action purpose consistently | Attack type, support tool or resource expenditure | Action menu, preview, current action data | Low/medium optional lookup; no resolver changes | Icon promises AoE, a reaction, damage or status that the action lacks | Sixteen reusable families covering current actions and known enemy moves |
| Intent/reaction atlas | Scan public threat categories and legal defenses | Interrupt, Guard or attempt a legal reaction | IntentReadout, knowledge filter, ReactionSpec, timing widgets | Low/medium shared presentation lookup; medium legibility review | Unique secret-move art leaks knowledge; decorative cue competes with impact | Ten current category symbols plus six shared reaction/channel markers |

*Relative planning estimates, not recorded implementation work. Existing procedural icons and opaque
UI panels are cheaper fallbacks and remain acceptable wherever a texture reads worse. Reject bespoke
move sheets, new shaders, particle systems, ornate panel skins and new animation tooling for this pass.

## PLAYER EXPERIENCE

“That broad fungal silhouette is the brute. Its heavy-attack symbol means I should read the target,
channel countdown and legal reactions. The water drop on Mara is Wet; I can check its duration and
change my plan before the storm resolves.” Recognition assists the existing information hierarchy.
No player must infer rules from a drawing alone.

## RULES

1. Identity comes from silhouette, value grouping and a small material vocabulary. Party faces right;
   enemies face left. Front-facing effigies/clusters may lean left without a forced anatomical profile.
2. Choir legacy: worn ivory cloth/stone, tarnished brass, charcoal iron, muted oxblood fabric.
   Bloom: irregular peat/root bodies, olive moss, rust growth, pale fungal edges. Both can coexist.
   Avoid glossy gold, fluorescent saturation, smooth plastic and demonic shorthand.
3. Use a warm near-black contour, a dark body mass and one readable light mass. Upper-left material
   highlights may describe form; no painted spotlight, ground vignette or atmospheric halo on a sprite.
   Reserve cold cyan for the existing marsh-light/storm vocabulary; keep it from washing out labels.
4. Pixel production uses intentional stepped clusters and a restricted palette. No automatic reduction
   or resize may be described as artist cleanup. Generated high-resolution sources retain their pixels.
5. One `idle` frame per actor is sufficient now. Generic anticipation, lunge, hit and down transforms
   remain the default. Animation never determines engine impact, reaction windows or event order.
6. Art cannot change hit areas, target slots, collision, weak points, research, damage or affinities.
   Existing placeholder art remains the fallback. Texture loading must not block an input window.
7. Before moves are UNDERSTOOD/Inspected, show the existing public intent category symbol. Do not show
   a distinctive named-move/family texture, filename, tooltip or accessible name that reveals hidden
   move identity or damage type. Public status payloads and reaction legality stay public.
8. Once a move is known, a family symbol is still only a navigation aid. Explicit scope, target,
   payload and legal reactions come from the action/readout. A blade symbol does not imply Parry.
9. Broken is a Stagger state, not a fifth active status. Do not register Chill or Blight merely because
   they exist in an enum or the long-term brief. Current active statuses are Burn, Wet, Shock and Bleed.
10. Conditions reuse their existing rule text and the Battlefield category mark. Flooded Ground is not
    equivalent to a Wet status on every actor; Spore Fog is not a poison status.

## UI REQUIREMENTS

Reference UI is 1280×720. Use Departure Mono at 22 px for body/secondary text, and interactive controls
at least 40 px high. Paintings do not contain labels, input bindings, turn numbers or durations.
Render those using the current UI font and presenter values. Status icons target 24–32 px, action
families 32–40 px and reaction cards 32–48 px. Prefer 32 px during candidate review. Any 24 px failure
uses the existing procedural symbol until cleaned; enlarging the entire dock is not the fix.

Opaque panels, semantic focus brackets, timing rings and progress bars remain code-drawn. Do not
place texture grain under essential text or rasterise the UI into a pixel buffer. Art icons may have
pixel texture; their silhouettes must remain simple and different in monochrome.

| UI role | Canonical colour |
|---|---|
| Background / panel / raised | `#101918` / `#172321` / `#20332e` |
| Border / primary / secondary text | `#62766b` / `#f1ead5` / `#bac6b5` |
| Selection and Focus / Heart / Stagger | `#e2c681` / `#94c89b` / `#c4b5e5` |
| Threat / Wet cue | `#f0a18a` / `#9ad7e0` |

These are UI tokens from M1.1, not a claim that generated images contain only those colours. Suggested
final sprite ramp: outline `#171a17`, peat `#333a30`, moss `#66713b`, rust `#9b513b`, brass `#a88b50`,
bone `#d0c2a2`, highlight `#f1ead5`. Target at most 24 opaque colours per ordinary sprite, 32 for
elite/boss, and 8 per small icon, subject to artist review rather than a new global palette engine.

## DATA REQUIREMENTS

Each pack has a versioned manifest, immutable generated sources, exact image dimensions, native facing,
measured regions, feet anchor, intended review height, asset status, source provenance and prompt record.
Use stable existing content IDs, not localised display names. SpriteFrames use `idle`, one frame,
`metadata/display_height` and `metadata/faces_left`, matching the working-tree renderer interface.

UI AtlasTextures are static declarative resources. Their mapping is a presentation contract, not a
new field in a combat definition. The v0.2 manifest records status enum values, buff IDs, action IDs,
enemy-action IDs and intent enum values. An engineer can implement one optional texture lookup with
the current procedural fallback. No new save field, combat enum or engine state is required.

Use the actual manifest rectangles. Never infer slicing from the requested image size. Cell margins
are exclusion gutters, not new border pixels; `filter_clip = true` prevents neighbouring samples but
does not remove unwanted art. Sources, review resources and final pixel exports must be distinguishable.

Import PNGs losslessly, nearest filtering, mipmaps off, no lossy/VRAM compression. Preserve alpha.
Verify at final size on dark, pale and stage backgrounds. Do not bake a checkerboard into transparency.

| Export target after artist cleanup | Cell | Anchor / usage |
|---|---|---|
| Party / ordinary enemies including Rotcap Brute | 64×64 | Bottom-centre; all limbs/weapons inside cell |
| Elite Bramblejaw / boss Mirebell Cantor | Up to 96×96 | Bottom-centre; larger cell only if recognition needs it |
| Familiar | 32×32 | Existing portrait/trigger role; no extra party slot |
| Combat UI icon | 32×32 | Centred; at least 2 px transparent margin; 24 px read check |

Generated candidate source sizes are not these final cell sizes. Keep source art unchanged; future
approved exports use a separate versioned path and require new region/anchor verification.

## BALANCE PARAMETERS

No change to current numbers. Damage, Stagger, status durations, buff charges, target rules, assist
windows and research thresholds remain in existing data. Display height is presentation only. Four
enemies must fit with their compact intent strips, target labels and distinct silhouettes.
Do not conceal a threatening status because a decorative image is larger than the previous icon.

## EDGE CASES

- Duplicate enemies retain instance names and stable slot markers; identical art is intentional.
- Bramblejaw must retain Thornhound kinship while its mantle and jaw distinguish the elite.
- The Cantor's bell must read at stage size; a larger body must not cover another actor or intent.
- Sporecaller is a rooted cluster; count it as one combatant, not three mushroom targets.
- Straw Penitent is an effigy on one stake. No walk cycle, independent limbs or new combat behaviour.
- Bleed uses a cut plus drop; Wet uses a plain drop. Shielding, Guarding, Shelled and Cover need distinct
  silhouettes and names. Coiled/Steady Aim are different buffs despite similar tactical use.
- Applying/removing an effect updates the icon on its event, including cleansing, expiry and restart.
- An unavailable reaction keeps its place and text; a strike overlay cannot hide its binding.
- Missing/corrupt textures fall back; source alpha residue, clipping or tiny detail blocks final approval.

## ACCESSIBILITY REQUIREMENTS

Every effect and intent has a focused name and explanation. No hover-only information, baked keyboard
letters, colour-only reaction legality or icon-only threat. Maintain ≥4.5:1 body-text contrast and ≥3:1
for essential graphic boundaries in the final composed UI; a source PNG alone cannot establish this.
Check grayscale and colour-vision simulations as well as labels. At 150%/200% text, use the current icon-first layouts
and retain actor, target, cost and legal reactions. Reduced motion disables bob/lean/shake decoration;
reduced flashing and sound-off retain the same static timing marker and honest impact clock.

## ACCEPTANCE TESTS

ART-01: Manifest paths exist, dimensions and regions match sources, IDs are unique, and every frame
and AtlasTexture loads. Candidate validation is recorded separately from final art approval.

ART-02: At intended stage heights on light/dark/stage surfaces, all six new identities can be named
from silhouette. No clipped appendage, visible haze, stray pixel island or incorrect facing. Inspect
bottom contact and event transforms without sprite jumps. Final exports meet the cell/palette targets.

ART-03: Every active status, buff, player action, enemy action and intent category has one documented
mapping. No extra gameplay definition is created. Known-move mappings cannot bypass knowledge gating.

ART-04: At 24/32 px and in grayscale, Burn/Wet/Shock/Bleed and the four protection buffs remain distinct.
Names/durations/charges are reachable with keyboard and controller. Otherwise retain procedural fallback.

ART-05: UNKNOWN and UNDERSTOOD views differ only where M1.1 permits. Unknown heavy and normal attacks
cannot be identified through hidden named-move family art or accessible names. Always-visible payload,
targets, channel units and reaction legality remain readable.

ART-06: Four duplicate enemies, mixed cast and boss layouts at 1280×720 and enlarged text keep stable
selection bounds and unobstructed labels. Art off/on produces identical battle results, targets and
timing. Texture failure and restart produce no stale or late event updates.

ART-07: Human art/clarity review remains pending until recorded. A contact sheet, image-generation
result or resource-load check cannot pass the fresh-player READ/REACT gate.

## Environment/frame continuation — 8 October 2026

The latest user request authorizes [two backdrop alternatives and one reusable stepped frame/bar kit](../../docs/design/ENVIRONMENT_FRAME_ART.md).
This supersedes the earlier blanket hold on ornate skins only for small corner/edge decoration on
existing boxes. Flat interiors, current padding, icon-first enemy strips, honest bar fractions and
full-size actors remain requirements. The active default/UI are preserved while engineering reviews.
Enemy threat colour is now `#e56d72` (the older table above records historical M1.1 tokens).
The native frame/bar kit extends the earlier code-drawn-only appearance guidance; live geometry,
resource fractions, focus ownership and gameplay semantics remain in the existing components.

## V0.2 information-card composition — 8 October 2026

Apply [the current interaction/card contract](../../docs/design/V02_UI_INTERACTION.md): one shared
action/enemy card, title top-left, Focus/charges/threat top-right, status payload strip beneath,
targets at left and outcomes at lower right. Use gold for title/Focus, red for threat/damage,
green for ally health/healing, lavender for break and cyan for recipients/neutral information.
Individual icons explain their own fact; fields within a card use its footer rather than opening
another popup. Enemy intent tiles use a dark backing, clear borders and gaps on every backdrop.
Group targets have an explicit count and status overflow is explained. Keep glyphs/words/position
alongside colors; no new art family or bespoke per-move interface is introduced.

## V0.2 screenshot follow-up

Follow [the inspection/targeting contract](../../docs/design/V02_UI_FOLLOWUP.md). Threat is a named
top-right badge, with a separate title row when needed. Unit name, type, knowledge and resource
values are distinct fields; affinities use icons/names grouped by Weakness, Resistance, Normal
damage or Unknown. Render inspector content at 82% of the existing native pixel-font sizes;
accessibility scale still applies. No repeated stage reaction row, turn/target text or pet circle.

The shared heart SVG uses two stepped lobes, a deep notch, tapered edges and neutral source colors
for existing allegiance tinting. ConditionArt reuses backdrop drawing: Flooded Ground has sparse
slate/cyan horizontal reflections and stepped ripples; Spore Fog has broken olive haze and sparse
square flecks. Use a two-pixel grid, muted opacity, slow discrete drift and static reduced-motion
signatures. Keep decoration behind actors; no bright circular particles, flashing or gameplay geometry.

## V0.2 support and resource presentation

Follow [support presentation](../../docs/design/V02_SUPPORT_PRESENTATION.md). Use the shared Choir
frame kit for health/break tracks and compact condition cards, with beveled fills and a dark stepped
rim. Health is 12 px high; break 5 px, separated by 2 px. Keep exact health beside the two-lobed,
beveled shared heart; break numbers belong in inspection. No ornamental fill at zero and no baked text.
Support actions use icon/name and recipient rows, not an empty damage placeholder. Cinder Pup's
generated source and prompt are recorded in [its provenance](../../docs/art/CINDER_PUP_V01.md).
Both familiar portraits preserve proportions and share a floor anchor. New global familiar art
belongs under global/familiars; regional enemy/environment art stays in its region folder.

Final pre-push scale tuning: Cinder Pup uses FamiliarDefinition.display_scale = 1.2, with a rounded
62×70 slot. Preserve its existing source PNG, aspect fit and paw baseline; clamp placement to the
stage's left edge. Bell Crow retains 1.0. This is display tuning, not a new art variant or hit area.
