# Fresh Claude assignment — recover V0.4, then V0.5A backend

Prepared 9 October 2026 at Adrian's request. Work in C:/Users/Adrian/Code/Games/hollow-choir. This is the bounded implementation assignment to give the replacement Claude instance; do not implement the later roadmap stages in this session.

## Objective and reading order

Finish the interrupted fifth-playtest engineering review, then implement **Salvage and Preparation backend**: persistent rewards from existing world accomplishments, validated inventory/equipment commands and typed presentation readouts. Prove that existing earned equipment changes the next battle setup. Codex owns the UI/art integration afterward.

Read in this order:

1. This brief and [the staged roadmap](../design/V05_BACKEND_ROADMAP.md).
2. [GDD current authority and original loop/systems/roadmap](../DESIGN_DOCUMENT.md). Relevant headings: The core game loop; The crucial progression principle; Equipment upgrades; Potions and alchemy; Home base; The vertical slice; Development roadmap.
3. [Fifth engineering brief](V0_4_FIFTH_PLAYTEST_ENGINEERING.md) and [fifth presentation report](../reports/V0_4_FIFTH_PLAYTEST_POLISH.md). The [third engineering review](../reports/V0_4_THIRD_PLAYTEST_ENGINEERING_REVIEW.md) records completed backend fixes; the fourth brief is linked from the fifth.
4. [Data contracts](../DATA_CONTRACTS.md), [testing/isolation policy](../TESTING.md), and relevant current code before designing new classes.

This brief scopes the next assignment beyond V0.4's historical no-rewards/no-new-systems hold. That exception covers only the rewards, inventory, preparation and supporting definitions described here. Existing combat/reset/knowledge/display rules remain authoritative. V0.5A is a working milestone label; application version remains 0.3.0 and save version remains 1 unless a genuinely incompatible schema change requires a documented migration.

## Inherited state: do not start over

The shared dev tree contains substantial uncommitted work after 6d8401d, including authored scenes and bitmap UI, music, SFX, animations and backend fixes. Inventory relevant changes before editing. Do not revert, commit, push or force-regenerate world areas. Do not bump release versions for this task.

The last Claude instance appears to have started the fifth engineering pass:

- tests/ui/test_fifth_engineering.gd covers pinned snapshot survival through target review, actual details key/mode wording, conditional weak-point help and announcement fades at combat speeds.
- tests/unit/test_action_capacity.gd inventories authored loadouts against the eight-action ceiling.
- Corresponding production changes are present, including ActionMenu.CAPACITY and speed-aware Banner fades. Audit these rather than duplicate them.
- docs/reports/V0_4_FIFTH_PLAYTEST_ENGINEERING_REVIEW.md has not been written. Their existence is not evidence that these new tests passed.

Preserve the latest fixed centered two-column action grid, eight-action capacity, no action scrollbar, larger docks, ally/enemy turn announcements, right-click inspection snapshots with local field help, symmetric spacing, v05 idle mask and textured assets. The old generic CLAUDE_PROMPT.md prohibition on pinned inspection is historical and superseded by the fifth brief.

First finish that review, fix actual defects, and write the missing report. Do not reimplement completed action switching, journey reset, root collisions, victory-return position/arming or audio teardown. Report nonblocking remaining human observations and proceed to the new backend batch; fix save/submission blockers before connecting rewards.

## V0.5A scope

### 1. Definitions, inventory and reward planning

Use small typed Resource definitions indexed/validated through DefinitionRegistry. Proposed names such as MaterialDefinition, RewardDefinition and RewardReadout are suggestions; follow the existing architecture rather than adding a manager for every noun.

Reuse ProgressState.owned_equipment and materials. Add an optional, plain-data reward-claim section outside ProgressState.world so Reset journey retains claims. Stable campaign reward IDs determine eligibility; an encounter token alone is insufficient because reset creates a new token for the same site. Store no Nodes or mutable Resources in saves.

Starting content is deliberately small. These are provisional slice quantities, stored as data so Codex can tune them later:

| Source | Stable claim ID | Reward |
|---|---|---|
| First committed reedway_patrol victory | first_footsteps.patrol | 2 Bog Iron (material ID bog_iron) |
| First committed bell_guard victory | first_footsteps.guard | 2 Bog Iron + 1 Storm Salt (material ID storm_salt) |
| Deliberate wayside bell restoration | first_footsteps.restoration | Existing equipment storm_salt_charm |

Treat the materials as site salvage, not a claim about undiscovered enemy drop tables. No random drops, new enemy behavior, additional encounters, reward choices, purchases or crafting are needed. Keep claiming separate from discovery: standing near the bell or defeating the guard must not award the restoration reward. Repeated grants of an already-owned equipment ID never duplicate that item.

Validate duplicate reward IDs, source references, material/equipment references, allowed kinds, positive bounded counts and arithmetic overflow. Use deterministic ordering. Readouts expose known item names/descriptions/icons where available, counts, eligibility/lock reasons and equipped state; do not read hidden enemy stats or manufacture unknown species information for a reward preview.

### 2. Transaction boundaries and compatibility

Integrate eligible victory rewards into the existing WorldSession.commit_victory candidate, together with research/mastery, clear state, pending-entry closure and token receipt. Integrate the restoration grant into the restore_bell candidate. A reward is not a second independent save after the world action.

Use the existing copy → mutate → write → adopt boundary. A failed write changes neither live inventory nor claims/world/loadout, and emits no successful reward notification. Retry applies it once. Publish typed receipts/events only after adoption. Do not move world rewards into generic GameState.record_battle: Practice awards none, and the Lab's optional existing research/mastery recording must not become a salvage source.

Support old save-version-1 slots without a global reset:

- Missing reward data defaults safely. Existing research, mastery, stats, loadout and unrelated sections survive round trips.
- An explicit, transactional reconciliation command may grant the above rewards once for accomplishments still present in the old world state: cleared patrol, cleared guard, restored bell. This prevents a completed old journey from losing access to the new option. Do not award from merely discovered sites or infer an accomplishment erased by an earlier reset.
- Reconciliation must run through the same atomic boundary, return a clear success/failure result for the caller, and be wired at the world-entry boundary with the existing save-error/retry handling. Do not mutate or write a save from a pure deserializer. Keep WorldSession.open's interrupted-entry recovery behavior intact.
- Once claims exist, Reset journey retains them and all inventory. Repeating either site or restoring the bell after reset cannot farm rewards. New Game legitimately starts new claims.
- Unknown/wrong-type new fields cannot create rewards, negative inventory, unlocks or crashes. Validate new data against approved definitions. Preserve unrelated legacy data; document any repairs and test them.

No incompatible change is required by this plan. Use additive fields with safe defaults; if implementation reveals one, explain it and add a real migration instead of silently repurposing a field or bumping game_version as a substitute.

### 3. Ownership-aware preparation commands

Expose a small campaign preparation API for weapon, garb, charm and relic slots. It must reject unknown, unowned and wrong-slot equipment, allow removing optional armor slots, enforce the party's action ceiling without silently dropping actions, and commit successful changes atomically. Report useful rejection reasons in typed results/readouts. No new action is authorized to fill the eighth slot.

Make the bench's backend weapon listing include all valid owned weapons, not just WorldRules.STARTER_LOADOUTS. Keep the three existing starter weapons available. Provide typed lists for each equipment slot with selected/equipped state and public trait descriptions, plus inventory and reward readouts. Keep gameplay validation out of widgets and avoid a pure rule depending on a UI class just to obtain the action limit.

Retain valid legacy equipped gear by treating it as owned during explicit compatibility reconciliation; do not strip a player's loadout merely because older tooling did not populate ownership consistently. Unknown/wrong-slot IDs must not be grandfathered. Restore a safe valid starter weapon when needed. Distinguish campaign ownership validation from PartyLoadout.from_ids, the sandbox and static content fixtures: the Lab/Practice can still audition unearned content.

Do not add potion consumption to persistent inventory. Existing two prepared potion slots and per-battle capacities remain unchanged. Companion/familiar recruitment, relationship upgrades and potion unlock menus are later work.

Preparation changes apply to a **new** EncounterEntry. An existing entry/retry remains immutable even if live progress subsequently changes. Commands must reject an active/pending world encounter rather than allowing field equipment changes. Also reject campaign preparation away from the preparation station. Use a session-owned station context that ends when the interaction closes; neither a hidden UI button nor the last saved safe anchor proves that the player is still at the bench. The isolated fixture can enter the station through the real production path.

### 4. Integration surface, not a presentation redesign

Connect reward/reconciliation lifecycle hooks and return typed receipts/readouts. Provide the production preparation commands and a small developer demonstration script or integration fixture using them. It should print only public results under isolated QA and show: world accomplishment → persistent reward → station equipment choice → next entry contains the authored trait.

Codex will add the final inventory/station/reward screens and visual feedback. You may make minimal lifecycle/error-handling adapters needed to exercise the backend, but do not redesign the current bench, HUD, inspector, menus or combat UI. Report clearly which APIs are available only to fixtures and which user-facing paths are already connected; do not call an invisible backend an accepted gameplay loop.

## Acceptance cases

Use focused behavioral tests, including real production commands and an injected failed writer:

1. New game → patrol victory → material counts and claim saved once; guard/restoration have independent eligibility.
2. Duplicate result, retry after failed write, reset/replay, reload and repeated restoration cannot duplicate any grant.
3. Defeat, abandoning an entry, interrupted-entry recovery, Practice and recording Lab award no new salvage. Preserve their existing research/mastery policies.
4. Failed victory/restoration/reconciliation/equip writes leave all live state unchanged and emit no success event; retry produces one successful change.
5. Older save without new fields and a completed journey receives only its provable catch-up grants; a second reconciliation is a no-op; incomplete/unrestored saves receive only eligible rewards.
6. Unknown IDs, malformed counts/claims, wrong-slot or unowned gear and invalid contexts are safely rejected/repaired as documented. Optional unequip works; starter choices and valid legacy equipment survive.
7. Equip storm_salt_charm through the campaign station API → save/reload → new entry → party contains the existing Grounding trait. Verify a real Wet/Shock interaction through the combat engine, reusing current effect expectations rather than changing balance. A captured entry/retry keeps its original loadout.
8. Readouts agree with actual ownership, rejection reasons and equipped state; do not leak research-gated combat information. Returned data cannot mutate shared definitions or the persisted snapshot.
9. All shipped valid party configurations still fit eight actions. Overflow rejects the new loadout as a whole; it does not truncate, introduce scrolling or hide a stance/Inspect action.

Run targeted tests while implementing, then the appropriate complete suite and script/content validation once the integration settles. For inherited fifth-pass UI/input behavior, use the hidden native Compatibility window where necessary. Do not repeatedly run the full regression suite for a cosmetic centering adjustment; Adrian explicitly waived that tiny change. New save/gameplay behavior does need meaningful tests.

All Godot runs use tools/qa_godot.py with isolated .godot/qa homes, never the player's real saves/settings. See docs/TESTING.md. On this host the console executable is C:/Users/Adrian/Code/Games/Godot_v4.7.2-stable_win64_console.exe; Python is available at C:/Users/Adrian/AppData/Local/Python/bin/python.exe. Example (PowerShell):

~~~powershell
& 'C:/Users/Adrian/AppData/Local/Python/bin/python.exe' tools/qa_godot.py --home .godot/qa/v05a-tests --godot 'C:/Users/Adrian/Code/Games/Godot_v4.7.2-stable_win64_console.exe' --headless --script res://tests/run_tests.gd
~~~

Reimport through the launcher after adding class_name scripts. Run wall-clock/widget suites alone. Old fifth-presentation counts (304 tests / 4,117 assertions and rendered 5 / 87) predate the last small edits and interrupted Claude changes: they are inherited reference points, not a current result.

## Return package and stopping point

1. docs/reports/V0_4_FIFTH_PLAYTEST_ENGINEERING_REVIEW.md — finish the interrupted review; distinguish inherited work from verified changes.
2. docs/reports/V0_5A_BACKEND_IMPLEMENTATION.md — actual behavior, files/contracts, reward quantities, save/reset compatibility, lifecycle integration, exact verification results and remaining limitations.
3. A concise API/fixture guide in that report for Codex: how to obtain readouts, invoke preparation, present successful rewards, retry failures and test against isolated data.
4. Update DATA_CONTRACTS.md and relevant testing/return-queue notes for implemented behavior. Do not mark the human acceptance gate passed or rewrite the historical GDD examples as already shipped features.

Finish the bounded batch, report and stop. Forge sockets/mastery unlocks, recipes/spending, gathering/puzzles, Pressure, quests, new areas, new enemies, weapon families, attrition and broader economy are later assignments. See the roadmap rather than starting them opportunistically.
