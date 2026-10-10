# Decision Log

## D-048 — Prototype the revised journey, station and character menus

**Owner:** Adrian / Director. **Status:** Frontend prototype for review, 10 October; backend assigned.
**Update, 10 October:** Backend returned and presentation integrated for Adrian's human test.
D-049–D-054 below govern the working transactions; the preview-only consequences below record
the original prototype stage. See [Director acceptance](reports/V0_5_UI_DIRECTOR_ACCEPTANCE.md).
**DECISION:** Adopt [the requested UI iteration](design/V05_UI_PROTOTYPE.md): five-choice title,
chronological Continue picker, dedicated anvil and Stillroom, icon-first Equipment/Inventory/Combat,
Character-owned Field Guide and stacked save/pickup notices. Deprecate the public preparation-bench
flow and public reset. Keep legacy IDs and debugging code compatible. New journey creation,
autosave event ownership, field equipment permissions, station service checks and persisted six-of-
eight Combat arrangements go to [Claude](briefs/V0_5_UI_BACKEND_HANDOFF.md).
**WHY:** Gear and crafting decisions need a visible object/slot hierarchy and one familiar information
box. Long contextual explanations belong behind Help/inspection. Saves must never displace menus.
**CONSEQUENCES:** New Journey's Start is disabled until real creation is wired; Combat arrangements
are explicitly local previews. Existing station guards and engine capacity remain intact. Two future
Forge sockets and two future potion/Combat positions do not authorize new mechanics. Generated art
is supplied with provenance; no new audio delivery, balance retune or version change is required.

Every irreversible (or expensive-to-reverse) decision gets an entry. Format per `DESIGN_DOCUMENT.md`
("The handoff format"). **Owner** marks who has authority; entries marked *Provisional* await the
Director (ChatGPT) and are cheap to change because they live in data.

---

## D-001 — Active party is protagonist + one companion + one familiar
**Owner:** Director (GDD). **Status:** Locked.

**WHY:** Reduces animation, UI, AI, balance and content complexity while preserving party synergy.
**REJECTED:** Four-character party.
**CONSEQUENCES:** Companion choice matters; enemy groups stay 1–4; the engine supports exactly two
player-controlled units plus trigger-only familiars.

## D-002 — Battle logic is a pure, deterministic state machine; presentation replays events
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** The GDD requires seeded determinism, headless balance simulation, a sandbox and "no systems
coupled to UI". One engine serves the game, the simulator and the tests.
**REJECTED:** Engine driven by `await` on UI nodes (cannot run headless or synchronously in tests);
logic inside Nodes/animations.
**CONSEQUENCES:** The engine pauses only at three input points (action select, action command,
reaction). Everything visible is a `BattleEvent` record. Any battle is reproducible from seed + inputs.

## D-003 — Round-based initiative with intents declared at round start
**Owner:** Claude (technical), affects design. **Status:** Locked unless Director objects.

**WHY:** The GDD speaks in rounds (3–5 round target, "once per round" familiar limits, round-count
metrics) and wants Into-the-Breach-style readable intent. Declaring all intents at round start means the
player always sees every enemy plan before acting, and Tempo decides who acts before whom.
**REJECTED:** CTB/tick timeline (Tempo = action frequency). More expressive but harder to read, harder
for AI lookahead, and blurs "round" metrics.
**CONSEQUENCES:** Tempo matters as *order* (can I break that channel before it releases?). "Delay"
effects push a unit to the end of the round. Hammer "slowness" is expressed as a Tempo penalty.

## D-004 — Mechanics are composed from Traits (modifiers + triggered effects)
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** Weapon identities, equipment rules, resonance, familiars, companion passives, statuses and
battlefield conditions are all "while X is present, change a number" or "when Y happens, if Z, do W".
One interpreter covers all of them; designers author them in the inspector.
**REJECTED:** Bespoke scripts per weapon/familiar (GDD forbids); a general scripting language
(over-engineering).
**CONSEQUENCES:** Effects/conditions are typed "union" Resources interpreted by `EffectResolver` /
`ConditionEvaluator`. Adding a new *kind* of effect is a code change (enum + branch + test); adding new
*content* is not.

## D-005 — Statuses, damage types and other closed sets are enums, append-only, explicit values
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** "Avoid runtime magic strings." The GDD caps statuses at six and damage types at a handful.
Explicit integer values keep `.tres` files and saves stable when new values are appended.
**CONSEQUENCES:** Never reorder or reuse an enum value. Open-ended content (weapons, enemies, items) uses
`StringName` ids on Resources instead.

## D-006 — Damage types: SLASH, BLUNT, PIERCE, FIRE, STORM, BLIGHT, PURE
**Owner:** Claude (technical) / Director (design). **Status:** Accepted for M1, 7 October 2026.
BLIGHT remains reserved; acceptance does not authorize its behaviour or new content.

**WHY:** Weapon choice must matter ("Build test"); weakness/resistance by physical family (Sword=SLASH,
Hammer=BLUNT, Bow=PIERCE) creates that decision with no extra systems. FIRE/STORM align with Burn/Shock;
PURE is status damage that ignores Guard.
**REJECTED:** Per-element numeric resistance tables (opaque); dozens of elements (anti-feature list).
**CONSEQUENCES:** Weakness ×1.3, resistance ×0.7 globally (BalanceConfig). Weakness hits grant Focus and
bonus Stagger.

## D-007 — Focus is per character, integer, capped (default 10, start 2)
**Owner:** Claude (implementation of GDD). **Status:** Rule accepted by Director, 7 October 2026;
numbers retained as provisional tuning. This does not decide expedition persistence.

**WHY:** GDD's Mara passive ("protagonist parries grant Mara Focus") implies per-character pools.
Small integers are readable as pips.
**CONSEQUENCES:** Gains: GOOD +1 / PERFECT +2 on focus-generating actions, PERFECT +1 on others,
weakness +1, parry +2, break +2, Guard +1, Inspect +1, plus traits. Enemies have their own pools
(+1 per activation) which pay for big moves — this is the GDD's `resource_cost`.

## D-008 — Reactions: one window per enemy action; first input locks the choice
**Owner:** Claude (technical), confirmed by Director. **Status:** Accepted, 7 October 2026.

**WHY:** Prevents "press every button" exploits and keeps AoE reactions to one decision. Unavailable
reaction types are shown crossed out (rules are never hidden). *Amended in M1 UI work:* in the reaction
widget a crossed-out key is inert — it neither locks nor fails the window, so a mis-press on a rule the
player can see does not cost the turn. The engine still normalises a submitted disallowed reaction to
"no reaction" (replays, tools), so the rule holds outside the UI too.
**CONSEQUENCES:** Successful Evade/Parry also prevent the attack's statuses; Brace does not. This makes
"Brace or Evade?" a real decision against status attacks.

## D-009 — Settings live in their own autoload and file (`user://settings.cfg`)
**Owner:** Claude (technical). **Status:** Amended by D-049, 10 October 2026.

**WHY:** Assist and accessibility are per player. Tactical difficulty is per journey under D-049,
and remains changeable at any time ("Allow difficulty to change during an existing save").
**CONSEQUENCES:** Adds a seventh autoload (`Settings`) to the GDD's suggested six. Settings still
presents difficulty; New Journey and loading a save apply that journey's value.

## D-010 — Input actions are registered at runtime from one default table
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** Rebinding, reset-to-default and persistence all need the defaults in code anyway; one table is
the single source of truth.
**CONSEQUENCES:** `project.godot` keeps only Godot's built-in `ui_*` actions; game actions (`hc_*`) are
created by `InputBindings` at startup and overridden from settings.

## D-011 — Saves are versioned JSON; settings are ConfigFile; no node trees serialized
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** Human-readable, diffable, migratable. The GDD forbids serializing live node trees.
**CONSEQUENCES:** Every runtime model implements `to_dict()/from_dict()`. `SaveMigrator` upgrades old
versions step by step; writes are atomic (temp file + rename).

## D-012 — Content definitions are discovered by folder scan
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** Designers add content by dropping a `.tres` into `data/…`; no manifest to forget. The registry
validates ids and references on load and the test suite fails on any invalid definition.
**CONSEQUENCES:** Export builds must handle `.remap` entries (handled in `DefinitionRegistry`).

## D-013 — The presenter plays events after the fact; bars follow a per-event ledger
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** The engine resolves a whole step synchronously (D-002), so by the time the presenter sees a
batch of events the unit state is already final. Reading state while animating would show HP drop
before the hit lands and the timeline jump ahead of the animation.
**REJECTED:** Snapshots of the whole state per event (memory and complexity); having the engine yield
between events (couples logic to presentation timing).
**CONSEQUENCES:** `BattleEventPlayer` keeps small ledgers (HP, Stagger) updated by DAMAGE / HEAL /
STAGGER_DAMAGE events and reconciles with the real state after each batch; the timeline follows
ROUND_STARTED / TURN_ORDER / TURN_STARTED / TURN_ENDED. An intent consumed later in the same batch is
rebuilt from its INTENT_DECLARED event, so every telegraph is visible before its attack.

## D-014 — Presentation waits are tweens bound to their node; real-time widgets use wall time
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** The sandbox restarts a battle by freeing the scene mid-animation. A coroutine awaiting a
SceneTree timer would resume on a freed instance (engine error); a node-bound Tween is killed with its
node and the coroutine is simply dropped. Action commands and reactions must be judged against real
elapsed time, independent of frame rate, Combat Speed and `Engine.time_scale`.
**CONSEQUENCES:** Combat Speed scales every non-interactive wait but never a timing window. Widgets
read `Time.get_ticks_usec()`; tests inject input by back-dating a widget's start time.

## D-015 — Godot's `ui_*` actions mirror the game bindings
**Owner:** Claude (technical). **Status:** Locked. Extends D-010.

**WHY:** Menus use Godot focus navigation (`ui_accept`, `ui_cancel`, `ui_up`…). Without mirroring,
rebinding Confirm or Back would not affect menus, and the JRPG defaults (Z confirm, X back) would only
work in battle.
**CONSEQUENCES:** `InputBindings.install()` reloads the project input map, registers `hc_*` actions,
then appends their events to the matching `ui_*` actions. The battle log key is handled before GUI
focus navigation so Tab never moves menu focus.

## D-016 — UI layout is built in code; scenes are thin roots
**Owner:** Claude (technical). **Status:** Retained for M1.1 by Director, 7 October 2026.
New artwork alone does not justify a scene architecture migration.

**WHY:** M1 UI is procedural placeholder art (pixel silhouettes, drawn icons) whose sizes depend on the
text-scale accessibility setting and the theme built in `UITheme`. Building it in code keeps one
source of truth, keeps diffs reviewable without the editor, and lets tests instantiate the real
scenes headless.
**REJECTED:** Hand-authored `.tscn` layouts for every widget (hard to review as text, duplicated
styling, easy to desynchronise from the theme).
**CONSEQUENCES:** `scenes/**.tscn` contain a single root with a script. Replacing placeholder visuals
with sprites happens inside the widgets (`UnitView`, `IconPainter`), not in the presenter.

## D-017 — Combat clarity is the next gate
**Owner:** Director. **Status:** Approved design, 7 October 2026; implementation pending.

**DECISION:** [M1.1](design/M1_1_COMBAT_CLARITY.md) is incorporated into the canonical GDD.
**WHY:** Functional tests and simulation don't establish readable decisions or fun.
**REJECTED:** World expansion, new enemies, or new mechanics before a human READ/REACT pass.
**CONSEQUENCES:** Prioritize honest information, stable input prompts and practice setup; retain engine,
trait system and balance. Five-person comprehension rubric is directional evidence, not a statistical claim.

## D-018 — Research must not leak through previews
**Owner:** Director. **Status:** Approved design, 7 October 2026; implementation pending.

**DECISION:** One presentation knowledge policy covers intents, previews, details and reaction names.
Unknown affinity hides all affinity-derived estimates/guarantees, not merely its label. Exact engine
calculations remain unchanged. Known previews state their direct-hit/per-target scope.
**WHY:** “Weakness?” and inferred exact bonuses give away the answer before learning it.
**REJECTED:** Misleading neutral estimates; a second combat/prediction simulator.
**CONSEQUENCES:** Qualitative fallback until knowledge unlocks. Inspect remains useful. UI cannot claim
complete multi-hit/AoE/trigger results from a single-hit estimate.

## D-019 — Keep binary Parries and current slice environment
**Owner:** Director. **Status:** Accepted existing rules, 7 October 2026.

**DECISION:** Successful party Parry triggers Bell Crow; successful Hollow Parry grants Mara Focus.
Spore Fog uses the existing once-per-round Burn ignition. No Perfect Parry tier, Blight or positioning.
**WHY:** Existing triggers deliver the intended synergy cheaply and read clearly.
**REJECTED:** Additional timing axis and status system merely to satisfy ambiguous examples.
**CONSEQUENCES:** Correct GDD terminology. Retain current 12 Stagger, 2 Focus, 8 Fire as tunable values.

## D-020 — Mastery may avoid damage; simulation is not a balance verdict
**Owner:** Director. **Status:** Retain current tuning, 7 October 2026.

**DECISION:** No chip damage, HP inflation, new feints or forced reaction restrictions. Keep 3–5 normal
rounds and investigate actual elapsed time. Tactician is smarter through existing public rules.
**WHY:** Reported autopilot outcomes cannot establish human tactical dominance or pacing.
**REJECTED:** Nerfing mastery to manufacture losses; new AI tools driven only by never-used counts.
**CONSEQUENCES:** Human and controlled Lab tests precede retuning. Knowledge-limited autopilot deferred.

## D-021 — One decision dock, stable input ownership
**Owner:** Director. **Status:** Approved design, 7 October 2026; implementation pending.

**DECISION:** Planning/command/reaction reuse one region. Preserve the current gamepad mapping and
first-allowed reaction lock, with fresh presses between states. Explicit safe pause/focus-loss contract.
**WHY:** The next input should be clear without learning a separate screen for each weapon.
**REJECTED:** New widgets/minigames per action; colour-only legality; hidden running clock under a modal.
**CONSEQUENCES:** Existing command graders remain; focus-loss and input carry-through require regression tests.

## D-022 — Practice and Lab share the current sandbox
**Owner:** Director. **Status:** Approved design, 7 October 2026; implementation pending.

**DECISION:** Practice exposes preset/loadout/difficulty/assist; Lab retains full tools. Practice is manual,
Unknown knowledge, no progress recording; saved difficulty/assist stay respected.
**WHY:** A first fight should test play, not comprehension of a developer form.
**REJECTED:** Tutorial campaign, new tutorial engine or removal of simulation tools.
**CONSEQUENCES:** One BattleSetup builder; Lab overrides cannot silently bleed into Practice.

## D-023 — Art replacement uses existing presentation interfaces
**Owner:** Director. **Status:** Art direction approved; generated candidates staged, 7 October 2026.

**DECISION:** Fen Patrol cast + one reusable backdrop first. SpriteFrames and generic event transforms,
with placeholder fallback. [Manifest](../docs/art/briarfen_v01/manifest.json) records irregular regions.
**WHY:** Recognition and readable motion justify the cost; bespoke per-move sheets do not.
**REJECTED:** Full-cast animation expansion, art-driven timing/hitboxes, treating generated art as final.
**CONSEQUENCES:** Pixel cleanup gate; no runtime assignment until renderer hookup. Familiar remains trigger-only.

## D-024 — Expedition persistence is not implicitly decided by M1
**Owner:** Director. **Status:** Deferred to expedition specification, 7 October 2026.

**DECISION:** Do not assume HP, potions and Focus all persist between battles. Decide their boundaries
explicitly when the excursion loop is specified. M1 remains isolated encounters.
**WHY:** Different carry rules change farming, recovery and encounter value; current sims cannot test them.
**REJECTED:** Justifying empty attrition fights with an unimplemented future loop.
**CONSEQUENCES:** No save or resource-reset change in M1.1; every current fight must teach or test a decision.

## D-025 — Separate action-policy evidence from human combat acceptance
**Owner:** Director. **Status:** Approved evaluation method, 8 October 2026; human gate pending.

**DECISION:** Compare existing SMART, BASIC_ONLY and RANDOM policies with fixed execution/assist
settings; use the [audit](reports/M1_DIRECTOR_POLICY_AUDIT.md) to focus the
[human session pack](playtests/M1_1_SESSION_PACK.md), not to pass the milestone.
**WHY:** Basic-only still selects targets and uses competent automated defenses. Random actions are
not a model of beginners. Wins alone cannot establish the value or readability of techniques.
**REJECTED:** Mandatory losses in normal fights; inferred human difficulty/seconds from simulation;
new enemy mechanics or balance changes before the M1.1 comprehension gate.
**CONSEQUENCES:** Preserve current tuning. Record first-read, adaptation, weapon decisions and pacing
separately, with exact build/settings and no invented human results. Current engineering priority stays M1.1.

## D-026 — Prepare a bounded expedition candidate without unlocking implementation
**Owner:** Director. **Status:** Paper comparison only, 8 October 2026; carry policy still undecided.

**DECISION:** Prepare [candidate A](design/EXPEDITION_RESOURCE_CANDIDATE.md): full HP and normal starting
Focus each fight, only existing potion charges carried. Compare it against cheaper all-reset control C.
**WHY:** A single visible supply budget is cheaper to reason about than simultaneous HP/Focus/item
attrition; it still needs evidence of a useful decision that isolated encounters cannot provide.
**REJECTED:** Treating this draft as approved scope; camps, wounds, durability, field crafting or a
world-state implementation while combat clarity remains open.
**CONSEQUENCES:** D-024 remains in force. The candidate includes boundary/save/retry requirements for
review, not new runtime fields. Choose control C if persistence adds only hoarding or bookkeeping.

## D-027 — Extend existing-cast art with one shared combat symbol vocabulary
**Owner:** Director. **Status:** User-authorized art continuation, 8 October 2026; final pixel/human approval pending.

**DECISION:** Incorporate the [art style guide](../assets/art/STYLE_GUIDE.md) and prepare
[v0.2](../docs/art/briarfen_v02/README.md): six already-defined enemy idle candidates plus
48 shared combat symbols. Bind enemy frames through existing data; hand off UI lookup to engineering.
**WHY:** Recognisable actors/effects support READ/REACT. Existing categories, families and event
transforms cover the current moves more cheaply than bespoke animation and icons for every technique.
**REJECTED:** New content, new statuses, full animation, ornate panel skins, art-driven rules/timing,
automatic resizing presented as final cleanup, and a passed human gate inferred from generated images.
**CONSEQUENCES:** The user's request supersedes the broader-cast staging hold in D-023/M1.1 F5 only.
Knowledge gating, accessibility, pixel cleanup and new-content limits remain. Exact prompts, regions,
provenance and mappings are versioned. [Actual captures](../docs/art/briarfen_v02/QA.md) reveal a
four-enemy layout/recognition constraint; resolve it within M1.1 before art/readability approval.

## D-028 — Assign UI integration to ChatGPT and simplify combat presentation
**Owner:** Director / UI integrator (ChatGPT). **Status:** User-authorized and implemented in the working tree, 8 October 2026; human gate open.

**DECISION:** Adopt [icon-first combat UI](design/ICON_FIRST_COMBAT_UI.md): no enemy context panels or
rail-driven sprite shrink, immediate hover/focus inspection, compact red enemy stats, portrait turn order,
icon toolbar/conditions, expanded actions and existing potion slots, familiar beside allies, pixel font,
and real-window reaction arcs/cards. Reorganise art by purpose and region; v01 gets individual lossless sprites.
**WHY:** Preserve battlefield recognition and meaningful choices while removing repeated prose and waits.
**REJECTED:** New inventory systems, pet turns, bespoke move interfaces, strobing feedback, hidden knowledge
leaks, balance changes and UI pixel bounds becoming combat geometry.
**CONSEQUENCES:** ChatGPT owns UI presentation code/art wiring and its canonical documentation. Claude owns
core engine architecture. This explicitly supersedes the earlier Director-only production-code boundary
for UI integration and older M1.1 panel/dock/font requirements. Existing combat rules and human gates remain.

## D-029 — Bounded environment/frame assets and full-mix audio intake
**Owner:** Director/UI integrator. **Status:** User-authorized asset preparation, 8 October 2026; runtime and human approval pending.

**DECISION:** Prepare two decorative Briarfen backgrounds, one shared stepped frame/bar family, and the
[audio folder contract](../assets/audio/AUDIO_CONTRACT.md) with a small [Suno request pack](audio/SUNO_REQUESTS.md).
Reuse existing music first. One full mix per cue is sufficient; stems/adaptive middleware are deferred.
**WHY:** Repeated fights gain atmosphere and consistent presentation through reusable assets, while
source/approval/loop expectations stop agents from silently selecting or transforming incoming music.
**REJECTED:** New encounters/terrain rules, bespoke UI boxes, busy text interiors, fake HP fractions,
automatic music scans, timing driven by soundtrack, mandatory stems, and inferred human approval.
**CONSEQUENCES:** Latest user request permits bounded frame ornament despite D-027's older hold.
Current UI/default backdrop/AudioManager remain unchanged while Claude reviews. New native resources,
source provenance and review evidence are prepared; later assignment follows canonical contracts.

## D-030 — Clearer glyphs, grounded actors and reusable defeat presentation
**Owner:** Director/UI integrator. **Status:** User-authorized and implemented in the working tree, 8 October 2026; artist/human review open.

**DECISION:** Adopt [the stage refresh](design/STAGE_PRESENTATION_REFRESH.md): three flat numbered
day/night pairs, Departure Mono, a framed/scrollable title, thin break tracks directly below enemy HP,
static Broken/Exposed markers and one dead pose for each of the nine existing enemies. Keep corpses
visible through the same ledger/UnitView path, without changing living-target eligibility.
**WHY:** Clearer G/5 and less plate height improve READ; shared state shapes preserve REACT and clarify
existing openings for ADAPT/EXPERIMENT. Reusable renderer/data changes avoid nine bespoke death systems.
**REJECTED:** Nested alternatives, art-induced actor shrink, HP-tween-driven death, flash-only weakness,
new stun rules, necromancer/cannibal mechanics, a corpse manager, persistent bodies or day/night rules.
**CONSEQUENCES:** This latest user request supersedes earlier font sizes, idle-only art limits and the
title-frame staging hold. Core rules, balance, save formats and human gates remain. Combat frame
textures stay staged; actual UI captures and regression evidence are recorded separately from art approval.

## D-031 — One inspector, deliberate confirmation and bounded menus for V0.2
**Owner:** Director/UI integrator. **Status:** User-authorized UI fixes in the working tree, 8 October 2026; human comfort review open.

**DECISION:** Adopt [the V0.2 interaction/card contract](design/V02_UI_INTERACTION.md): scrollable
Practice/Lab with a fixed footer, five window sizes, one immediate inspector with per-icon event
coordinates, shared structured action/enemy cards, dark spaced intent tiles and exclusive Setup
ownership. Enter/gamepad A confirm; Space/Z remain command defaults; explicit rebinds are respected.
**WHY:** The user's playtest found off-screen controls, stranded pause overlays, modifier-induced
inspection flicker, blocked Supplies and nonfunctional scrolling. Shared routing/layout fixes
support READ/REACT and preserve ADAPT/EXPERIMENT choices more cheaply than bespoke tooltips per move.
**REJECTED:** Pinned target/second Alt overlays, native accept defaults appended to rebinds,
unexplained selection bars, hidden-state leaks, new combat/input timing and release scope expansion.
**CONSEQUENCES:** Supersedes the old UI requirements listed above. A global resolution preference
is additive; no progress-save format changes. Fresh automated/rendered evidence is separate from
controller, color-vision, human play feel and release approval.

## D-032 — Less repeated stage UI, structured inspection and explicit recipient review
**Owner:** Director/UI integrator. **Status:** User-authorized follow-up, 8 October 2026; human visual/comfort review open.

**DECISION:** Adopt [the V0.2 follow-up](design/V02_UI_FOLLOWUP.md): move reaction legality to
inspection/active reaction UI, remove repeated turn/target tags and the familiar readiness circle,
name threat, separate unit fields/affinities, compact the existing inspector through a native-font
content transform, and require target review even for one legal recipient. Lists own their wheel;
Hold-details follows actual held state. Redraw the shared heart and existing terrain decoration.
**WHY:** Adrian's screenshots show ambiguous threat/readiness markers, overflowed combined facts,
redundant stage icons and accidental commitment. Shared presentation fixes improve READ/REACT and
preserve deliberate ADAPT/EXPERIMENT choices.
**REJECTED:** Bespoke unit cards, a second inspection overlay, new confirmation modals, new combat
or environmental rules, research/future-state leaks and new particle middleware.
**CONSEQUENCES:** Supersedes the specific earlier UI behaviors in D-031; retains engine rules,
knowledge thresholds, native font raster sizes, accessibility preferences and release/human gates.

## D-033 — Complete support cards and reuse the shared presentation art

**Owner:** Director/UI integrator. **Status:** User-authorized, 8 October 2026; human visual review open.
**DECISION:** Adopt [the support presentation contract](design/V02_SUPPORT_PRESENTATION.md).
Restore authored descriptions in expanded actions, show direct support effects by icon/name and
recipient, assign Cinder Pup art, use existing textured HP/break resources, and dock compact
condition announcements to the header. Reduced motion substitutes a stationary card and steady border.
**WHY:** Guard's existing rules were skipped by its expanded card; non-damage outcomes fabricated
a dash. Cinder Pup was the only equipped creature without art. Terrain introductions did not teach
the location of their persistent details. Shared adapters/resources improve READ without adding rules.
**REJECTED:** Per-action widgets, a second resolver, new familiar mechanics, notification middleware,
flashing arrival effects, repeated terrain introductions and a new art family.
**CONSEQUENCES:** Transient UI fields only; no save/balance/research/timing changes. Source artwork,
generation prompt and current rendered/test evidence are documented. Release approval is separate.

## D-034 — Expanded action scrolling and a brief manual preparation beat

**Owner:** Director/UI integrator. **Status:** User-authorized pre-push polish, 8 October 2026.
**DECISION:** Adopt [the final polish contract](design/V02_PRE_PUSH_POLISH.md): expanded action
details own wheel input over their source; Cinder Pup display scale becomes 1.2; manual commands
and reactions show one 400 ms real-time preparation cue before starting their existing clock.
**WHY:** Action-list wheel priority blocked convenient expanded inspection. The Pup was hard to
read. Consecutive timing sequences felt overwhelming, even though each grading window was correct.
**REUSE:** Existing inspector arbitration, familiar portrait fitting, transition panel, scene-bound
tween, fresh-press latches and command/reaction widgets. No new combat timing or notification system.
**CONSEQUENCES:** Supersedes unconditional list-wheel priority only while details are expanded.
Preparation pauses on focus loss, cancels on restart, ignores Combat Speed, and never consumes an
active timing window. Simulator/untimed actions skip it. Human pacing review remains open.

## D-035 — Prepare on the actual timing UI; fit and protect announcements

**Owner:** Director/UI integrator. **Status:** User-authorized screenshot/UX follow-up, 8 October 2026.
**DECISION:** Revise [the polish contract](design/V02_PRE_PUSH_POLISH.md): the actual command meter
or reaction ring/cards stay visible during the 400 ms beat, inactive at zero time, then start in
place. Announcements fit settled autowrap content and suppress contextual inspection until hidden.
**WHY:** A separate Get ready panel prevented scanning the timing cues during preparation. A
temporary narrow label layout left the first banner oversized; hover details could cover it.
**REUSE:** Existing widgets, clocks, fresh-press latches, bound tween, Banner panel and inspector
suppression callback. No extra overlay, notification service or combat phase.
**CONSEQUENCES:** Supersedes D-034's transition-panel presentation only. Preparation input cannot
grade, charge or consume beats; held keys/Confirm are relatching boundaries. Assist pause, timing
specs, grading and battle rules remain. Opening/condition details are available again after the
announcement, including reduced-motion docking behavior. Actual captures and regressions record it.

## D-036 — Expose saved knowledge and integrate authorized version playlists in V0.3

**Owner:** Director/UI integrator. **Status:** Implemented in the working tree, 8 October 2026;
human clarity, controller comfort and runtime listening remain open.

**DECISION:** Add a read-only Field Guide over existing bestiary/mastery, fix enlarged reaction
help using the font's real line height, and integrate Adrian's six explicitly approved songs as
three version playlists. Use private shuffle bags, two streaming decks, scene fades and end-aware
overlaps; prepare native-rate, measured exports while preserving originals. Recognize future
`_calm` / `_intense` groups and matching version requests. See [V0.3 contract](design/V03_FIELD_GUIDE_AND_AUDIO.md).

**WHY:** Make knowledge earned in combat visible outside it and give repeated fights a coherent
soundscape using existing content. Reusable playlists support additions/replacements without
hard-coding v1/v2. This advances the slice while the new-world/content gate remains open.

**REJECTED:** New progression rewards, new combat/world systems before clarity acceptance, source
overwrites, soundtrack-driven combat clocks, global RNG use, and claiming separate generated
versions are sample-aligned stems. Future simultaneous layers require verified aligned exports
and their own synchronized adapter; filename suffixes alone establish only grouping.

**CONSEQUENCES:** Supersedes D-029's single selected mix/runtime hold following Adrian's explicit
music authorization. No save/rule/balance/binding change. Human musical-fit authorization is recorded;
agent audition, seamless loops, verified licensing and human comprehension are not inferred.

**AUTHORIZED FOLLOW-UP:** Include the supplied v01 intense battle example, standardize boss inbox
filenames/sidecars to underscores, and expose manual song/version/tone/end tests in Audio Lab.
Add a reusable file-argument importer with external-original preservation and archived deliberate
replacements. Automatic battle intensity and simultaneous aligned layers still require an engine
contract; the manual frontend supports listening while that work is specified.

**TIMESTAMP FOLLOW-UP:** Adrian requested adaptive same-position changes and a usable seek bar.
Same-song version/tone selections now preserve source time through leading-trim offsets; only new
cues and Next version start at zero. Preview ending leaves five seconds before automatic rotation
and displays a countdown. Click/drag/keyboard seeking commits the selected deck. Pending audio-mix
reads avoid rapid-switch drift. This supplies timestamp continuity without claiming verified musical
alignment or implementing automatic intensity policy.

## D-037 — Accept V0.3 engineering and preserve the open human gates

**Owner:** Director. **Status:** Accepted for Adrian's authorized push, 8 October 2026.
**DECISION:** Accept Claude's [engineering review](reports/V0_3_ENGINEERING_REVIEW.md), fix the
two remaining importer inconsistencies and release the combat/Field Guide/audio foundation as
0.3.0. [Final acceptance](reports/V0_3_DIRECTOR_ACCEPTANCE.md) records the independent checks.
**WHY:** The reported defects have targeted regressions, the complete suite passes and the final
tooling repairs preserve media bytes. No combat or save-format expansion is needed for release.
**CONSEQUENCES:** Engineering acceptance does not pass fresh-player clarity, controller or listening
review. Adrian separately authorized moving toward exploration and towns; the next stage requires
its own bounded Director contract and Claude backend handoff. V0.3 contains no overworld runtime.

## D-038 — First Footsteps starts one bounded spatial journey

**Owner:** Director. **Status:** Authorized by Adrian's post-V0.3 request, 8 October 2026.
**DECISION:** Adopt [V0.4 First Footsteps](design/V04_FIRST_FOOTSTEPS.md): walkable Gloamstead and
one Briarfen route, two existing encounter groups, a bypass, a return shortcut and a bell restoration
with a visible home consequence. Choose all-reset battles for this stage; potion-only attrition stays
a paper candidate. [Claude's handoff](briefs/V0_4_CLAUDE_HANDOFF_PROMPT.md) defines backend work.
**WHY:** Advance from a combat harness into a coherent place without adding an economy, new combat
content or a generalized quest framework. Persistent cleared encounters/landmarks provide consequence.
**CONSEQUENCES:** Explicitly supersedes the earlier world hold only for this scope. Human clarity
remains open. The HUD/readout shell and layout study are preparation; actual world runtime is pending.

## D-039 — Fixed game layouts and resolution presets; retire independent font sizing

**Owner:** Director/UI integrator. **Status:** Explicit user correction, 8 October 2026.
**DECISION:** Adopt [the fixed display contract](design/DISPLAY_PRESETS.md): one 1280×720 game
canvas and 22 px body text, uniformly scaled; the five supported window presets; no manual window
resize or independent text-size option. Fullscreen keeps the same canvas with letterboxing.
**WHY:** Adrian wants a deliberately designed game interface, not ongoing responsive-app work.
**CONSEQUENCES:** Supersedes earlier independently enlarged-text and arbitrary-width requirements.
Legacy font preferences are ignored/retired without changing progress or other settings. An oversized
window preference falls back to another supported preset. This correction follows the pushed V0.3
commit and remains separate working-tree work for engineering review.

## D-040 — Connected areas, editable layers and parallel exploration art

**Owner:** Director. **Status:** Adrian's asset/design continuation, 9 October 2026.
**DECISION:** Use connected continuous areas with a following bounded camera, named exits and
separate ground, decoration, depth-sorted actors/props, overhead, lighting/effects and UI layers.
Prepare the [first exploration pack](../assets/art/world/first_footsteps_v01/README.md) while Claude
implements the world host. [Map production](design/V04_MAP_PRODUCTION.md) defines the graybox,
collision and asset seam. Bodies and scenery use simple foot/base collision independent of alpha.
**WHY:** A larger-than-screen place supports exploration while keeping each authored area manageable.
Separate assets/layers support later lighting and editable state without repainting a giant map.
**CONSEQUENCES:** Supersedes the artwork-preparation wait; final dressing still follows traversal.
The pack and F6 art workbench are candidates/fixtures, not playable world progression or final art
approval. Enemy groups remain stationary. Two bank corners are rejected. Readable paths and an exit
visible before its trigger replace the incompatible requirement to show town square and distant gate
within one following-camera frame. No seamless continent, screen-flip grid or lighting framework.

## D-041 — First Footsteps integration preserves free exploration and save truth

**Owner:** Director. **Status:** Integrated for human acceptance, 9 October 2026; uncommitted.
**DECISION:** Move the guard from the three-way junction onto the bell approach near tile (62,22).
Keep Patrol/Guard categories, unrecorded defeats (including `battles_lost`), separate Save and
Save and return to title, and a non-interactive town bell. Finalize world copy and the fixed-canvas
dialogue/card/bench/map/menu views. Keep exploration silent and application/save versions at 0.3.0/1.
**WHY:** The player can scout the outside loop and reach the far-side latch freely; only the
deliberate bell restoration depends on guard victory. Readable public facts and saved-state wording
make each boundary understandable without adding progression rules.
**CONSEQUENCES:** No combat, reward, save-schema or eligibility change. Encounter spatial reach moves
with its group/point; existing safe anchors, physics tiles and portals remain intact. The map's home
description now reflects the existing bell flag. Pixel alignment affects art/camera only.
[Acceptance](reports/V0_4_DIRECTOR_ACCEPTANCE.md) and [follow-up](briefs/V0_4_POST_INTEGRATION.md)
record evidence and the open human/controller/listening gates; no release or human approval is inferred.

## D-042 — Present saved salvage and station-owned preparation

**Owner:** Director/UI integrator. **Status:** Integrated for Adrian's test, 9 October 2026; uncommitted.
**DECISION:** Accept V0.5A's backend foundation and connect all four equipment slots, read-only
inventory, public first-clear previews, saved victory/bell reward cards and a one-time old-save
catch-up notice. Explain that Reset journey retains salvage/claims and cannot renew rewards.
Finalize material/reward/rejection copy; use native stepped material icons and existing textured
panels. Retain Grounding's authored 12 Stagger and the application/save versions 0.3.0/1.
**WHY:** Earning the charm should suggest a concrete return to the bench and a Wet → Shock outing;
materials and already-claimed previews must tell the truth about the bounded route.
**CONSEQUENCES:** Rules, claims, ownership, station context, action ceiling and atomic writes remain
backend-owned. A preparation rejection stays in the station and shows its typed reason; Retry
retains the context, and inventory within preparation returns to the selected slot. Catch-up
feedback appears only after a successful write and does not repeat on reload. Materials explicitly
have no use yet. [Director acceptance](reports/V0_5A_DIRECTOR_ACCEPTANCE.md),
[presentation evidence](reports/V0_5A_PRESENTATION.md) and [icon provenance](art/SALVAGE_ICONS_V01.md)
record this pass; gameplay, art, controller and listening gates remain open.

## D-043 — Bound the first Forge/Stillroom budget and reversible choice

**Owner:** Director. **Status:** Specification ready for Claude, 9 October 2026; not implemented.
**DECISION:** Adopt [V0.5B's brief](briefs/V0_5B_BACKEND_HANDOFF.md): one fitting kit costs 2 Bog
Iron and requires 1 saved mastery point on any owned starter; it provides one introductory socket
on Pilgrim's Edge for Merciful Grip or Hollow Echo, or no fitting. Switching/removing is free;
reclaiming the kit atomically clears it and refunds the full 2 iron once. Clotting Salve and Focus
Tincture permanent recipe unlocks cost 1 Bog Iron and 1 Storm Salt respectively, with no mastery
threshold and no refund. Preserve two potion slots and all-reset capacities.
**WHY:** Total 3 iron + 1 salt fits the route's 4 + 1 in every purchase order. A single recorded
weapon action opens capacity without a repeat-clear grind; reusable existing traits offer comfort/
recovery versus a weak-point opening. The shared unlock does not demand mastery on three weapons.
**CONSEQUENCES:** This deliberately permits a single introductory fitting on the common sword
despite its current zero authored sockets; derive capacity from the kit instead of mutating shared
Resources. No second socket, damage tier, depletion, currency, new action or map work. Duplicate
traits and refund overflow reject whole. New entry snapshots capture fitting IDs; retries remain
immutable. This is a backend handoff specification, not shipped crafting or human balance approval.

## D-044 — Character menu, compact inspection and reward-unlocked bag rows

**Owner:** Adrian; implemented by Codex. **Status:** Integrated for review, 9 October 2026; uncommitted.
**DECISION:** Remove redundant reading buttons. Use icon/name/quantity loot with hover details;
replace the persistent Exposed banner with a ledger-driven, inspectable effect icon. Add the
exploration portrait and Inventory/Actions/Magic/Skills tabs. Inventory starts with ten thin
equipment frames in two rows of five, separate ingredient stacks and the combat inspector's
Alt/detail/pin/scroll behavior. Adrian chose specific progression rewards for expansion; author
five permanent slots on first bell restoration.
**WHY:** Long descriptions belong in contextual inspection, and existing scrolling already
handles long content. Bag rows should grow through explicit accomplishments rather than a
character-level system that the game does not have.
**CONSEQUENCES:** Capacity is a readout of approved persistent reward claims, with no new saved
counter or migration. Failure/retry/reset/duplicate boundaries remain atomic. No acquisition
discard/full-bag rejection is introduced, and all legacy equipment stays visible. Menu browsing
never equips or saves. The four preparation equipment types and eight-action ceiling are unchanged.
[Follow-up](reports/V0_5A_CHARACTER_MENU.md) records implementation, validation and captures.

## D-045 — Atlas character-menu frames and integrated V0.5 test timing

**Owner:** Adrian; implemented/prepared by Codex. **Status:** Presentation integrated; later
backend stages remain unimplemented, 9 October 2026; uncommitted.
**DECISION:** Reuse the existing square cloth/leather atlas frames for equipment pockets and
dark/gold strips for ingredient, action, magic and skill rows. Update application metadata to
0.5.0, preserving save version 1. Continue with Claude's bounded V0.5B Forge/Stillroom stage,
Codex integration and a bounded C brief, then V0.5C exploration and its presentation. Run the full
human test on the integrated V0.5 build rather than requiring it before the next backend stage.
**WHY:** The supplied atlas references fit the game's existing materials. A complete return/build/
discovery loop gives the full human test a more useful scope than testing the isolated A seam.
**CONSEQUENCES:** Hover/Alt/pin inspection and reward-derived slot growth remain intact. Automated
checks and focused reviews still accompany each return. Historical version holds are superseded
by Adrian's explicit update; no save migration is added. Human/controller/listening acceptance
stays open. The [current handoff](briefs/V0_5_CONTINUATION_FOR_CLAUDE.md) is prepared, not dispatched.

## D-046 — Connect the Forge and Stillroom; confirm backend policies

**Owner:** Director, following Adrian's V0.5 continuation. **Status:** Integrated, 10 October 2026;
uncommitted. **DECISION:** Keep the specified costs, mastery, exact refund and trait references;
connect all commands through the host's transaction/rejection/retry path. Two copies of the same
potion are rejected: two slots should support distinct situational choices. Duplicate traits are
checked against the resulting active loadout in either direction; an unequipped fitting is inert.
Grandfather legacy prepared recipe potions without charging salvage. Accept no-op fitting/potion
choices without writes; equipment re-choice also writes nothing under D-053 (supersedes the
earlier V0.5A exception).
**WHY:** Preserve existing saves and avoid hidden costs, double traits or redundant writes.
Recipe source, free reusable bases, no Catalyst, mastery/current stock, refund preview, kept
Pilgrim's Patience and fitting activation are presented from typed readouts.
**CONSEQUENCES:** Recipes stay permanent; kit refunds clear the fitting atomically. No balance or
battle-resource change. Merciful Grip's wider Perfect window also feeds Pilgrim's Patience's
Focus: watch it in Adrian's test, without claiming balance acceptance or retuning it.

## D-047 — Place the first gathering / discovery / rune loop

**Owner:** Director. **Status:** Integrated for Adrian's test, 10 October 2026; uncommitted.
**DECISION:** Accept the proposal with physically checked placements in
[the bounded C specification](design/V05C_EXPLORATION.md). One seam grants +1 Bog Iron once per save.
Low → high → middle reveals the drowned niche; searching grants existing Fenrunner Leathers once.
Wrong runes clear the attempt, with low starting a fresh attempt when applicable. Confirm strikes
directly; gathering/searching require explicit dialogue actions. Each strike saves once.
**WHY:** Optional exploration yields a real alternative garb and reuses existing rules/rewards.
Written clue, notch counts, saved lights, prompt progress and static feedback preserve sound-off
play. Original small stepped art and three soft procedural stone tones extend the established
visual/audio vocabulary; existing approved music needs no new delivery.
**CONSEQUENCES:** Gathered nodes stay gathered after Reset journey; found secrets, solved puzzles
and rune attempts reset; claims never repeat. Reset copy says so. The route gains one spare iron,
with no price, damage, encounter, terrain-regeneration or version change. Gate chimes stays
test-only. Human/controller/art/listening gates remain open; V0.6 stays later work.

## D-049 — Tactical difficulty belongs to the journey (amends D-009)

**Owner:** Director. **Status:** Accepted for integrated V0.5, 10 October 2026; uncommitted.
**DECISION:** New Journey saves its chosen difficulty; loading applies it to Settings. Settings
can change it at any time during a journey: live state follows immediately, and the next normal
save persists it. Encounter entries capture the difficulty for that attempt and its retries.
Execution assist, bindings and accessibility remain per player.
**WHY:** A named journey should resume its own tactical challenge while retaining adjustable difficulty.
**CONSEQUENCES:** Amend D-009's original per-player difficulty rule. Closing through the window
before a save can lose a recent change; in-game exits save first. No new write boundary or version bump.

## D-050 — Kindle starts outside the six combat positions

**Owner:** Director. **Status:** Accepted for Adrian's human test, 10 October 2026; uncommitted.
**DECISION:** Keep the deterministic first-six order, Actions then Magic, for every starter and
an older save without an arrangement. Kindle starts unplaced. It remains granted, inspectable
and selectable in Magic; a visible Unplaced line names it. Place it to take it into battle.
**WHY:** Six positions make a real choice from seven granted actions. Preserve the authored order
and introduce the choice explicitly rather than hiding the seventh action.
**CONSEQUENCES:** Older players also receive this default; their next battle omits Kindle until
they place it. Existing captured entries retain their original actions. Human usability and
balance acceptance remain open; this ruling does not certify either.

## D-051 — Older journeys without difficulty resume as Adventurer

**Owner:** Director. **Status:** Accepted, 10 October 2026; uncommitted.
**DECISION:** A save without campaign difficulty uses Adventurer, independently of player Settings.
**WHY:** A deterministic default avoids transferring another journey's challenge into an older save.
**CONSEQUENCES:** An older Tactician player must choose Tactician once again. Optional campaign
fields keep save version 1 compatible; loading does not write solely to record this default.

## D-052 — Equipment refills freed combat positions in grid order

**Owner:** Director. **Status:** Accepted, 10 October 2026; uncommitted.
**DECISION:** Shared actions keep their positions. New equipment actions fill freed positions in
grid order in the equipment transaction. No per-weapon arrangement memory in V0.5.
**WHY:** The current arrangement stays predictable and the equipment preview can explain every change.
**CONSEQUENCES:** Sword → Maul → Sword may change a customised sword order. The candidate previews
and adopted result name affected positions; the arrangement and equipment save together.

## D-053 — Re-choosing equipped gear is a no-op

**Owner:** Director. **Status:** Accepted, 10 October 2026; uncommitted.
**DECISION:** Selecting the currently equipped item writes nothing and emits no save event. Show
the unchanged result. This supersedes the V0.5A equipment exception retained in D-046.
**WHY:** Save feedback should represent a successful write; an unchanged selection has no new progress.
**CONSEQUENCES:** Equipment now follows the existing fitting, potion and arrangement no-op policy.

## D-054 — Battle owns the screen; station save confirmations have a footer dock

**Owner:** Director. **Status:** Accepted and presented, 10 October 2026; uncommitted.
**DECISION:** Hide world notices while battle owns the screen. Notice timers continue, including
cards created during battle. In wide station and Character menus, reserve footer space for the
coalesced Game Saved card, beside the fixed actions. Other menus and exploration retain the stack.
**WHY:** Neither an encounter-entry save nor a station save should obscure an action the player needs.
**CONSEQUENCES:** No paused timers, deferred success announcement or duplicate event owner.
The station's Close button remains visible during the confirmation; Reduced Motion keeps it static.

## D-055 — Unified Loadout and visible capacity stay within earned limits

**Owner:** Adrian / Director. **Status:** Implemented and rendered; human acceptance open (10 October).
**DECISION:** Replace separate Equipment/Combat with one Loadout. Show truthful gear-source strips,
Core/stance grants, eight destinations (six usable), pet/authored passive selection and four supplies
(two usable). Inventory draws twenty cells in four rows of five; actual capacity stays 10/15.
Three visible Forge sockets retain one usable socket. All three menus share the supplied approved
ingredient catalog, including zero quantities. No extra grant, unlock or action is implied by art.
**WHY:** Source, destination and passive membership need to be visible together; drawing capacity
must not change progression rules.
**CONSEQUENCES:** Widgets consume backend readouts and emit commands. Missing contracts cannot
fabricate playable choices. Existing action/source and old-save content must remain reachable.
[Implementation status and gates](reports/V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md).

## D-056 — Finite supplies and individually crafted fittings

**Owner:** Adrian (finite paid brewing) / Claude and Director (provisional policies).
**Status:** Provisional for playtest; economy and human acceptance open, 10 October.
**DECISION:** Brew pays each batch into saved finite dose stock. Use the backend proposal of starter
4 Mending/4 Flask, 1 ingredient → 2 doses, 99-dose cap; only a saved victory settles actual uses once.
Defeat/retry/leave/quit discard attempt uses. Each fitting costs 2 Bog Iron with mastery 1.
**WHY:** Permanent recipe ownership cannot provide unlimited encounter supplies under the new brief.
**CONSEQUENCES:** Entry captures allowance; UI never decrements stock. Older paid kits retain granted
ownership and deliberately reachable refunds; loading does not refund or clear them. One-time stock
migration must not mint stock again on reset/reload. These values are not tuned or balance-approved.
[Backend outcome/migration policy](reports/V0_5_PLAYTEST_BACKEND_IMPLEMENTATION.md).

## D-057 — Individual party Break is a provisional playtest policy

**Owner:** Adrian (feature) / Claude and Director (provisional values).
**Status:** Provisional, requires deterministic regression evidence and human balance review.
**DECISION:** Present each party member's own Break from engine/ledger facts. Proposed values are
40 maximum, hit 8, Brace 4, Evade 0, Parry 6; Broken loses that unit's next activation, then recovers.
No reactions/cover while Broken, and no enemy Broken damage multiplier applies to party members.
**WHY:** Reaction choices need distinct resource consequences while keeping the two party units
independent. Presentation must not calculate or advance those rules.
**CONSEQUENCES:** Upright sprites, explicit bars/status and reaction indicators communicate the
state. The values remain cheap to change. No broader V2/Pressure rules or acceptance are implied.
