# M1.1 — Combat playtest pack

**Director preparation, 8 October 2026. Status: protocol, not completed testing.**
Authority: [combat clarity specification](../design/M1_1_COMBAT_CLARITY.md).
Evidence prompting the action-choice probes: [policy audit](../reports/M1_DIRECTOR_POLICY_AUDIT.md).

## Purpose and readiness

Find whether a player can read a threat, deliberately respond, and change a plan because of the
rules. Five fresh participants give directional evidence; they do not establish population rates.
No recruitment, playtest, accessibility verification or timing measurement has happened in this pack.

The current Godot build can supply a **baseline** through Combat Sandbox. The staged art and HTML
study are not the running game. Run the same protocol on the integrated M1.1 build before granting
its gate. Record exact commit and phase (`baseline` or `candidate`); do not mix their results.
If a participant saw the baseline, their later result is a returning-player result. Use five fresh
participants for the candidate's first-read gate; returning players are useful additional evidence.

Use the existing encounters, rules and Lab controls. No new tutorial, telemetry service, analytics
SDK or test scene is needed. Keep identifying information out of committed sheets: use P01–P05.

## Preparation — facilitator only

Open the repository's `project.godot` with Godot 4.7.2 and run the project (F6 only runs the selected
scene). Enter **Combat Sandbox** from the title screen. In the current setup form set every field
below explicitly: preferences survive previous sessions. M1.1 Practice/Lab is a specified future
interface, so these instructions intentionally use today's Sandbox.

| Field | Baseline value |
|---|---|
| Encounter | Fixture's preset; selecting it restores its actual enemies and conditions |
| Party Preset | Starter: Sword, then fixture's Weapon override, if any |
| Tactical difficulty | Adventurer; record any player-requested change |
| Execution assist | Player's choice; record resolved window/speed/auto-Brace/reaction-pause overrides |
| Bestiary knowledge | Unknown, except fixture explicitly says Studied |
| Execution | Manual (you play) |
| Autopilot picks actions | Off |
| Show AI reasoning | Off |
| Record progress | Off; never use a participant's campaign save for this session |
| Seed | 23 for core fixtures; pacing seeds below |
| New seed on restart | Off |

Keep Mara, Bell Crow, Pilgrim's Coat, empty Charm/Relic, Mending Draught and Fen Water Flask for
the **weapon-only** comparison. Starter: Hammer/Bow presets also change other equipment/familiar/
potions; using them would compare whole builds. Recheck equipment after changing a preset.
Seed 23 here is the actual battle seed. It is not the CLI audit's base seed 23, which expands into
a sequence of battle seeds. Same seed with different inputs need not produce the same later rolls.

Record device, resolution, UI text scale, audio and reduced-effects settings. Allow the participant
to choose comfortable assists before testing. Do not ask them to forgo an accommodation to preserve
a comparison; mark that comparison as changed and interpret it accordingly.

## Core session — approximately 40–50 minutes

Show participants only the quoted prompts, not the expected answers below. Do not teach the answer
before its first probe. Stop for discomfort or fatigue; untested cells stay **not assessed**, not pass.

| ID | Fixture / purpose | Participant prompt | Record |
|---|---|---|---|
| R1 | Fen Patrol, Sword, Unknown; first planning state, before any tutorials | “Tell me who acts now, which enemy acts next, who is threatened, which defenses are allowed, and one drawback of the terrain.” | Start a 10-second observation timer when the state is visible. Score each of five facts separately; a complete pass needs all five without coaching. Do not require hidden move names/numbers. |
| R2 | Training Yard (`toy_training`), Sword, Unknown | “Try a defense. If it fails, tell me what happened and what you would change.” | One explained early/late failure and one successful chosen legal response. If neither occurs naturally, mark missing and use a later coached retry; do not count coached work as first-read success. |
| R3 | Fen Patrol, Sword, Unknown; fresh start | “Win this fight. Talk through anything that makes you change your plan.” | Wet/Shock explanation and an actual resulting decision. Ask “What changed?” only after an observed change, without naming the answer. Record spontaneous versus prompted explanation. |
| R4 | Fen Patrol, weapon-only variants; Studied | “Choose something useful this weapon lets you do. Why here?” | One distinct decision for each weapon, the situation and the cost paid. A higher damage number alone is insufficient. Rotate weapon order below. |
| R5 | Bramble Den or Mirebell Cantor, Sword, Unknown; optional challenge | “After the outcome, explain what most threatened the party and one available alternative.” | For a defeat, record attacker/action/status cause and feasible alternative. If no defeat occurs, defeat comprehension is not assessed; do not deliberately mislead the player or secretly alter balance. |

R2 Assisted check: when an attack disallows Brace, observe whether the player recognises that a manual
legal response is still required. If the dummy does not reach that move, this case remains untested.
Facilitator may extend that fixture after the uncoached segment; no invented claim that every seed
immediately presents every reaction type.

R4 order: P01 Sword→Hammer→Bow; P02 Hammer→Bow→Sword; P03 Bow→Sword→Hammer;
P04 Sword→Bow→Hammer; P05 Hammer→Sword→Bow. Partial counterbalancing reduces obvious order bias;
it does not remove practice effects. Returning-player runs must be labelled.

## Pacing pass — separate from interview

The canonical gate asks for **ten normal fights per player at their chosen assist**. Schedule a
separate session or breaks; the core interview alone cannot satisfy it. Alternate Fen Patrol and
Rot Grove, with actual battle seeds 31–40 in order, Starter: Sword, Studied, Manual, autopilot off.
Keep assist/device/text settings fixed within a player's pass unless an accommodation is needed.
These are repeated-content measurements, so report their familiarity and do not label them first-play.

Record active seconds = planning + manual input + playback, excluding pauses, setup and interviewer
interruptions. An interrupted run is marked contaminated and repeated with its original seed.
Record outcome and rounds; do not discard losses or timeouts. Report all-run summaries and wins-only
summaries separately when samples permit. Use sorted nearest-rank p90 (`ceil(0.9*n)`), not maximum.
Report each player's median and p90; pooling different assists alone conceals accessibility costs.
Investigate median >150 s or p90 >210 s; these are provisional investigation thresholds, not automatic
balance failures. Identify whether thinking, input or playback caused the delay before changing HP.

## Facilitator answer key and tactical probes

- **READ:** legal defenses, target and condition drawback are public even at Unknown. Exact damage
  and affinity-derived break/kill predictions must not reveal hidden research. Inspect temporarily
  reveals Understood detail; Studied reveals affinities. Learning during a fight is valid evidence.
- **REACT:** successful Evade/Parry avoid hit damage; this does not cancel terrain consequences.
  Flooded Ground makes an evading unit Wet even on success, creating a Shock risk. Accept any sound
  alternative grounded in the actual state: change defense, eliminate the Shock threat, interrupt,
  protect, or deliberately accept the risk. Do not prescribe a single correct button.
- **ADAPT:** ask after a repeated basic attack, “What would make you choose a technique here?”
  Distinguish “I didn't see it,” “I didn't understand it,” “I was saving Focus,” and “no useful reason.”
  The last answer is a design concern; the first two point to presentation. A win alone settles none.
- **EXPERIMENT:** Sword timing/Parry and Focus conversion, Hammer Brace→Coiled or break timing,
  and Bow weak-point setup/interrupt are examples to observe, not answers to teach. Mara's Condemn,
  Intercept and familiar triggers give alternate useful decisions without adding systems.
- **AFFECT THE WORLD:** not assessable in this sandbox. Do not substitute a checkbox or simulation
  win for a world consequence. Keep it deferred.

## Coverage beyond the five sessions

Use the existing custom encounter slots for four duplicate enemies and four different enemies;
also inspect the existing boss. Check keyboard-only, controller-only, mouse, 100/150/200% text,
sound off and reduced effects. Divide combinations across sessions and developer checks; list
exact combinations tested. Coverage is not a claim of full combinatorial accessibility testing.
Fresh-press ownership, focus loss during timing, pause queue, disallowed reaction then legal press,
empty/reordered targets and research leaks remain the functional tests in the implementation brief.

## Gate report

Copy the templates in this directory. Every observation uses `pass`, `fail`, `not_assessed` or
`blocked`, includes a concrete action/quote and states whether it was coached. No blank becomes pass.

At least 4/5 **fresh candidate** participants must pass all R1 facts within ten seconds; at least
4/5 must explain and act on R3. Each participant must supply the R2/R4 evidence. Track defeat
comprehension and the ten-fight pacing pass explicitly; missing evidence leaves the full gate open.
Attach accessibility coverage and functional results before a go decision. No new encounter/world
work is unlocked by this preparation pack or by the automated audit.

Report: candidate commit; participants/settings; R1/R3 counts; R2/R4/R5 evidence; pacing by player;
coverage and blockers; top three changes ranked by pillar impact; **go / revise / incomplete**.
Prefer a label/cue repair before a new mechanic when it solves the observed problem.
