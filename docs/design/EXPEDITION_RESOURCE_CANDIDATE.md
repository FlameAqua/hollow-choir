# Expedition resource boundary — candidate A

**Director draft, 8 October 2026. Paper evaluation only; not approved for implementation.**
This answers the design question in D-024 with a concrete candidate to compare, not a declaration
that the expedition loop exists. [M1.1 combat clarity](M1_1_COMBAT_CLARITY.md) remains the gate.
It does not authorize world maps, encounter chains, economy, camps, new potions or a save rewrite.

## Feature review

| Required question | Candidate answer |
|---|---|
| Player-facing purpose | Let a short excursion contain a visible supply decision without turning every mistake into a worsening HP deficit. |
| Decision created | Spend a limited potion charge to solve this fight, keep it for a later known threat, or return to regroup. Never require taking avoidable damage to make an encounter matter. |
| Systems touched | PartyLoadout's two shared potion slots, PotionDefinition capacity, battle setup/result boundary, progression save boundary, future expedition owner, result/setup UI. Existing action costs and reactions stay intact. |
| Implementation cost | **Medium**, despite the small rule: charge input/output, stable slot identity, idempotent result application, boundary save/resume, and UI copy. No reliable schedule estimate until Claude reviews the interfaces. The all-reset control is cheaper. |
| Likely failures/exploits | Potion hoarding; return/re-enter refill farming; duplicate result application; slot swapping to refill; retry yielding both supplies and rewards; inaccessible recovery from defeat; treating current automatic fresh battles as already persistent. |
| Cheaper reuse | First test the current full-reset encounters with clear threat/condition information. If these already make preparation and adaptation satisfying, retain full reset and reject persistent supplies. Reuse existing charges/actions for any later trial; do not add durability, hunger, wounds or a second inventory. |

## DESIGN INTENT

Preserve the pleasure of mastering a fight while investigating one resource that could connect
several meaningful fights. Separate tactical damage inside combat from a possible excursion budget.
This candidate deliberately makes no claim that normal encounters need attrition to be worthwhile.

Compare **control C: everything resets**, **candidate A: only potion charges carry**, and
**alternative B: HP and potion charges carry**. Focus and temporary effects reset in all three.
Prefer C unless A produces a visible useful decision that C cannot. B adds healing/defeat/recovery
pressure and more persistence state; reject it for the first trial unless direct evidence requires it.

## PLAYER EXPERIENCE

“We can regroup after this fight. Our bodies recover and Focus starts fresh, but I have one draught
left for this excursion. I can attempt the next threat or go home and change my preparation.”

Regroup is a boundary explanation, not a timed healing activity, click-to-heal chore or new camp.
Coming home should invite a different preparation, not an entrance fee or a compulsory grind.
The refill fiction and wider alchemy economy are unresolved; free departure capacity below is a
trial rule, not a canonical replacement for future recipe acquisition or material costs.

## RULES

1. **Departure:** resolve a valid loadout using existing definitions. Snapshot two slot identities
   and their potion IDs/capacities. Each occupied slot starts at its definition's charge capacity;
   an empty slot has zero charges. Slot identity is the index, not merely potion ID.
2. **Next battle:** party starts at full HP; Focus uses the existing configured starting value.
   Clear statuses, buffs, Stagger, channels, intercepts, timing state and battle/round trigger counters.
   Preserve only the candidate's remaining potion counts. Do not carry player or enemy runtime nodes.
3. **Within battle:** a legal committed potion action consumes its existing major action and charge
   under current rules. Preview, back, invalid selection and opening details consume nothing.
   There is no outside-battle potion action in this candidate; HP already recovers at the boundary.
4. **Victory:** apply ending potion counts to the matching departure slots once. A downed party member
   also recovers to full at the next battle; there is no injury or resurrection fee. Do not revive a
   downed ally during the still-running battle or change current defeat detection/healing rules.
5. **Preparation:** keep the loadout fixed during this trial excursion. Return home to change weapon,
   armor, companion, familiar or equipped potion. This bounds max-HP and slot-remapping questions;
   it is not a permanent ban on future field equipment changes.
6. **Return:** between battles, returning ends the excursion and permits re-preparation. It has no
   real-time cooldown, supply fee or hidden pressure increment in the trial. Starting another
   excursion grants that departure's capacities. Re-entering a route must not duplicate one-time
   rewards; reward respawn and pressure rules need a separate approved world contract.
7. **Defeat:** offer retry of the same encounter from its captured entry state (including entry
   charges and seed), or return home. A retry discards the failed attempt's candidate outputs;
   a failed attempt cannot both restore its charges and permanently award its progression.
   This requires future coordination with progress recording, not a change to M1 practice now.
8. **Suspend:** support a between-battle save boundary for a future trial. A mid-battle app exit
   returns to the captured encounter-entry state on resume, with that behavior stated in advance.
   No mid-command snapshot, punitive supply loss or anti-save-scumming subsystem. Commit successful
   outcome, progression and remaining charges together before advancing to the next boundary.
9. **Failure recovery:** reject mismatched slot IDs, out-of-range charges or duplicate outcome tokens
   without silently refilling. Resume the last valid boundary and show a plain recovery message.
   Never apply a partially valid result. Future implementation must demonstrate this behavior.

## UI REQUIREMENTS

At departure, show each potion's **uses for this excursion** and the rule “HP and Focus reset between
fights. Potion uses refill when you depart from home.” Do not mix an inventory stack count with uses.
After a victory, show remaining uses and “Party recovers before the next fight.” Offer Continue /
Return at a future route boundary; neither needs a new progression dashboard.

At retry, show that the encounter restarts with its entry supplies. At return, state the actual known
route consequences; do not imply unspecified pressure, lost loot or a deadline. If the route has no
approved consequence rules, it is still a test harness, not a shippable world loop.

## DATA REQUIREMENTS

Existing `PartyLoadout` and `PotionDefinition` describe capacities and actions; `PotionSlotState`
holds live battle charges. `BattleSetup` currently has no starting-charge override, and `BattleResult`
does not export ending charges. Loading a preset today therefore does **not** test this candidate.

Proposed minimal boundary values (conceptual, naming for engineering review):

| Value | Shape / invariant |
|---|---|
| Trial identity | excursion ID and a monotonically advancing boundary index; no gameplay meaning |
| Departure loadout | resolved definition IDs plus two indexed slots `{slot_index, potion_id, capacity}`; immutable during excursion |
| Entry state | remaining charges for each slot, encounter ID, actual seed, difficulty/assist references; HP/Focus derive from existing rules |
| Completion | unique encounter-attempt token, outcome, ending charges keyed by slot; existing BattleResult progression fields remain the source of rewards |
| Applied boundary | last accepted completion token and next entry state written with progression; replaying a token does not re-award or refill |

An absent override means legacy fresh-battle behavior; an explicit count of zero means **empty**,
not “use the default.” Validate potion ID, slot index and capacity against the departure snapshot.
Do not serialize mutable Resources, engine/presenter nodes or duplicate a second progress system.
Older saves without an active excursion return to the existing home/default boundary.

## BALANCE PARAMETERS

For comparison only: two shared slots; current Mending Draught 2 × 45 HP, Fen Water Flask 2 uses,
Focus Tincture 1 use and Clotting Salve 1 use. Keep every existing action cost, effect, starting
Focus value and reaction window. No item pickup/refill mid-excursion in the initial candidate.

Use a **paper route** of the existing Fen Patrol → Rot Grove → Bramble Den definitions. This is an
evaluation fixture, not an approved authored route or a promise of its elapsed duration. Compare
stated decisions with and without carried supplies. Do not substitute summed simulation damage for
remaining HP: damage events can include overkill, and the audit contains fresh independent fights.

Before coding, ask players to explain the boundary rule from the proposed copy and choose a supply
plan against disclosed threats. This can reject confusing/pointless rules; it cannot prove play feel.
After M1.1 passes, a separately authorized playable trial would need evidence of changed potion/return
decisions, comprehension and tolerable replay cost. If it only encourages hoarding or adds bookkeeping,
retain control C. No exact win-rate target or new difficulty multiplier is proposed.

## EDGE CASES

- Two copies of the same potion retain independent indexed counts; if current loadout validation
  disallows that loadout, do not loosen it for this feature. Empty slots cannot acquire charges.
- A survivor wins after their partner drops: partner returns next fight; all spent charges remain spent.
- A zero-charge battle must remain playable through existing actions. No mandatory potion lock/key.
- Defeat after using the last draught: retry restores the captured entry count, not the departure max.
- Return and re-depart can refill. This is an intentional trial affordance; measure whether it creates
  repetitive travel. Do not “fix” it with a new toll or real-time timer.
- Save/close during result application must yield either the old complete boundary or the new complete
  boundary, never new progression with old supplies. Suspend/resume must not become an item generator.
- Lab and Practice stay isolated fresh battles unless an explicit future expedition harness is used.
  No dependency on or mutation of a player's campaign save for testing.
- Pressure, loot respawn, quests, corruption choices, route completion and alchemy material consumption
  remain separately unspecified. This candidate cannot approve **AFFECT THE WORLD** by itself.

## ACCESSIBILITY REQUIREMENTS

No time limit on supply/return decisions. Counts must have text labels, be readable at enlarged text,
and work with keyboard/controller focus. Difficulty and assist never secretly change refill rules.
Retry requires no execution challenge or penalty payment. Explain suspend behavior in normal language.
No essential distinction relies on color, sound or a tiny empty-bottle icon.

## ACCEPTANCE TESTS

These are future trial requirements, **not tests passed by M1**.

| ID | Given / when | Required result |
|---|---|---|
| E01 | Depart with Mending 2 and Fen Water 2; use one Mending; win | Next battle starts full HP, default starting Focus, Mending 1 and Fen Water 2. |
| E02 | One party member down at victory with Wet/Bleed and temporary buffs present | Next battle both recover; statuses/buffs and trigger counters reset; spent potions do not refill. |
| E03 | Entry Mending 1; spend it and lose; retry | Same entry seed/supplies (1, not 0 or 2); no failed-attempt permanent reward is applied. |
| E04 | Entry slot explicitly has zero charges | Setup preserves zero and disables that use with a readable reason; fight remains playable. |
| E05 | Preview/cancel an item; then apply one legal potion action | Preview/cancel spend nothing; successful commit consumes exactly one charge under existing rules. |
| E06 | Apply the same victorious completion twice | Supplies/progression/route advance once. |
| E07 | Change a slot or loadout during an active trial | No silent change/refill; return/re-prepare is the available path. |
| E08 | Interrupt saving at the result boundary and resume | One complete valid boundary; no mixed rewards/supplies and no duplicated victory. |
| E09 | Return after one fight and start another excursion | New departure capacities; prior one-time reward cannot be re-awarded by this action. World reward contract still required. |
| E10 | Current Practice/Lab or old save has no expedition state | Existing fresh-battle behavior is preserved; no invented active excursion. |
| E11 | A player reads departure/result copy using their chosen access settings | Can distinguish HP/Focus reset from carried potion uses and explain retry/return before committing. |

## Claude handoff — hold until combat gate

### IMPLEMENTATION BRIEF

Review the boundary feasibility only. No implementation is requested by this draft. After human
combat validation, Director must choose control C or authorize a minimal candidate-A trial explicitly.

### DATA CONTRACT

Use the table above: optional starting counts, ending indexed counts, immutable departure identity,
and one atomic applied-result boundary. Preserve legacy null/default behavior and explicit zero.

### STATE FLOW

Home → depart → entry boundary → battle → victory commit → next boundary or return.
Defeat → retry captured entry or return. Suspend during battle → resume captured entry.
These are proposed orchestration boundaries, not new internal battle engine states.

### ACCEPTANCE TESTS

E01–E11; current deterministic combat and isolated Sandbox behavior must still pass.

### KNOWN EDGE CASES

Duplicate IDs/tokens, empty slots, death/retry, changing definitions after a save, interrupted writes,
and campaign progression that currently records outcomes differently. Report conflicts before coding.

### NON-GOALS

No implementation now; no world slice, pressure economy, potion crafting, camp system, injury,
durability, inventory expansion, enemy content, mid-command save, compulsory attrition or live service.
