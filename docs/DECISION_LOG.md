# Decision Log

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
**Owner:** Claude (technical). **Status:** Locked.

**WHY:** Difficulty, assist and accessibility are per player, not per save slot, and must be changeable
at any time ("Allow difficulty to change during an existing save").
**CONSEQUENCES:** Adds a seventh autoload (`Settings`) to the GDD's suggested six.

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
with placeholder fallback. [Manifest](../assets/art/briarfen_v01/manifest.json) records irregular regions.
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

