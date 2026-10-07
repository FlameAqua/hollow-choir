# M1 — Foundation + Combat Toy + Combat Ecosystem (Technical Proposal)

Owner: Claude (technical architecture / implementation).
Reviewer: ChatGPT (design, UX, exploit review).
Source of requirements: `DESIGN_DOCUMENT.md` (master prompt + roadmap), `CLAUDE_PROMPT.md`.

## 1. Requirements restated

The roadmap orders work as **Foundation → Combat toy → Combat ecosystem → World slice → Progression
slice → World-state slice → Narrative slice → Boss**, and says combat must be fun before anything else
exists ("a combat game with an RPG wrapped around it"). This milestone covers the first three phases only:

**Foundation** — project skeleton, resource definitions, input abstraction, save foundation, battle state
machine, CombatSandbox.

**Combat toy** — one protagonist vs one dummy: initiative, Attack, Timing command, Brace/Evade/Parry,
Focus, Stagger, damage previews.

**Combat ecosystem** — Sword/Hammer/Bow, six enemies (+ the slice elite and boss as combat data),
utility AI, intents, statuses (Burn/Wet/Shock/Bleed), two battlefield conditions, one companion, two
familiars, three tactical difficulties, four execution assists, and **automated simulations** with
simulated execution (MISS/GOOD/PERFECT/MIXED) tracking the metrics listed in the GDD.

Hard requirements carried from the GDD (non-exhaustive):

- Deterministic, seeded battle resolution; no battle logic in UI; definitions are Resources and never
  hold runtime state.
- Missed commands never cancel the strategic action (MISS = 0.85x, GOOD = 1.0x, PERFECT = 1.15x + Focus).
- Every enemy ability declares `can_brace / can_evade / can_parry`, always shown as icons.
- Execution Assist and Tactical Difficulty are independent and changeable mid-save; assist never touches
  AI quality, difficulty never inflates stats.
- Tactician AI may not read future inputs or hidden RNG.
- Combat UI shows initiative, intent, enemy HP, Stagger, status, player HP, Focus, companion state,
  environment condition, action preview, reaction availability; ALT shows analysis-layer detail.

## 2. Reusable systems (what everything is built from)

| System | Reused by |
|---|---|
| **Trait** = modifiers + triggered effects | weapon identities, equipment, resonance pairs, companion passive, familiars, statuses, battlefield conditions, enemy species mechanics, buffs/stances |
| **Effect** (typed union, interpreted by `EffectResolver`) | actions, potions, triggers, boss phases |
| **Condition** (typed union, evaluated by `ConditionEvaluator`) | trigger gates, conditional modifiers, enemy action legality |
| **Action pipeline** (`ActionResolver`) | player attacks/techniques/magic/guard/items/inspect *and* enemy actions |
| **Command grader** (pure functions) | all four command widgets, reactions, the simulator |
| **AI considerations** (data, gated by difficulty) | all six roles; role defaults merged into every enemy |

A new weapon, enemy, familiar or condition is data + art; new *code* is only needed for a genuinely new
kind of effect/condition/trigger (one enum value + one `match` branch + a test).

## 3. Architecture

```
            ┌──────────── data/ (*.tres Resources, designer-editable, immutable) ───────────┐
            │ actions, weapons, equipment, enemies, roles, statuses, conditions, balance… │
            └──────────────────────────────┬──────────────────────────────────────────────┘
                                           │ BattleSetup (party loadout + encounter + profiles + seed)
┌──────────────────────── src/battle (pure logic, RefCounted, no Nodes) ─────────────────────────┐
│ BattleEngine — explicit state machine; stops only at PLAYER_SELECT / ACTION_COMMAND /          │
│   REACTION_WINDOW and exposes a typed request; resumes on submit_*().                           │
│ BattleContext — state + config + seeded RNG + event queue (no back-references → no ref cycles). │
│ rules/*  — static, testable functions: damage, modifiers, conditions, effects, triggers,        │
│   statuses, stagger, focus, turn order, intents, reactions, commands.                           │
│ ai/*     — utility scoring, role defaults, difficulty tiers, explanation strings.               │
│ sim/*    — execution simulator, party autopilot, metrics, batch reports.                        │
└───────────────┬─────────────────────────────────────────────────────────────┬─────────────────┘
                │ BattleEvent records (drained)                               │ requests/submits
   ┌────────────▼──────────────┐                                ┌─────────────▼─────────────┐
   │ BattleScene presenter     │  plays events as animation/    │ Simulator / tests / CLI   │
   │ (+ HUD widgets, command & │  VFX/SFX, asks player for      │ answer requests instantly │
   │ reaction widgets)         │  input via widgets             │ (autopilot + skill model) │
   └───────────────────────────┘                                └───────────────────────────┘
```

Autoloads: `EventBus`, `Database`, `Settings`, `GameState`, `SaveManager`, `SceneRouter`, `AudioManager`.
`Settings` is split from `GameState` because settings are global, not per save slot.

### Battle state machine

`BATTLE_START → ROUND_START → ENEMY_DECIDE → ENEMY_TELEGRAPH → (UNIT_START → [PLAYER_SELECT →
ACTION_COMMAND] | [REACTION_WINDOW → REACTION_RESOLVE] → ACTION_RESOLVE → UNIT_END)* → ROUND_END → …
→ VICTORY | DEFEAT`

- **Round-based initiative.** Each round every living unit acts once in Tempo order (ties: party first,
  then unit index). The timeline shows this round and a projection of the next.
- **Intents are declared at ROUND_START** for every enemy (in initiative order, so later deciders can
  build combos on earlier intents) and stay visible until executed. If a target dies the action
  retargets by its target rule; it is never silently swapped for a different action.
- **Channels** (`channel_turns = N`): the enemy spends its activation starting the channel and releases
  after N further activations; the intent shows an hourglass countdown. Breaking Stagger cancels an
  interruptible channel. Story difficulty adds +1 channel turn (more time to answer, same numbers).
- **Stagger/Break.** At 0 Stagger the enemy is Broken: channel cancelled, its next activation is lost,
  it takes ×1.5 damage until it recovers, and its weak point (if any) is exposed. Max Stagger grows
  after each break for bosses (anti-stunlock, data-driven).

### Determinism

All battle randomness goes through one seeded `RandomNumberGenerator` owned by the battle; simulated
execution uses a separate seeded generator so changing a skill profile never shifts battle RNG. The
engine records every submitted input, so `seed + inputs` reproduces any battle (bug repro tool).

## 4. Key data structures (full schemas in `docs/DATA_CONTRACTS.md`)

- `ActionDefinition` — category, focus cost, target rule, damage type, power (flat or ×weapon power),
  stagger, status applications (with `min_grade`), effects, tags (STRENUOUS, IMPACT, …), command.
- `EnemyActionDefinition extends ActionDefinition` — `base_priority, focus cost (resource_cost),
  cooldown, target rule, conditions, role/synergy tags, considerations, can_brace/can_evade/can_parry,
  channel_turns, intent category, telegraph text, signature/rare flags`.
- `ActionCommandDefinition` — type (TIMING/HOLD_RELEASE/RHYTHM/OPTIONAL_AIM), durations, target, Good
  and Perfect window widths in ms, beats.
- `TraitDefinition` — `modifiers: Array[ModifierDefinition]`, `triggers: Array[TriggeredEffectDefinition]`.
- `StatusDefinition` (6 ids, 4 authored) — duration mode (turns / charges), tick damage, cancellation
  rules, traits.
- `BattlefieldConditionDefinition` — severity (major/minor), always-visible explanation, traits.
- `EnemyDefinition`, `CompanionDefinition`, `ProtagonistDefinition` share `CombatantDefinition`.
- `BalanceConfig`, `TacticalDifficultyProfile`, `ExecutionAssistProfile`, `ExecutionSkillProfile` —
  every tunable number lives in data.

Runtime (never Resources): `BattleUnit`, `StatusInstance`, `TraitInstance`, `BuffInstance`,
`EnemyIntent`, `BattleState`, `BattleEvent`, requests/choices. Cross-unit links are unit ids, never
object references.

## 5. Edge cases identified up front

- Target dies before an enemy's declared action → retarget by rule; no legal target → enemy re-decides
  and the change is logged/announced (never a silent different attack).
- Enemy broken before its own activation this round → that activation is the one lost.
- Burn on a Wet target is doused (Wet consumed, no Burn); Wet removes Burn. Equipment may override.
- Shock chains (Flooded Ground) must not re-chain; trigger recursion is depth-limited and chain events
  are flagged.
- Bleed never ticks on non-strenuous actions; it expires after its turn cap so it cannot sit forever.
- AoE enemy attack on both party members → one reaction window applied to every target.
- Intercept redirect when the interceptor is dead/broken → no redirect.
- Assist "auto-Brace" only fills in when the player gave no input; a wrong manual input is still wrong.
- Item used with 0 charges / technique without Focus / cooldown → illegal option with a visible reason.
- Battle that never ends (two healers vs no damage) → safety cap `max_rounds` ends sims as a timeout.
- A mandatory-feeling channel must be survivable if not interrupted (validated by simulation).

## 6. Dependencies

None outside Godot 4.7.x. No addons (test runner and simulator are in-repo). Headless runs need one
`godot --headless --import` on a fresh checkout to build the class cache.

## 7. Non-goals (explicitly not in M1)

Overworld/zones, Gloamstead hub, quests/rumors, puzzles, regional Pressure and corruption choices, Forge /
Stillroom / Observatory UIs, alchemy crafting, loot drops, mastery unlock trees, narrative, music, final
art. Chill and Blight behaviour (enum values reserved only). The data model leaves room for all of these,
but none is implemented here.

## 8. Provisional content (flagged for Director review)

The GDD names systems but not every number or creature. M1 ships **provisional** content so the combat
can be played and simulated; every item is data and can be replaced without code. See
`docs/DESIGN_QUESTIONS.md` for the decisions that need the Director's call.
