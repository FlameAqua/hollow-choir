# M1 Director audit — does choosing actions change outcomes?

**Director analysis, 8 October 2026 (local date). Completed simulation evidence; no human testing.**
**Source:** `455ec506fd7c75d6edbf5fe5c1dd6b5725767118`, Godot
`4.7.2.stable.official.ed1daf0bf`. No production code, encounter data or balance values changed.

**Decision:** retain M1 tuning and finish combat clarity first. Basic attacks plus competent
automated defense won every sampled normal fight. Broader action selection helped in the elite/boss
fixtures, particularly the Sword build against Mirebell Cantor. The next human test must establish
whether players see and value those choices. Neither result establishes that combat is fun or dull.

## Evidence package and method

- [Manifest: settings, seeds, provenance, hashes, reproduction arguments](data/M1_DIRECTOR_POLICY_AUDIT/manifest.json)
- [All 24 matched cells and policy differences](data/M1_DIRECTOR_POLICY_AUDIT/comparison.csv)
- Unmodified tool exports: [SMART](data/M1_DIRECTOR_POLICY_AUDIT/smart.json),
  [BASIC_ONLY](data/M1_DIRECTOR_POLICY_AUDIT/basic_only.json),
  [RANDOM](data/M1_DIRECTOR_POLICY_AUDIT/random.json).

Each policy ran 4 encounters × 3 starter builds × 2 difficulties × 100 seeds: **2,400 battles per
policy, 7,200 completed battles**. Encounters: Fen Patrol, Rot Grove, Bramble Den, Mirebell Cantor.
Builds: Starter Sword/Hammer/Bow. Execution: Mixed. Assist: Standard. Difficulties: Adventurer and
Tactician. No research override; the CLI starts with an empty research-level map. Every fight is fresh.

Base seed 23 expands to `23 * 100003 + run_index * 7919 + 17`, indices 0–99: first battle seed
2,300,086; last 3,084,067. The same starting sequence is used in each cell. Autopilot RNG uses
battle seed +1; executor RNG uses +2. Different choices change later random consumption, so these
are matched starting conditions, not identical roll-by-roll outcomes or paired statistical estimates.

All three final commands exited successfully, produced 24 rows of 100 runs, and emitted no script
errors. Initial SMART/RANDOM attempts hit a 240-second **shell** cap before report export; those
partial logs were excluded. Complete reruns used a 900-second shell cap. Engine battle timeouts
inside completed runs are retained as outcomes below; they are not missing samples.

## What the policies actually test

| Policy | Chooses actions / targets | What it does not represent |
|---|---|---|
| SMART | Existing heuristic values direct damage, kills, Stagger/interrupts, healing, Focus and selected status benefits. It reads exact engine previews. | An optimal player, a knowledge-limited player, or reliable valuation of every setup stance. |
| BASIC_ONLY | First legal Focus-generating basic attack, aimed at the legal target with lowest absolute HP; fallback to first legal option if needed. | No tactics at all. Concentrated targeting and the full defense model remain active. |
| RANDOM | Random legal action option and random target. | A beginner. It can waste turns on inappropriate setup, Inspect or Guard. |

**Defenses are shared across all three policies.** ExecutionSimulator selects a legal response by
expected immediate hit damage with a small Parry Stagger credit; it then rolls modeled success.
It does not plan around Wet→Shock, future status harm or every build synergy. The experiment changes
action selection, not reaction intelligence. Mixed base offensive weights are Miss .25 / Good .55 /
Perfect .20; base reaction success is Brace .88 / Evade .60 / Parry .25, subject to window modifiers.
Offensive execution is a probability model, not a measurement of human command timing or device latency.

Starter builds vary armor, familiar and potion slots as well as weapons. Treat their differences as
**build** differences. The [human pack](../playtests/M1_1_SESSION_PACK.md) specifies weapon-only swaps
to hold the other parts fixed. SMART versus BASIC_ONLY also changes healing and target selection;
it does not isolate the causal contribution of Focus techniques alone.

## Results

Each table row pools six equally sized cells (three builds × two difficulties), **600 battles**.
Mean rounds include defeats/timeouts. The linked CSV retains every build/difficulty result so pooled
figures cannot hide an unfavorable matchup. No confidence or statistical-significance claim is made.

| Encounter | SMART wins | BASIC_ONLY wins | RANDOM wins | Mean rounds SMART / BASIC / RANDOM |
|---|---:|---:|---:|---|
| Fen Patrol | 100.0% | 100.0% | 71.0% | 4.82 / 4.92 / 12.08 |
| Rot Grove | 100.0% | 100.0% | 78.2% | 4.92 / 5.02 / 12.74 |
| Bramble Den | 100.0% | 94.5% | 38.0% | 6.28 / 7.29 / 15.21 |
| Mirebell Cantor | 99.2% | 88.8% | 14.0% | 11.22 / 11.92 / 23.54 |

Totals: SMART **2,395/2,400** victories, BASIC_ONLY **2,300/2,400**, RANDOM **1,207/2,400**.
SMART and BASIC_ONLY had zero engine timeouts. RANDOM had **55/2,400**, with a maximum 12% in
one cell. Random's high rounds reflect poor legal choices and the battle cap, not intended pacing.

| Encounter | Mean recorded party damage SMART / BASIC / RANDOM |
|---|---|
| Fen Patrol | 56.36 / 56.69 / 196.35 |
| Rot Grove | 45.51 / 52.09 / 186.31 |
| Bramble Den | 87.80 / 102.72 / 254.28 |
| Mirebell Cantor | 105.13 / 124.27 / 254.85 |

Recorded damage sums DAMAGE event amounts and can include overkill. It is neither final missing HP
nor an expedition attrition forecast. Healing is reported separately in the CSV; subtracting these
aggregate means cannot reconstruct survivors or a particular battle state.

### Findings that affect the next review

1. **Normal-fight wins do not separate basic and broader action selection here.** Across both normal
   encounters, all 12 cells in each of SMART and BASIC_ONLY had 100/100 wins. The pooled speed gain
   is only about 0.1 round per encounter. SMART Sword is actually 0.18–0.20 rounds slower in Fen
   Patrol. Ask humans why they spend Focus; do not assume victory proves its value or absence.
2. **Harder fixtures show a reason to inspect existing options.** SMART beats BASIC_ONLY's win rate
   in all six Bramble Den cells and five of six boss cells; the remaining boss cell ties at 100%.
   Sword boss wins rise from 72→97% on Adventurer and 77→100% on Tactician. Basic Hammer already
   wins 97/100 and 100/100 respectively. A blanket damage increase would address unlike cases alike.
3. **SMART is not superior on every metric.** Its mean recorded damage is higher in six matched
   cells, including both Hammer boss cells (+11.96 and +6.11), despite equal/better wins and faster
   completion. It uses healing and other actions that BASIC_ONLY never selects. Judge whole outcomes;
   do not label one build or policy universally dominant from the headline wins.
4. **Pacing needs human time data.** Seven of twelve SMART normal cells exceed the 5-round upper
   target (eight with BASIC_ONLY). Rounds cannot tell whether thinking, command input or playback is
   the problem. The separate ten-fight timing pass is still required; no seconds were measured here.
5. **Underused actions need diagnosis, not additions.** Across SMART's 2,400 fights, Mending Draught
   appears 1,850 times, Condemn 793, Intercept 228, Guard 105, Steady Aim 48 and Anchor Stance 3.
   Riposte Stance, Spark and the three other potion actions receive zero uses. These are counts
   of uses, not percentages of battles or opportunity-adjusted preference rates. The heuristic poorly
   values some self-setup actions; this cannot justify deleting them or buffing them automatically.
6. **Tactician is not proven harder by these results.** Pooled wins are slightly higher on Tactician
   for every tested policy: SMART 100.00 vs 99.58%, BASIC_ONLY 95.92 vs 95.75%, RANDOM 52.00 vs
   48.58%. These small/differing gaps are descriptive, not significance claims. Review actual
   telegraphed decisions against human play before revising difficulty behavior. Assisted was not
   tested in this audit, so no claim that it preserves or erases tactics follows from it.

## Pillar review and action

| Pillar | Evidence / limit | Next bounded action |
|---|---|---|
| READ | Exact-preview autopilot bypasses human comprehension and research uncertainty. | Implement M1.1's public threats and honest knowledge filtering; run uncoached R1. |
| REACT | All policies share the same response chooser/probability model. | Test actual cues, fresh presses and chosen assists in Training Yard. Keep zero-damage success. |
| ADAPT | Elite/boss outcomes benefit from broader policy; normal wins do not distinguish it. | Observe whether condition, channel, Focus or survival changes a player's action; log the reason. |
| EXPERIMENT | Build matchups differ, but weapon/familiar/armor changes are confounded. | Run controlled weapon-only swaps with existing content; no new weapon or status. |
| AFFECT THE WORLD | Every run resets; no route state or world consequence is tested. | Keep deferred. Evaluate the separate resource candidate on paper only. |

The player-facing purpose of this work is to make useful choices understandable. It adds **no
player mechanic**. Implementation cost now is the already-approved UI work plus moderated testing;
existing presets, action policies and CSV sheets provide the evidence more cheaply than new encounters
or telemetry. Main failure risk: optimizing the game for the autopilot instead of the player.

## Reproduce

Use Godot 4.7.2 from the repository root. The cloud checkout can activate its retained environment
with `source /workspace/.hollow-choir-env/activate`; on another machine use its installed Godot binary.
The command below overwrites only these generated report files. It can take several minutes.

```sh
for policy in smart basic_only random; do
  godot --headless --path . --script res://tools/simulate.gd -- \
    --encounter=fen_patrol,rot_grove,bramble_den,mirebell_cantor \
    --loadout=starter_sword,starter_hammer,starter_bow \
    --exec=MIXED --difficulty=ADVENTURER,TACTICIAN --assist=STANDARD \
    --policy="$policy" --runs=100 --seed=23 \
    --out="res://docs/reports/data/M1_DIRECTOR_POLICY_AUDIT/$policy.json"
done
```

Compare parsed numeric reports at the recorded source revision, not serialized key order. Regenerate
the comparison/manifest if reporting new results; don't relabel this evidence as a later build.
Simulator JSON lacks policy/base seed in its labels, which is why the manifest is required.
Its p90 is the zero-based `floor(n*0.9)` element (91st of 100) and median uses the upper middle;
the human pack deliberately defines nearest-rank p90 separately. Per-run observations, Focus spent,
remaining HP, human duration and input errors are not present in these aggregate exports.
