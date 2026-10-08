# M1.1 — Combat clarity and Briarfen art

Director specification • 7 October 2026 • **Core contract retained; UI presentation revised 8 October.**

> The user-authorized [icon-first UI contract](ICON_FIRST_COMBAT_UI.md) supersedes this document's
> four-column dock, context panels, rail reservation, font and persistent-text layout requirements.
> Runtime integration is present; knowledge, input ownership, mechanics and human gates below remain.

This is a normative supplement to [the canonical GDD](../../DESIGN_DOCUMENT.md).
It supersedes older M1 presentation examples where they conflict. It adds no battle system,
content tier, party slot or progression mechanic. Numerical combat tuning remains unchanged.
See [review](../reviews/M1_DIRECTOR_REVIEW.md), [Claude brief](../briefs/M1_1_IMPLEMENTATION.md),
and [visual study](visuals/combat_study.html). The study uses illustrative states, not a live engine.
Rendered review captures: [planning](visuals/planning.png), [reaction](visuals/reaction.png),
and [practice setup](visuals/setup.png). Finalized 8 October 2026.

## Release purpose and scope

The player must answer **whose turn, who threatens whom, what can I do, and what will it cost**
without opening a tooltip. Detailed evidence remains available on demand. The next milestone is
a readable combat toy, not the world slice. Complete the first three priorities before expanding art.

Cost estimates below are planning ranges for one engineer familiar with M1, including local checks;
they are not commitments. Art cleanup and player recruitment are separate.

| Feature / priority | Player-facing purpose | Decision created or clarified | Existing systems | Cost | Failure / exploit | Cheaper approach chosen |
|---|---|---|---|---|---|---|
| F1 / P0: information hierarchy and honest previews | Understand threats and likely consequences | Which enemy/action merits this turn; whether to Inspect | IntentPreview, ActionPreview, ResearchRules, timeline, UnitInfo | 2–3 days; knowledge filtering is the main risk | Hidden affinity leaks; optimistic AoE or trigger promises; overlapping intents | Restyle and filter existing presenters; no prediction engine |
| F2 / P0: common decision dock and input ownership | Know when to choose and when to time a press | Commit/cancel a target; choose a legal defensive risk | ActionPicker, existing command widgets, ReactionSpec, InputBindings | 2–3 days; timing/pause regression checks | Confirm carries into command; gamepad overlap; pause consumes clock; mismatched cue/impact | Reuse existing graders and timing source; one presentation shell |
| F3 / P1: condition and familiar explanation | See why a tactic changed | Evade now versus becoming Wet; exploit a familiar trigger | SidePanel, conditions, trigger events, battle log | 0.5–1 day, shared with F1 | “Evade blocks statuses” conceals environment Wet; stale once-per-round state | Existing descriptions + event ledger; no synergy recommendation system |
| F4 / P1: Practice / Lab setup | Reach an intentional first fight quickly | Practice a readable preset versus change one variable | CombatSandbox, existing presets/loadouts/settings | 1–2 days | Old saved autoplay/knowledge contaminates practice; accidental progress recording | Two views of one setup form; no tutorial campaign or tutorial state machine |
| F5 / P1: reusable art presentation | Recognize actors and actions by silhouette | Identify a target/attacker quickly; no new combat choice | CombatantDefinition.sprite_frames, UnitView, BattleEventPlayer, Battlefield | 1–2 days hookup; 2–4 artist days for first-pass cleanup, provisional | Sprite footprint shifts hit targets; animation delays reaction; incorrect facing | Idle sprites + shared lean/lunge/hit/defeat; existing placeholder fallback |

Rejected now: new enemies, bespoke telegraph minigames, new reaction grades, tactical positioning,
Blight, procedural tutorials, a new simulator policy, a full scene architecture rewrite, voice acting,
portrait sets, world-state UI, and a bespoke animation for every action.

## Visual and layout contract

Reference canvas: **1280 × 720**, existing canvas-items stretch. Text is rendered at UI resolution;
sprites use nearest filtering and integer display scale after their final pixel cleanup. Do not render
the entire UI into a low-resolution pixel buffer. Art never carries essential instructions.

| Region | Reference rect x / y / w / h | Content |
|---|---|---|
| Header | 24 / 12 / 1232 / 36 | Encounter, round, quiet Log / Pause / Setup controls |
| Timeline | 24 / 56 / 1232 / 44 | NOW + remaining activations; forecast explicitly says “Next round · forecast” |
| Stage | 24 / 112 / 1232 / 340 | Party left, enemies right, no interactive scenery |
| Intent rail inside stage | 640 / 120 / 608 / 208 | Up to four stable slots in a 2 × 2 grid; actor name + matching marker/leader |
| Condition ribbon | 24 / 456 / 1232 / 36 | Current major/minor rule, with full details reachable by focus |
| Decision dock | 24 / 500 / 1232 / 180 | Party 248 px; gap 16; actions 272 px; gap 16; preview 416 px; gap 16; familiar 248 px |
| Context help | 24 / 688 / 1232 / 24 | Current device bindings, never instructions for an inactive state |

Dock widths sum to 1232. The reference rail uses compact rows; expanded intent details use the preview
area while planning, never a stack of free-floating overlapping bubbles. Intent identity is stable
through resolution and never shifts to a different enemy when another dies. Instance names distinguish
duplicates, e.g. Thornhound A / B. Four-enemy and boss layouts are required acceptance cases.

Hierarchy: current input task → current actor / target → threats → resources → analysis. Selection
uses a bone-gold bracket **and** a label. Threat uses an exclamation mark + word, not only red.
Never use faction colours as “good/evil.” Choir is orderly ivory/brass; Bloom is irregular moss/rust.

Palette: background `#101918`; panel `#172321`; raised panel `#20332e`; border `#62766b`;
text `#f1ead5`; secondary `#bac6b5`; selection/Focus `#e2c681`; Heart `#94c89b`;
Stagger `#c4b5e5`; threat `#f0a18a`; Wet `#9ad7e0`. Text-bearing panels are opaque.
Target contrast is ≥4.5:1 for body text and ≥3:1 for focus outlines / meaningful graphics;
verify final combinations after integration. Icons always have names in focus details.
Base body text 18 px, secondary 16 px; no essential label below 16 px at reference scale.
Control height ≥40 px. Use the bundled/default UI font initially; no font acquisition dependency.

At 150% text, expand the dock to 256 px and use a scrollable action list / detail panel; shrink scenery,
not essential text. At 200%, use the same components in a stacked full-width decision overlay over a
dimmed stage, retaining actor, target and threat summary. Execution and reaction replace its contents;
their controls never require scrolling. The visual study illustrates default scale only.

## F1 — Read and choose

### DESIGN INTENT

Keep tactical truth separate from information earned through research. Remove clutter without making
the player hunt for the actor, target, reaction legality or condition rules.

### PLAYER EXPERIENCE

“The crab is preparing a heavy hit against Mara. I cannot Parry it. I can break it first, Guard,
or accept a defensive timing attempt.” An attack preview prioritizes target, cost, Good outcome and
important consequence. Miss / Perfect comparisons and calculation detail expand on demand.

### RULES

1. Always show actor and actual affected target(s), intent category, threat word, available reactions,
   status payload, channel countdown and whether the channel can be interrupted. Countdown units are
   **that enemy's activations**, not rounds. A release due now says “Releases this activation.”
2. Enemy move names, exact incoming damage and AI explanations unlock at UNDERSTOOD or Inspect.
   Otherwise use the same category label everywhere, including the reaction widget and log before
   resolution. Debug AI information stays in Lab and is visibly labelled.
3. Affinities unlock at STUDIED or a revealing hit. Unknown affinity is **unknown**, never “Weakness?”
   or “Resisted?” chosen using the hidden answer. Inspect retains its current UNDERSTOOD reveal.
4. Before affinity is known, suppress outgoing exact damage/Stagger ranges, affinity-dependent Focus,
   lethal/break claims, formula terms and comparative bar ghosts that disclose it. Say “Affinity
   unknown · strike to learn, or Inspect.” Retain cost, damage type, target, command type, public
   status rules and public meters. Do not substitute a misleading neutral calculation. This is a
   display policy; the underlying engine preview and simulation remain exact and unchanged.
5. With known affinity, label values **Good · direct hit**. Multi-hit totals, redirection, area effects,
   grade-conditioned statuses and triggered follow-ups must not be silently represented as complete
   by today's single-target preview. If the existing preview cannot establish a total, qualify it as
   “per hit / per target” where true, otherwise hide the number and list the effect in words. Do not
   ship a new forward simulator to solve this. No unconditional “will break/kill” without proof across
   all affected hits/targets, minimum roll and required grade.
6. Hovering a unit cannot replace the selected action summary unless the player explicitly enters
   Details. Keyboard/controller focus exposes the same detail as a pointer. Back returns to the
   previous focus and target. No world-state consequence is implied by a sandbox victory.

### UI REQUIREMENTS

One active actor label; full target name in the preview; costs adjacent to action names; disabled
actions remain inspectable with a reason (“Needs 3 Focus · have 2”). Use “Stagger remaining” and an
emptying meter consistently. “Broken” replaces the meter state, with interruption/lost activation
explained once in details. Status names plus remaining turns/charges are available on focus; avoid
cryptic three-letter buff labels as the only explanation. Keep at least the dangerous status visible
and provide a labelled “+N effects” control for overflow. Essential incoming status is on the intent,
not hidden in this overflow.

### DATA REQUIREMENTS

Reuse ActionPreview / IntentPreview / ResearchRules. Add one presenter-level, typed visibility policy
shared by dock, intent, tooltip and reaction header; do not duplicate knowledge checks by widget.
Existing events supply target changes and resolution. No save change. Detailed contract in the brief.

### BALANCE PARAMETERS

No change to damage, timing or research thresholds. Preview grade defaults to Good; always label it.
Information gating changes displayed knowledge, not outcomes. Monitor Inspect choice and comprehension
before changing its cost. The study's numbers are fixture values, not proposed tuning.

### EDGE CASES

Redirected attacks; two identical enemies; hidden affinity but visible HP; area action with mixed
affinities; multi-hit; chance-based effects; target death or break; capped Focus; research gained
mid-battle; minimum damage; next-round forecast becoming stale. Unknown on one target must not conceal
known information on another, or leak via aggregate totals. Determinism must survive preview calls.

### ACCESSIBILITY REQUIREMENTS

No hover-only rules. Details supports hold, toggle and Always (toggle is a small addition to the current
hold/Always support). No colour-only meaning. Scaling rules above are acceptance requirements, not
claims about the current build. Tooltips must remain within the safe area and accept focus.

### ACCEPTANCE TESTS

F1-A: Four different and four duplicate enemies at 1280×720 and 150% text: identify every attacker,
target, legal reaction and imminent channel without overlapping labels or opening analysis.
F1-B: At UNKNOWN, switch Slash/Blunt/Pierce previews on Bogshell: no hidden affinity, exact
affinity-derived result or formula is exposed; a revealing hit / STUDIED unlocks only permitted data.
F1-C: Inspect changes knowledge without changing enemy stats or submitted action results.
F1-D: On area, multi-hit, redirect and grade-conditioned actions, displayed scope matches resolution;
unprovable break/kill claims are absent. Previewing consumes no RNG or Focus.
F1-E: A keyboard-only and controller-only player can read the same rules as a mouse user and return
to the same selected action. Log/details never silently change the selected target.

## F2 — Commit, execute and defend

### DESIGN INTENT

Separate deliberation from dexterity. Reuse a single decision dock for planning, commands and reactions,
with clear input ownership and no pressure during action selection.

### PLAYER EXPERIENCE

“I choose the action and target, then perform it. On defense I press one legal response at impact.”
The key used to confirm an action cannot also miss its command. Reaction timing is readable without
sound and with motion reduction enabled.

### RULES

1. Action selection → target review → commit → command → event playback. Back before commit spends
   nothing. Single-target actions with only one legal target still show its identity; an extra review
   confirmation is required only when a target choice exists. Self/area actions show scope before commit.
2. Consume the committing event. Newly opened timing widgets accept a **fresh press** after release;
   held buttons, key repeat and the same gamepad X event do not enter the next state.
3. Preserve three command components and the existing optional aim widget. Do not make aim mandatory.
   Every command shows one short instruction, its bound key and an unambiguous active region.
4. Reactions are binary. The first allowed fresh press locks type and timing. Unavailable reactions
   are inert and labelled “Unavailable”; an invalid press does not consume the legal attempt.
   AoE uses one window for all affected party members. No separate reaction grade or extra window.
5. Reaction order is always Brace / Evade / Parry. Show availability before the window begins.
   Preserve the ring's engine impact time. A fixed impact marker plus a matching dock indicator
   can share the same clock; neither animation nor SFX may define a second timing source.
6. Pause-before-reaction says “Confirm to begin; then press a reaction at impact.” The starting
   press never counts as a reaction. Existing auto-Brace is labelled and applies only if allowed.
   If Brace is unavailable, explicitly say “Manual Evade required” (or the actual legal response);
   do not claim Assisted resolves every attack automatically.
7. Preserve current safe pause points during planning. During a timed input, a pause request queues
   until resolution and visibly says “Pausing after this action”; it must not open an overlay while
   wall-clock time continues unseen. Application focus loss must freeze the active elapsed-time
   source and resume without reusing a held input; no countdown reset or free retry. This clock
   correction is an acceptance requirement, not an implemented capability.

### UI REQUIREMENTS

Planning dock contains actions and preview. Command dock contains a short verb and timing area.
Reaction dock contains attacker → targets, one instruction and three large fixed-position cards:
Brace “Reduce damage; statuses can land”; Evade “Avoid hit; risk +15% on failure”; Parry
“Avoid hit + Stagger; risk +30% on failure.” These are base values; equipment-modified details come
from the rules. Flooded Ground adds “Evade makes you Wet, even on success.” No hidden tooltip is
required to discover this drawback. An unavailable card stays in place. Results say “Early”, “Late”,
or “Success” only if measured evidence supports it; otherwise “Failed”. Never call every failure late.

### DATA REQUIREMENTS

Use ReactionSpec/CommandSpec and InputBindings. Pending pause, released-input latch and active elapsed
time are transient presenter/widget state, not new combat states or save data. The same calculated
window controls grading and display. Read success/failure multipliers from BalanceConfig, not UI literals.

### BALANCE PARAMETERS

Keep Standard total reaction windows at Brace 520 ms / Evade 280 ms / Parry 150 ms before modifiers.
Brace success damage multiplier 0.6; Evade/Parry success 0; failed Evade 1.15; failed Parry 1.3.
The loaded M1 parry Stagger is **16**, overriding the class default 18. Offensive grades remain
0.85 / 1 / 1.15. Do not tune these to compensate for poor cues. Combat Speed never alters windows.

### EDGE CASES

Shared confirm/command/Evade binding; two buttons in one frame; disallowed button then legal one;
pause at impact; alt-tab while holding charge; controller disconnect; low FPS; restart during feedback;
no legal Brace with auto-Brace; no command action; action cancelled by death before presentation.
Deterministic event order and node-bound lifetime cancellation remain mandatory.

### ACCESSIBILITY REQUIREMENTS

Retain independent Tactical Difficulty and Execution Assist, rebinding, pause-before-reaction, reduced
flashes and shake options. All action text shows the active device's binding. Reduced motion removes
bobbing, shake and decorative pulses; a simple meter/marker still communicates timing. No requirement
to recognize sound pitch. Timing offset calibration is deferred pending hardware evidence.

### ACCEPTANCE TESTS

F2-A: Hold confirm across commit: zero command input until release and fresh press. Repeat with gamepad X.
F2-B: Disallowed Parry then legal Brace succeeds when timed correctly; two legal presses submit once.
F2-C: Standard/Generous/Assisted display the actual modified windows; Combat Speed 0.5× / 2× does not
alter measured acceptance boundaries. Sound-off and reduced-motion users can locate impact.
F2-D: Pause-before consumes only start input; Assisted auto-Brace works only when legal. Drench
visibly warns that Brace is unavailable.
F2-E: Focus loss for several seconds preserves elapsed progress and does not replay held inputs;
queued manual pause appears after the active result. Restart during feedback produces no late submit.

## F3 — Explain conditions and triggered allies

### DESIGN INTENT

Make systemic reuse visible: one condition and one familiar should create many decisions without
additional buttons or bespoke encounters.

### PLAYER EXPERIENCE

“Evading the slam saves HP but makes Mara Wet; the wisp's Shock can then spread. The crow will help
with Stagger when a legal Parry succeeds.”

### RULES

Flooded Ground keeps its current effects: Evade applies Wet for 2 turns even on success; IMPACT
actions splash Wet; Shock on Wet spreads to other Wet units on that side without re-chaining;
Burn lasts one turn less. State the normal status rules in details, including Wet/Burn cancellation.
Spore Fog stays a minor condition: the first Burn applied in a round deals 8 Fire damage to each
other unit on that target's side. This is **one shared trigger per round**, not per side or per unit;
it is ordinary Fire damage subject to the existing resolver. A doused, unapplied Burn cannot trigger it.
No positioning mechanic is implied by either rule. Bell Crow damages the attacker for 12 Stagger
after a successful party Parry, once per round; Mara gains 2 Focus on the Hollow's successful Parry.
No “Perfect Parry” grade. Familiars still take no turn.

### UI REQUIREMENTS

Condition ribbon shows name + short consequence; focus gives the full rule, not just flavour.
Familiar card shows trigger, effect and “Ready this round” / “Used this round”. Show triggered
feedback once and log its source. HP, Focus, Stagger, statuses and readiness advance together at
their presentation events; do not expose the final state before its cause plays.

### DATA REQUIREMENTS

Reuse condition descriptions, trigger limits and BattleEvent records. Extend the existing presentation
ledger for Focus/statuses as needed; reconcile at batch end. No new trigger interpreter, counters in
saved definitions, or independent familiar combatant. Add only an optional portrait texture to
FamiliarDefinition if required to show the staged Bell Crow art.

### BALANCE PARAMETERS

Retain current 8 Fire / 12 Stagger / 2 Focus and once-per-round limits. Change none in this pass.
One major + optional minor condition remains the cap.

### EDGE CASES

Burn doused by Wet; reapplication; both sides apply Burn; target has no living allies; dead chained
target; familiar cap reached; target Parried by Mara; Focus already capped; phase replaces condition;
restart between trigger and display. Follow the existing trigger owner/recipient semantics.

### ACCESSIBILITY REQUIREMENTS

No colour-only Wet/Fire distinction. Readiness uses words. Condition transitions have persistent text
and log entries as well as optional sound. Reduced effects never hides a condition.

### ACCEPTANCE TESTS

F3-A: Successful Evade in Flooded Ground avoids the hit but visibly applies Wet from the environment.
F3-B: First actual Burn in Spore Fog triggers once; second application on either side does not;
doused Burn never consumes the trigger. Verify damage through existing calculations.
F3-C: Two successful Parries in a round fire Bell Crow once. Hollow Parry grants Mara Focus;
Mara Parry does not grant her the Hollow-specific passive. Next round resets readiness.
F3-D: During slow playback, every Focus/status/readiness change appears with its event, and batch-end
state agrees with the engine. No duplicated trigger on restart or replay.

## F4 — Practice and Lab

Practice defaults: Training Yard, Starter Sword, manual play, saved tactical/assist preferences,
Unknown knowledge, no autoplay, no debug AI, no progress recording. It displays its actual values;
it never silently reuses Lab overrides. Offer existing Fen Patrol / Rot Grove / boss presets with
one sentence describing what they test, and Sword / Hammer / Bow loadouts. No new encounters.

Lab contains today's full form, seed, individual equipment, enemy slots, knowledge override, simulated
execution, autoplay, progress toggle and batch simulation. One authoritative BattleSetup backs both
views. “Practice” cannot imply progress will persist. Results prioritize outcome, a factual cause
from the log, Retry same setup, and Change setup; seeds and metrics sit under Details. No automated
recommendation engine. Preserve Lab's re-seed option and label it explicitly.

Acceptance: first launch reaches manual Training Yard in two primary selections; entering Practice
after a saved PERFECT/autoplay Lab session restores Practice rules visibly; changing weapon never
changes difficulty/assist; Lab's existing controls remain reachable; no unexpected save writes.

## F5 — Art direction and production limit

**8 October art addendum:** the user's explicit continuation request authorizes staged idle candidates
for the remaining six **existing** enemies and shared combat UI textures. See the incorporated
[style guide](../../assets/art/STYLE_GUIDE.md) and [v0.2 pack](../../docs/art/briarfen_v02/README.md).
This supersedes the broader-cast *staging* hold below only. New content, full animation, production
pixel approval and the human clarity gate remain unchanged. No runtime implementation is claimed.

The Hollow is a weathered masked pilgrim; Mara's upright spear and worn ivory armour suggest her
inquisitorial past; Bell Crow reads as a small trigger ally, not a third controlled character.
Bogshell is a low protective crab, Thornhound a forward-leaning bramble animal, Fen Wisp a suspended
reed cage around cold light. Bloom organisms are living neighbours as well as hazards, not demonic
shorthand. The marsh reclaims precise Choir stonework without a “good nature / evil church” palette.

[Asset manifest](../../docs/art/briarfen_v01/manifest.json) supplies the generated sheet, independent
atlas regions and single-frame SpriteFrames Resources. **These are art candidates, not final animated
pixel assets.** The generator did not obey a uniform grid; never slice 512×512 cells. Partial alpha,
fine detail and some edge residue require cleanup at final display size. The background is one flattened
plate; there are no separate parallax layers. The study demonstrates direction, not shipping art approval.

First hookup: keep the existing feet anchor, target hit area and effect anchors stable; use the idle
frame with shared presentation transforms and placeholder fallback for all unillustrated units.
Do not scale a character to fit the HP label. Enemy candidates already face left; party face right;
do not flip them twice. No collision, weak-point, resistance or timing data comes from pixels.
Bell Crow is a portrait candidate until its optional texture field is integrated.

Final cleanup target: 64×64 cells for party / ordinary enemies, 32×32 familiar, 96×96 elite/boss only
when needed, shared bottom-centre anchor, restricted palette, no transparent haze. Long spear fits
inside its cell. Two idle frames are optional after a static frame reads. Cap initial animation at
idle, anticipation, hit and down; existing event transforms can supply the latter three. A separate
attack sheet per technique is rejected. Broader M1 cast art follows only after the Fen Patrol gate.

Acceptance: identify all six silhouettes at intended size on the darkest/brightest stage areas; no
clipped spear/claw, stray neighbour, alpha fringe or double flip; no sprite jump when selected or hit;
missing art uses the existing silhouette without an error; loaded idle Resources are valid; disabling
all new artwork leaves combat results and targeting identical. Art quality still requires human review.

## Human acceptance gate

Use five fresh testers as a small directional sample, not statistical validation. Record build, seed,
loadout, research, assist, device, text scale and observation. Do not coach before the read test.

1. Freeze a planning state: at least 4/5 identify active actor, next enemy, target, allowed defense and
   condition drawback within 10 seconds. Failure blocks additional encounter work.
2. Training Yard: testers explain one early/late failure and succeed with a chosen legal defense.
   A tester using Assisted can state when manual defense remains necessary.
3. Fen Patrol: at least 4/5 explain Evade → Wet → Shock risk and change a decision because of it.
4. Switch Sword/Hammer/Bow: each tester describes a different useful decision, not just damage output.
5. On defeat: tester names attacker/action/status cause and proposes an available alternative. A log
   existing is insufficient evidence of comprehension.
6. Time ten normal fights at each player's chosen assist. Keep 3–5 rounds as the target; provisionally
   investigate median active battle duration >150 s or p90 >210 s, excluding pauses/read tests.
   These are design hypotheses, not measured results. Separate thinking, input and playback time before tuning.

No go/no-go claim for AFFECT THE WORLD: it is intentionally absent in M1. No balancing around a
speculative expedition attrition loop, and no milestone expansion until the above clarity gate passes.
