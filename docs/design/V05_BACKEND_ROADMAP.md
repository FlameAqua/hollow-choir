# Backend continuation roadmap — 9 October 2026

Prepared for Adrian's request to assign the next backend work to a fresh Claude instance after the previous instance exhausted its usage. This is a scoped plan derived from [the original GDD](../DESIGN_DOCUMENT.md), checked against the current working tree. V0.5 labels below are planning labels, not release numbers. No gameplay implementation or human acceptance is claimed by this document.

The immediate assignment is in [the fresh-Claude brief](../briefs/V0_5A_BACKEND_HANDOFF.md). Complete the interrupted V0.4 engineering review, then implement only V0.5A. Later stages are a work order, not permission to implement the whole roadmap in one session.

## What the original design still needs

The GDD's loop is **Prepare → Explore → Discover → Fight → Salvage → Choose → Upgrade → Return**. First Footsteps proves movement, visible encounters, a shortcut, restoration and returning home. Its bench changes starter weapons, but there is not yet a persistent reward-to-build loop. That is the most useful next backend investment.

| Design pillar / system | Present in the working tree | Remaining slice work |
|---|---|---|
| Reactive combat | Deterministic engine, three weapon families, companion, familiars, statuses, conditions, AI, execution assists; elite/boss definitions already exist | Finish integration review; qualify encounters with human play, especially the existing boss |
| Knowledge and mastery | Persistent bestiary sources/tiers, Field Guide, Practice; weapon mastery points accumulate | Make mastery unlock choices rather than treating the saved counter as completed progression |
| Explore / return | Gloamstead and one Briarfen route, two encounter sites, deliberate bell restoration, return latch, save/retry/reset boundaries | Gathering, an interactive secret and the two eventual puzzle grammars; do not count the overlook or latch as those frameworks |
| Salvage / preparation | Saved equipment/material/consumable containers and owned starter weapons | Actual rewards, ownership-aware preparation, usable readouts and safe spending/unlocks |
| Forge / Stillroom | Weapon sockets and potion definitions; home-upgrade save placeholders | Modification rules, recipes, costs, station eligibility and persistent outcomes |
| Observatory | Existing Field Guide / map knowledge | Connect future regional and discovery readouts; reuse the Field Guide rather than build a second bestiary |
| World consequences | Bell and shortcut flags already drive authored changes | Activity-based Pressure, one event chain, choices and changed content |
| Narrative | Bellkeeper before/after interaction; recruited Mara | One authored companion arc and one meaningful regional choice; rumors later |

Evidence for the progression gap: ProgressState currently awards research/mastery/statistics from BattleResult; materials, consumables, quests, regions and home upgrades mostly serialize placeholders. WorldSession commits victories and restoration, but awards no salvage. WorldRules.bench_weapons exposes only owned starter weapons. Saved containers and content definitions alone are not finished systems.

## Order of work

### 0. Recover the interrupted fifth engineering pass

The current tree contains tests/ui/test_fifth_engineering.gd and tests/unit/test_action_capacity.gd, plus production changes for pinning, timing-help wording, conditional weak-point explanation and announcement speed. The requested V0_4_FIFTH_PLAYTEST_ENGINEERING_REVIEW.md is absent. Treat this as partial work to audit and finish, not a clean start or a proven passing suite.

Read the [fifth brief](../briefs/V0_4_FIFTH_PLAYTEST_ENGINEERING.md), preserve Codex's latest centered action grid and art, run appropriate checks in isolated user data, fix concrete integration defects and write the missing review. Do not spend the entire new assignment redoing historical completed fixes. A normal review finding need not hold up independent progression code; an unresolved save-corruption or battle-submission defect must be fixed before connecting new rewards.

**Exit:** the fresh engineer can state what was inherited, what changed, what actually passed and what still needs Adrian's review.

### 1. V0.5A — Salvage and Preparation backend

**Deliverable:** existing world accomplishments grant deterministic, persistent rewards exactly once; an owned item can be equipped through a validated backend command and reaches the next immutable encounter snapshot. Expose typed reward, inventory and preparation readouts for Codex to present.

Bound this to the current two sites and restoration. Use two small material definitions and one existing equipment reward: Storm Salt Charm. Its authored Grounding trait gives Shock against Wet an additional Stagger interaction; this is a concrete reason to try a different setup, not a stat-level treadmill. Materials establish the next station interface without requiring a full economy now.

Reuse ProgressState, DefinitionRegistry, TraitDefinition, WorldSession.commit, EncounterEntry and the existing combat pipeline. Add persistent reward receipts outside the resettable world section. Keep starter weapons and existing potion capacities available. Practice remains unrestricted and grants no new world rewards; the recording Combat Lab keeps its existing research/mastery behavior.

**Exit:** an integration test can complete the guard/restoration, save/reload, equip the charm through the production API and launch a battle containing the existing trait. Failed writes, retries, repeated notifications, older saves and Reset journey cannot duplicate or lose the reward. Inspector information remains research filtered. See the implementation brief for the exact contracts and acceptance cases.

**Codex follow-up:** present rewards, inventory and preparation choices using existing textured UI; then Adrian tests whether the new option suggests a useful next outing. Backend completion alone does not pass that human test.

### 2. V0.5B — One useful Forge and a small Stillroom

**Dependency:** V0.5A's ownership, transaction and readout contracts are stable.

Implement a data-driven recipe/cost/eligibility model and atomic spending. Make one reversible weapon modification choice through existing traits; do not mutate shared weapon Resources. Define how saved weapon modifications enter EncounterEntry and UnitFactory. Mastery should unlock modification capacity or another behavior, not mandatory damage levels. Common starter equipment must remain viable.

Start the Stillroom with two or three recipes using the GDD's Base + Reagent + optional Catalyst vocabulary and existing PotionDefinition effects. Six recipes is the vertical-slice ceiling, not an initial target. With the current all-reset battle policy, a recipe can unlock a selectable preparation option; it must not silently introduce carried potion depletion. Specify that economy separately if it is wanted later.

Costs must be achievable from the bounded route without forcing a reset grind. Do not ship finite materials with mutually exclusive purchases that can permanently prevent completing the slice. Recipe prices, mastery thresholds, modification choices and refunds need a small Director specification before this batch is activated; Claude can propose the data/contracts while Codex designs the station screens.

**Exit:** spend → unlock/modify → save/reload → equip → battle works atomically; invalid requests and insufficient resources do nothing; two options have distinct tactical uses and fit the eight-action ceiling. Removing a modification restores the base item without duplicating grants or touching other saves/loadouts.

### 3. V0.5C — Complete the small exploration vocabulary

The original world-slice list is not complete just because First Footsteps is playable. Add one authored gathering node and one discoverable secret, then the first reusable puzzle grammar. Resonance Mirrors or a small rune sequence is enough for the first batch; Bloom Routing can be the second grammar later.

Claude owns typed definitions, deterministic interaction state, validation, reset/persistence policy and reward hooks. Codex owns placement, visual feedback, tiles and presentation. Keep the current authored areas; add surgical scene changes after the placements are agreed. Separate puzzle truth from scene visibility. Gathering refresh policy must be explicit, with no clock-based respawn and no Reset journey reward exploit. Avoid a generic quest framework until a second real objective demonstrates the need.

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
- Preserve the shared uncommitted dev tree. Do not commit/push, reset it, change release versions or overwrite authored areas as part of this handoff.

## Next handoff checkpoints

Each batch returns a short report with implemented behavior, changed contracts/files, save compatibility, exact tests actually run, unresolved defects, and the next Codex presentation task. Keep inherited evidence separate from new verification. The current immediate brief supplies named output reports and a small demonstration fixture so another fresh engineer can resume without reconstructing this conversation.
