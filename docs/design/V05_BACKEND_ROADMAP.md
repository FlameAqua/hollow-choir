# Backend continuation roadmap — 9 October 2026

**Current assignment update — 10 October 2026:** the A/B/C and UI backend work described below
has returned. Adrian's new human-review revision is planned in
[the revision plan](../reports/V0_5_PLAYTEST_REVISION_PLAN.md) and
[Claude start prompt](../briefs/V0_5_PLAYTEST_BACKEND_PROMPT.md). Use those for the bounded finite
brewing, party Break, Loadout/pet/fitting, countdown/journal and UI feedback assignment. They define
parallel ownership and confirmed capacities. No new implementation is claimed by that plan.
The old B-first sequence below is historical; wider V0.6/V2 scope stays separate.

Updated after V0.5A integration and Adrian's character-menu feedback. This scoped plan derives
from [the original GDD](../DESIGN_DOCUMENT.md). Adrian has now requested application **0.5.0**;
save version remains **1**. Update 10 October: V0.5A/B/C are integrated for the
[full human test](../playtests/V0_5_INTEGRATED_TEST.md). The
[C specification](V05C_EXPLORATION.md) records placement and confirmed policies. Human acceptance
is still open. The staged assignments below describe the implementation sequence.

The immediate Claude assignment is [V0.5B Forge/Stillroom](../briefs/V0_5B_BACKEND_HANDOFF.md).
Follow the [current continuation sequence](../briefs/V0_5_CONTINUATION_FOR_CLAUDE.md): B backend,
Codex station integration and bounded C specification, C backend and Codex exploration integration,
then the full integrated human test. Continue automated checks and focused reviews at each return;
an interim full human test of A is not a prerequisite. Later V0.6/narrative stages remain outside
this assignment.

## What the original design still needs

The GDD's loop is **Prepare → Explore → Discover → Fight → Salvage → Choose → Upgrade → Return**.
First Footsteps proves movement, visible encounters, a shortcut, restoration and returning home.
V0.5A now supplies persistent salvage, owned-equipment preparation and character inspection.
Forge/Stillroom spending and authored discovery interactions complete the next useful loop.

| Design pillar / system | Present in the working tree | Remaining slice work |
|---|---|---|
| Reactive combat | Deterministic engine, three weapon families, companion, familiars, statuses, conditions, AI, execution assists; elite/boss definitions already exist | Finish integration review; qualify encounters with human play, especially the existing boss |
| Knowledge and mastery | Persistent bestiary sources/tiers, Field Guide, Practice; weapon mastery points accumulate | Make mastery unlock choices rather than treating the saved counter as completed progression |
| Explore / return | Gloamstead and one Briarfen route, two encounter sites, deliberate bell restoration, return latch, save/retry/reset boundaries | Gathering, an interactive secret and the two eventual puzzle grammars; do not count the overlook or latch as those frameworks |
| Salvage / preparation | Exactly-once salvage, claims/catch-up, ownership-aware equipment commands, character menu and reward-grown bag capacity | Safe spending/unlocks and integrated human qualification |
| Forge / Stillroom | Weapon sockets and potion definitions; home-upgrade save placeholders | Modification rules, recipes, costs, station eligibility and persistent outcomes |
| Observatory | Existing Field Guide / map knowledge | Connect future regional and discovery readouts; reuse the Field Guide rather than build a second bestiary |
| World consequences | Bell and shortcut flags already drive authored changes | Activity-based Pressure, one event chain, choices and changed content |
| Narrative | Bellkeeper before/after interaction; recruited Mara | One authored companion arc and one meaningful regional choice; rumors later |

V0.5A rewards now commit alongside victories/restoration and survive Reset journey. The bench
equips owned gear; the Storm Salt Charm can reach a real battle. Materials are still reserved
for crafting until B lands. The menu inspects actual actions/passives and saved mastery rather
than introducing character levels. See [the current A follow-up](../reports/V0_5A_CHARACTER_MENU.md).

## Order of work

### 0. Fifth engineering pass — complete

Completed and committed in `35c8763`, including the
[fifth engineering report](../reports/V0_4_FIFTH_PLAYTEST_ENGINEERING_REVIEW.md).
Preserve those fixes and the centered action grid; do not restart that historical assignment.

### 1. V0.5A — Salvage and Preparation — integrated

**Deliverable:** existing world accomplishments grant deterministic, persistent rewards exactly once; an owned item can be equipped through a validated backend command and reaches the next immutable encounter snapshot. Expose typed reward, inventory and preparation readouts for Codex to present.

Bound this to the current two sites and restoration. Use two small material definitions and one existing equipment reward: Storm Salt Charm. Its authored Grounding trait gives Shock against Wet an additional Stagger interaction; this is a concrete reason to try a different setup, not a stat-level treadmill. Materials establish the next station interface without requiring a full economy now.

Reuse ProgressState, DefinitionRegistry, TraitDefinition, WorldSession.commit, EncounterEntry and the existing combat pipeline. Add persistent reward receipts outside the resettable world section. Keep starter weapons and existing potion capacities available. Practice remains unrestricted and grants no new world rewards; the recording Combat Lab keeps its existing research/mastery behavior.

**Exit:** an integration test can complete the guard/restoration, save/reload, equip the charm through the production API and launch a battle containing the existing trait. Failed writes, retries, repeated notifications, older saves and Reset journey cannot duplicate or lose the reward. Inspector information remains research filtered. See the implementation brief for the exact contracts and acceptance cases.

**Codex follow-up completed:** rewards, preparation, compact loot, the portrait character menu,
shared Alt/pin inspection and atlas inventory frames are integrated. Ten starting equipment slots
grow by five on first bell restoration, derived from its persistent reward claim. Final A behavior
verification was 371/0 under Compatibility/Dummy; see the linked report for its limits. Human
usefulness/clarity review joins the full integrated V0.5 test after B and C.

### 2. V0.5B — One useful Forge and a small Stillroom

**Dependency:** V0.5A's ownership, transaction and readout contracts are stable.

Implement a data-driven recipe/cost/eligibility model and atomic spending. Make one reversible weapon modification choice through existing traits; do not mutate shared weapon Resources. Define how saved weapon modifications enter EncounterEntry and UnitFactory. Mastery should unlock modification capacity or another behavior, not mandatory damage levels. Common starter equipment must remain viable.

The ready [B specification](../briefs/V0_5B_BACKEND_HANDOFF.md) fixes the first kit at 2 Bog Iron
and one saved starter-weapon mastery point, with Merciful Grip / Hollow Echo / none on Pilgrim's
Edge and a full atomic kit refund. The two permanent Stillroom recipes are Clotting Salve for
1 Bog Iron and Focus Tincture for 1 Storm Salt. Their Base + Reagent vocabulary reuses home
supplies and existing potion effects; it adds no carried depletion or bottle count.

All purchases total 3 iron + 1 salt against the finite route's 4 + 1. This budget and the exact
refund/mastery contracts are already specified, so Claude can implement B next. Codex owns the
station screens and the subsequent bounded C brief. Preserve immutable retry snapshots and
reward-derived bag capacity throughout.

**Exit:** spend → unlock/modify → save/reload → equip → battle works atomically; invalid requests and insufficient resources do nothing; two options have distinct tactical uses and fit the eight-action ceiling. Removing a modification restores the base item without duplicating grants or touching other saves/loadouts.

### 3. V0.5C — Complete the small exploration vocabulary

The original world-slice list is not complete just because First Footsteps is playable. Add one authored gathering node and one discoverable secret, then the first reusable puzzle grammar. Resonance Mirrors or a small rune sequence is enough for the first batch; Bloom Routing can be the second grammar later.

Claude owns typed definitions, deterministic interaction state, validation, reset/persistence policy and reward hooks. Codex owns placement, visual feedback, tiles and presentation. Keep the current authored areas; add surgical scene changes after the placements are agreed. Separate puzzle truth from scene visibility. Gathering refresh policy must be explicit, with no clock-based respawn and no Reset journey reward exploit. Avoid a generic quest framework until a second real objective demonstrates the need.

After B returns, Codex supplies the exact placement, reward budget, gathering persistence and
puzzle grammar in a bounded C brief. Then Claude implements that stage, followed by Codex's
visible integration. These contracts should be concrete before implementation, without making
the full human test a gate between B and C.

**Exit:** solve/discover → reward → save/reload works; the player understands the interaction; optional secrets do not block the main route. The first grammar has a second test fixture proving it is reusable, without producing dozens of maps.

### 4. V0.6 — Regional Pressure and one authored event chain

**Dependencies:** a meaningful return loop and a precisely defined expedition/activity boundary.

Specify which completed player activities count as meaningful expeditions before implementing Pressure increments. Opening a menu, reloading, entering a portal repeatedly, Practice and Reset journey must not advance it. Pressure is 0–3 and activity based; never a real-time timer. Keep this separate from the undecided HP/potion carry model.

Implement one chain in Briarfen: warning → active event → ignored consequence → Scar → Cleanse / Cultivate / Stabilize → changed region. Use stable event/choice IDs and typed effect/readout contracts. Reuse current regional save sections where possible. Effects change routes, encounters/resources or NPC responses rather than deleting access to authored content. Do not activate Pressure until all response branches and recovery paths exist.

**Exit:** every branch survives reload, repeated triggers are harmless, consequences are legible, and ignoring an event changes play without creating a timed checklist or a softlock. Codex authors the visible before/after states; Adrian validates the choice.

### 5. Narrative and the integrated vertical-slice finale

Build one Mara story using the world-state vocabulary and one regional moral choice. Add a small authored objective model if needed; do not bolt on a generic procedural quest system first. The GDD's three rumor templates can follow once the objective/event contracts are useful in actual content. No runtime LLM dialogue.

Integrate and tune the existing Mirebell Cantor rather than commission a replacement boss or a new biome. Its engine/data already exist; world placement, encounter context, progression rewards and human testing remain distinct work. Prove starter-weapon viability, readable deaths, environment decisions and interruptible channels. Then test the complete home → outing → reward → different build → next outing loop.

**Exit:** a compact complete slice, with one excellent quest/choice and a boss that tests learned systems. Expand zones, weapon families and companions only after that experience is useful and enjoyable.

## Ownership and guardrails

- Claude: gameplay/data/save architecture, pure rules, transaction commands, typed filtered readouts, tests, tools and concrete backend defects. Routine implementation choices inside the assigned batch do not require another permission round.
- Codex: game direction, UI/UX, authored assets, audio, art placement and presentation integration. Supply contracts and fixtures so this work can proceed without reopening gameplay rules in widgets.
- Adrian: final play/visual acceptance and larger design choices. Passing simulations or tests does not declare fun or clarity accepted.
- Keep two controlled units and a trigger-only familiar; preserve public/earned knowledge gates, existing combat balance and action-command input ownership.
- Keep all-reset encounters, current retry snapshots, safe anchors and save-failure behavior. No attrition, currency/shop economy, random drops, grinding gates, new region, new party size, real-time simulation or content regeneration in V0.5A.
- Preserve the shared uncommitted dev tree. Application is now 0.5.0 at Adrian's request and save
  version stays 1. Do not commit/push, reset, change versions again or overwrite authored areas
  as part of the backend handoff.

## Next handoff checkpoints

Each batch returns a short report with implemented behavior, changed contracts/files, save compatibility, exact tests actually run, unresolved defects, and the next Codex presentation task. Keep inherited evidence separate from new verification. The current immediate brief supplies named output reports and a small demonstration fixture so another fresh engineer can resume without reconstructing this conversation.

The final V0.5 checkpoint is the complete home → salvage → slot reward → craft/prepare → battle
→ discover/gather/solve → return loop, including older saves, reload/reset, failed writes and input
methods. Automated qualification precedes Adrian's full human, controller and listening test;
passing backend checks alone does not close those gates.
