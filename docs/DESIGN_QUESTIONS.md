# Design Questions for the Director

Owner of the answers: ChatGPT (Game Director). Raised by: Claude, from implementation and from
batch simulation (M1). Every item below is **data** in `data/**` — answering it needs no code change
unless stated. Numbers come from `tools/simulate.gd` (50–60 battles per cell, SMART autopilot,
STANDARD assist unless stated); the simulator approximates human execution, so treat them as
evidence for playtests, not verdicts.

Execution profiles: **MISS** = never lands a command or reaction, **GOOD** = reliable, **PERFECT** =
expert, **MIXED** = realistic spread. Round targets (GDD): normal 3–5, elite 4–7, boss 7–13.

---

## Q1 — Spore Fog without Blight
The slice lists *Flooded Ground* and *Spore Fog*; the GDD defines Spore Fog as "Blight accumulates
gradually", but Blight is not one of the slice statuses (Burn, Wet, Shock, Bleed).
**M1 (provisional):** Spore Fog is a *minor* condition: "the first Burn applied each round ignites the
spores: 8 Fire damage to every other unit on the burning target's side".
**Options:** (a) keep this version for the slice (uses slice statuses, rewards Burn and positioning);
(b) bring Blight into the slice; (c) another minor rule.
**Recommendation:** (a), revisit with the corruption milestone.

## Q2 — "Perfect Parry" with pass/fail reactions
The GDD writes "after Perfect Parry" (Bell Crow) and "Perfect protagonist parries" (Mara). Reactions
are graded pass/fail; a successful Parry already needs the tightest window (150 ms at Standard).
**M1:** Bell Crow fires on any successful party Parry (12 Stagger, once per round); Mara gains 2 Focus
when the Hollow Parries.
**Options:** (a) keep binary reactions; (b) two-tier Parry (Good = partial, Perfect = full + triggers),
which costs another HUD state and a second tuning axis.
**Recommendation:** (a).

## Q3 — Normal fights cannot be lost in isolation
With **MISS** execution the party still wins nearly every normal encounter; execution changes *how
much it costs*, not *whether* it is won:

| Encounter (Adventurer) | Win % MISS (Sword / Hammer / Bow) | Damage taken MISS vs MIXED (Sword) |
|---|---|---|
| Fen Patrol | 100 / 100 / 100 | 166 vs 58 |
| Rot Grove | 100 / 100 / 100 | 135 vs 27 |
| Mire Shrine | 100 / 100 / 100 | 128 vs 49 |
| Thornhound Pack | 98 / 74 / 86 | 196 vs 58 |

Elites and the boss do require execution (Bramble Den MISS: 94 / 50 / 54 %; Mirebell Cantor MISS:
0 / 40 / 2 %). M1 has no expedition, so HP does not carry between fights.
**Question:** is expedition attrition (HP, potions and Focus carried through Briarfen) the intended
pressure for normal fights? If yes, nothing changes now; if every fight must be losable on its own,
enemy damage needs to rise (one number per enemy action, or `BalanceConfig`).

## Q4 — Tactician is only harder for weak execution
Hard-mode test: "Tactician enemies appear smarter without inflated HP." Stats are identical across
tiers and the AI visibly behaves differently (focus fire, combo setups, avoiding channels the party
can break, adapting to reactions it has *seen* succeed). But outcomes barely move unless execution is
poor:

| Bramble Den (elite) | Story | Adventurer | Tactician |
|---|---|---|---|
| Hammer, MISS — win % | 30 | 25 | 17 |
| Bow, MISS — win % | 67 | 63 | 38 |
| Sword, MIXED — win % / damage taken | 100 / 78 | 100 / 76 | 100 / 67 |
| **Mirebell Cantor (boss)** | | | |
| Sword, MISS — win % | 43 | 0 | 0 |
| Bow, MISS — win % | 47 | 3 | 0 |
| Hammer, MIXED — win % / damage taken | 100 / 104 | 100 / 111 | 100 / 94 |

Story is a strong accessibility lever (it extends channels and avoids stacking lethal attacks);
Adventurer → Tactician changes little once execution is decent.

Cause: enemy kits are small (2–4 moves), so better choices have little room to matter, and one good
reaction cancels most of any single plan.
**Options:** (a) give elites/boss one more Tactician-relevant tool each (a setup→payoff pair, a feint
that punishes the most-used reaction); (b) Tactician-only considerations, e.g. hold a channel until the
party lacks the Focus to break it; (c) accept: Tactician is "smarter", difficulty comes from
execution. No stat inflation in any option.

## Q5 — Perfect execution takes almost no damage
PERFECT runs take 2–24 damage per fight (MIXED: 27–120). Successful Evade and Parry negate 100%;
Brace removes 40%. This matches the Mario & Luigi lineage, but an expert can largely skip defensive
tactics (Guard, Intercept, potions).
**Options:** (a) keep (skill is the reward); (b) leave chip damage on Evade (e.g. 10%,
`evade_success_multiplier`); (c) more moves that only allow Brace, or that hit both party members.
**Recommendation:** decide after human playtests; all three are data.

## Q6 — Content that never appears
"AI NEVER USED" across 12 batches per encounter:

| Move | Never used in | Cause |
|---|---|---|
| Fen Wisp *Arc Storm* | 12 / 12 | the wisp dies in round 1 in 67 of 90 sampled Fen Patrols (it cannot afford the 2-Focus storm then); when it survives, *Static Lash* scores ×2 against a soaked target — nearly always true on Flooded Ground — and beats the storm's flat 1.2 |
| Bogwife *Cleansing Mire* | 12 / 12 | cleanses ally statuses; starter loadouts rarely inflict any |
| Sporecaller *Needle Hum* | 12 / 12 | its basic attack scores below the buff and Sporeburst every turn |
| Bogwife *Moss Mend* | 9 / 12 | heals only when justified (as the AI test requires); burst damage rarely leaves a target worth saving |

Party side (autopilot, not players): Spark and Kindle (magic), Riposte Stance, Guard, Intercept, Fen
Water Flask and Focus Tincture are rarely or never chosen.
**Proposals (data only):** give Arc Storm its own consideration (e.g. ×2 when two or more party
members are Wet) or a cost of 1; Needle Hum `base_priority` 1.0 as the Sporecaller's fallback; keep
Cleansing Mire situational. Magic and stances need human
playtests — the autopilot cannot value setup moves the way players do.

## Q7 — Encounter length
At MIXED execution: normal fights 3.5–5.6 rounds; Sword and Bow in the flooded fights run 5.2–5.4
(slightly over 3–5) while Hammer clears them in 3.7–3.9; Rot Grove is the reverse (Sword 4.4, Hammer
5.5). Elite 5.8–6.4 (target 4–7). Boss 10.8–12.1 (target 7–13, Sword near the top).
**Question:** with commands and reactions each round, are 5–6 round normal fights acceptable? The
loadout spread itself looks healthy (Build test: different weapons win different fights fastest;
Hammer suffers against Bleed-inflicting Thornhounds — 74 % vs 98 % for Sword at MISS — as designed).

## Q8 — Crossed-out reaction keys are inert (UX)
D-008 said a disallowed reaction "counts as no reaction". In the UI that turned one visible mis-press
into a lost turn, so M1 ignores crossed-out keys (the first *allowed* key still locks the choice).
**Please confirm** — or prefer "any key locks", which is stricter.

## Q9 — Gamepad defaults (UX spec wanted)
M1 defaults: confirm A, back B, command A or X, Brace LB, Evade X, Parry RB, details Y, log Back,
pause Start. Evade and command share X because they never overlap in time.

## Q10 — Smaller calls made during implementation (veto if needed)
- Party Focus starts at 2, enemies gain +1 per activation and pay for big moves with it.
- A party ambush lets the party act first in round 1 and removes 25 % of every enemy's Stagger; an
  enemy ambush lets the enemies act first in round 1.
- Inspect reveals research level UNDERSTOOD for the rest of the battle (numbers, move names, "why").
- Status names and icons are always visible; exact damage numbers of enemy intents unlock at
  UNDERSTOOD; weaknesses at STUDIED (or once a hit reveals them).
- Training Yard dummy (*Straw Penitent*) exists for the combat toy and the sandbox only.
