# M1 Director review

7 October 2026 • Reviewed baseline `f3d13f1` plus current checked-out sources.
**Verdict: retain the combat architecture; require a clarity pass before milestone expansion.**
The M1 report establishes an implemented foundation, not a human-validated combat experience.

Sources: canonical GDD; all eleven Design Questions; Decision Log D-001–D-016; M1 proposal,
feature report and simulation report; Data Contracts; Testing; combat presenter/widgets, preview
rules, reaction rules and representative authored content. No external research claims were reverified.

## Pillar assessment

| Pillar | Assessment | Evidence and implication |
|---|---|---|
| READ | Mechanically supported; presentation gate open | Intent/preview data exists, but tiny labels, knowledge leaks and competing hover detail obstruct understanding. Automated presence of a log is not the Information test. |
| REACT | Functional foundation; physical usability unverified | Three reusable commands, binary reactions and independent assist already exist. Confirm carry-through, unavailable actions, focus loss and device cues need explicit acceptance. No live human/hardware test this session. |
| ADAPT | Promising simulation evidence | Flooded Ground changes Evade; Hammer wins flooded fights faster but suffers under Bleed. Explain these interactions in the primary view before retuning them. |
| EXPERIMENT | Architecture strong; decision diversity unproven | Traits reuse rules; no universal loadout winner in reported samples. SMART's unused stances/magic do not establish useless player options. Require controlled human comparisons. |
| AFFECT THE WORLD | Intentionally not assessable in M1 | No expedition/world state is implemented. Do not add fake regional rewards or approve the world slice based on combat simulation. |

## Findings to act on

| Priority | Finding | Source | Required response |
|---|---|---|---|
| P0 | Unknown affinities leak through “Weakness?” / “Resisted?”, exact values and analysis | `src/ui/battle/preview_panel.gd`, `src/battle/preview/preview_rules.gd` | One knowledge policy gates every derived disclosure; preserve exact engine calculations. |
| P0 | Preview implies more certainty than it proves | PreviewRules uses `calculate_hit`, a single target and unconditional `applied_statuses`; displayed break/kill uses Good | Label direct-hit scope; suppress unsupported aggregate/grade-dependent promises. A prediction simulator is out of scope. |
| P0 | Reaction and intent readability is structurally cramped | IntentBubble fixed 184×48, reaction glyphs 11×10, theme base 15 with 0.5–0.75 multipliers | Larger named responses and fixed intent slots; test four enemies and scaled text. This is a source finding, not a captured screenshot observation. |
| P0 | Mouse movement can displace action evidence | `BattleScene._refresh_info()` prefers hovered unit over picker preview | Explicit Details mode preserves action/target context for every device. |
| P1 | Identity art has no runtime hookup | `CombatantDefinition.sprite_frames` exists; UnitView draws only silhouettes | Use existing optional field and generic event transforms; retain fallback. |
| P1 | Presentation can reveal future Focus/status state | M1 report known limitation; UnitView reads live unit statuses/Focus while HP/Stagger have ledgers | Reuse event ledger and reconcile together. |
| P1 | Sandbox exposes a developer form as first experience | `CombatSandbox` includes seed, knowledge, execution and equipment overrides in one drawer | Practice/Lab views of the same setup, no new encounter system. |
| P1 | Pause availability and focus-loss behaviour need a contract | `_unhandled_input` opens pause only in planning; widgets grade wall time | State safe manual pause points; queue during timing, freeze elapsed time on focus loss, test held input. |
| P2 | Art source is directionally useful, not final pixel production | New generated atlas has irregular packing and partial alpha | Staged atlas resources + explicit cleanup gate; no claim of completed animation. |

See [the approved specification](../design/M1_1_COMBAT_CLARITY.md) for rules and feature cost/reuse review.

## Balance judgement

Keep current numbers for this pass. Reported 50–60-run cells support hypotheses, not causal findings:
they use an omniscient heuristic and approximate input distributions. Assisted halves damage in several
reported cells; similar break counts do **not** prove equivalent tactical decision quality.
Different initiative, party actions and reaction policies may explain Tactician outcomes, so no inference
that it must be harder in every individual seed is justified.

Normal encounters should teach/test a decision, not merely consume expedition resources. The GDD's
3–5 round target stays; 5–6 is a pacing investigation, not a newly approved norm. The world design
has not yet specified HP/potion carry and Focus reset at expedition boundaries; do not silently lock
all three as persistent or use future attrition to excuse a dull fight.

Keep zero damage on successful Evade/Parry. Do not punish demonstrated mastery with forced chip,
unannounced feints or blanket unparryable attacks. First determine whether timings are humanly readable
and whether tactics still change. No new Tactician action is approved.

## Review evidence and limits

The current Godot **4.7.2** headless UI suite was run during this review:
**18 tests passed, 0 failed, 78 assertions**. This verifies existing automated UI flows only.
Claude's report says the original full suite passed 120 tests; that is historical evidence, not a new
full-suite result. Historical simulation tables were read, not regenerated or silently retuned.

New art validation: Godot 4.7.2 import completed without script/engine errors on the verified rerun;
all six SpriteFrames loaded, each with one idle frame, valid atlas texture and in-bounds region.
The backdrop loaded at 1672×941. Local Markdown links and `git diff --check` pass.
The first import hit an environment socket restriction after importing; the rerun used the needed
local socket capability and completed cleanly. No production script or combat data was changed.

The environment has no display server. There was no live graphical Godot playtest, controller test,
input-latency measurement, or fresh-player comprehension test. The supplied visual study is an authored
design artifact. Import/load validation cannot establish artistic quality or runtime integration.

Presentation artifacts finalized on **8 October 2026**: planning, reaction and Practice HTML fixtures
were rendered at 1280×720 through a headless browser and visually inspected. Review corrected clipped
Stagger labels, inconsistent actor/selection state and the Practice progress-recording notice's fit.
Screenshots are under `docs/design/visuals/`; they depict the proposed UI, **not the running Godot build**.
Enlarged-text and gamepad acceptance remain future implementation checks. Resource loading and
Markdown links were also rechecked successfully on resumption.

## Next gate

Claude implements the [bounded handoff](../briefs/M1_1_IMPLEMENTATION.md), verifies focused regression
cases, then runs the five-person human rubric in the specification. Passing functional tests is
necessary; passing the READ/REACT comprehension gate is what permits additional content work.
