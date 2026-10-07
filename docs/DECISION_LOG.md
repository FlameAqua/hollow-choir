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
**Owner:** Claude (technical) / Director (design). **Status:** *Provisional.*

**WHY:** Weapon choice must matter ("Build test"); weakness/resistance by physical family (Sword=SLASH,
Hammer=BLUNT, Bow=PIERCE) creates that decision with no extra systems. FIRE/STORM align with Burn/Shock;
PURE is status damage that ignores Guard.
**REJECTED:** Per-element numeric resistance tables (opaque); dozens of elements (anti-feature list).
**CONSEQUENCES:** Weakness ×1.3, resistance ×0.7 globally (BalanceConfig). Weakness hits grant Focus and
bonus Stagger.

## D-007 — Focus is per character, integer, capped (default 10, start 2)
**Owner:** Claude (implementation of GDD). **Status:** *Provisional numbers.*

**WHY:** GDD's Mara passive ("protagonist parries grant Mara Focus") implies per-character pools.
Small integers are readable as pips.
**CONSEQUENCES:** Gains: GOOD +1 / PERFECT +2 on focus-generating actions, PERFECT +1 on others,
weakness +1, parry +2, break +2, Guard +1, Inspect +1, plus traits. Enemies have their own pools
(+1 per activation) which pay for big moves — this is the GDD's `resource_cost`.

## D-008 — Reactions: one window per enemy action; first input locks the choice
**Owner:** Claude (technical). **Status:** Locked unless Director objects.

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
**Owner:** Claude (technical). **Status:** Provisional — revisit when final art and a UI artist arrive.

**WHY:** M1 UI is procedural placeholder art (pixel silhouettes, drawn icons) whose sizes depend on the
text-scale accessibility setting and the theme built in `UITheme`. Building it in code keeps one
source of truth, keeps diffs reviewable without the editor, and lets tests instantiate the real
scenes headless.
**REJECTED:** Hand-authored `.tscn` layouts for every widget (hard to review as text, duplicated
styling, easy to desynchronise from the theme).
**CONSEQUENCES:** `scenes/**.tscn` contain a single root with a script. Replacing placeholder visuals
with sprites happens inside the widgets (`UnitView`, `IconPainter`), not in the presenter.

