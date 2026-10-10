# V0.5 playtest revision — Claude backend start prompt

10 October 2026 · prepared for Claude, Backend, Systems and Architecture Lead Engineer

You are continuing **Hollow Choir** at `C:\Users\Adrian\Code\Games\hollow-choir`.
Adrian requests the implementation below following his human review of integrated V0.5.
Codex is the Creative & Frontend Director and will work alongside you in a separate fresh chat.

Read these before editing:

1. `docs/reports/V0_5_PLAYTEST_REVISION_PLAN.md` — latest feedback, confirmed decisions, complete
   coverage matrix, required behaviors, file ownership and parallel/test protocol. This is the
   current assignment; older briefs' prohibitions on these specific new systems are superseded.
2. `docs/reports/V0_5_UI_BACKEND_IMPLEMENTATION.md` and `docs/DATA_CONTRACTS.md` — existing APIs.
3. `docs/reports/V0_5_UI_PRESENTATION.md` — the integrated frontend baseline and known test setup.
4. Current `git status`, relevant code and any applicable `AGENTS.md` instructions.

Preserve ALL uncommitted and untracked work. This is the shared `dev` checkout at application
**0.5.0 / save version 1**. Do not reset, commit, push, change versions, create a worktree/branch
or regenerate authored areas. No broader V2/V0.6, new regions, Pressure, bosses or new quest chain.

## First deliverable: publish the actual integration contract

Before changing dependent APIs, create
`docs/reports/V0_5_PLAYTEST_BACKEND_IMPLEMENTATION.md` with status **In progress**. Record chosen
architecture, actual typed names/fields/signals/methods, migration and supply-outcome policies,
provisional Break/crafting values and file ownership. Keep it current as implementation proceeds.
Tell Adrian when the contract is ready to pass to Codex. This is not a request to wait for routine
permission: continue independent backend implementation within this assignment.

Suggested names in the plan are illustrative. Publish a small stable contract and extend existing
typed readouts/transaction services; do not make the frontend reverse-engineer dictionaries or
derive affordability, ownership, source attribution, stock consumption or quest progression.
Keep old APIs usable during overlap where practical. Do not silently change a published contract
after Codex starts consuming it: document the change and its required consumer edits.

## Implement

### 1. Input and exploration defects

- Finish extra mouse button support end to end. `InputBindings` already supports `mouse:N`, but
  Settings capture accepts only keys/joypad buttons and prompts omit mouse. Supply reusable core
  validation/capture policy, middle/X1/X2 labels and persisted bindings. Preserve conflicts, Cancel,
  fresh-press/held-input gating and current defaults. Codex owns `settings_screen.gd` and will wire
  the screen from your documented helper/API. Do not edit that file in the parallel phase.
- Reproduce repeated movement taps into walls/corners. `WorldPlayer.step` already uses actual
  displacement, but the human sees a one-frame walk. Fix the cause without suppressing valid
  tangential movement, facing changes or real footsteps. Add the regression.
- Replace the encounter information/Engage modal with a three-second move-away countdown.
  Movement stays enabled. Leaving cancels; hysteresis rearms; only one stable site/entry can own
  the expiry. Pause/focus loss/modal contexts freeze it rather than reset it; cleared sites,
  transitions and overlapping triggers are handled deterministically. No write before expiry.
  At expiry use the existing atomic entry/snapshot/launch path. A failed write uses the existing
  frozen Retry flow, preserving intent and preventing a double launch. Publish remaining time,
  threat ID and active/cancelled state for Codex's small world indicator. No roaming enemy AI.
- Add a bounded typed quest journal for the existing bell journey/objective stages. Reuse current
  world truth and the `quests` save placeholder where appropriate. Supply active/completed public
  entries and an adopted change event. Load/open/rebuild must not replay acquisition notices;
  old-save sanitation and Reset journey must agree with the world. No new quest rewards/content.

### 2. Shared ingredient and unified Loadout facts

- Publish all currently approved player-facing materials in stable order with zero quantities,
  names/icons/details. Keep unknown IDs inert and ownership separate from catalog visibility.
- Equipment and Combat will merge into one Loadout view. Supply stable gear/source/action IDs,
  authored grants and selectable/rejection facts. Each gear row supports up to three action icons.
  Preserve existing stance, Inspect, innate Spark/Kindle and all current grants: do not truncate the
  weapon's four actions to satisfy a three-icon strip or attribute innate spells to an empty relic.
  Expose a truthful supplemental Core/stance group for those actions. No invented new spells.
- **Confirmed by Adrian: six usable action positions, two locked.** Keep existing deterministic
  reconciliation, no duplicates, source membership, real battle ordering and immutable entry
  snapshot/retry. Return structured removed/added/kept facts, not a prose block for the UI to dump.
- Supply actual prepared item inspection facts/stock/cap for every slot. Four supply positions are
  displayed; currently two usable. Three fitting sockets displayed; currently one usable. Do not
  unlock capacity as a side effect of the redesign. Inventory has 20 display cells, but capacity
  remains 10/15 from current progression. Backend remains authority for all locks.
- Add owned familiar/pet selection and one selected authored passive from up to three choices.
  Reuse the existing familiar definitions/system and retain `trait_def` as legacy one-choice data.
  Validate membership/ownership, save selection atomically and capture it in entry snapshots. A
  familiar still has no turn/target/HP. Active passives, selectable pet passives and weapon mastery
  facts are distinct. Use current pets/content rather than building a new pet framework.

### 3. Finite brewing and battle consumption

**Confirmed by Adrian: each brew spends ingredients and produces limited supplies.** The old
permanent-unlock/per-encounter refill model cannot be left in place behind a renamed button.

- Repeatable atomic Brew: access/mastery/service validation → affordability and overflow checks →
  candidate spend/stock increase → write → adopt → produced receipt. No auto-prepare side effect.
- Separate learned recipe/access, owned finite stock, prepared slot choices and battle allowance.
  Publish cost/yield/held/available/prepared/usable facts and concise rejection codes.
- Recommended starting model: saved stock counts doses (one use = one unit), batch yield is
  authored, and existing `PotionDefinition.charges` remains a per-slot encounter cap unless you
  explicitly split it into another data field. Never refill above owned stock. Preserve existing
  potion effects. Keep current duplicate-type and capacity rules. Stock uses no equipment cells.
- Include a documented finite starter supply batch and brew-access/cost policy for existing
  starter potions using current ingredients. Do not leave unlimited starter refills by accident.
- Document and test exact stock outcomes for victory, failed save/Retry, defeat/Retry, defeat/home,
  Leave battle, quit/reload and old pending entries. Preferred checkpoint policy: Retry restores
  the same immutable attempt allowance; a concluded accepted attempt settles actual uses exactly
  once. Unfinished quit/reload follows the documented pending-entry policy. Choose a safe
  reservation/settlement or equivalent architecture; never derive consumption from UI callbacks.
- Migrate old recipe access/prepared potions to a bounded one-time stock grant with a durable marker.
  A legitimately exhausted stock of zero must never trigger migration again. Reset journey grants
  no refill. Preserve Practice isolation and record any Lab implications explicitly.
- Existing rewards/material sources are mostly one-time. Do not invent farms/merchants/free
  refills to hide scarcity. Potion-free combat remains possible; economy tuning stays open.

### 4. Craft fittings instead of buying kits

- Add direct per-fitting craft ownership, costs and compatible-socket facts using current approved
  fittings. Unowned option → Craft; owned option → Fit/Remove. Installing/removing an owned fitting
  does not spend again. All mutations require the exact open Forge service and preserve trait/
  weapon/action constraints, whole-transaction rejection and no-op behavior.
- Preserve one usable socket and existing mastery gate. Proposed provisional per-fitting price is
  the old two-Bog-Iron kit price; publish actual data values and flag economy consequences.
- Remove kit purchase from the new public UI contract. Older paid kits need a non-lossy migration:
  default to grandfathering their previous fitting choices and preserve the installed fitting.
  Document legacy refund rights/value safely; no automatic load refund, duplicate reimbursement or
  working fitting loss. Keep a compatible legacy path if needed. No new dismantle mechanic.

### 5. Hollow and companion Break

- Add **independent** current/max Break to both controlled party members, using existing battle
  rule/event/turn architecture. One unit breaks for its next activation and recovers independently.
- Successful Parry keeps existing Focus gain and pays configured defender Break once per resolved
  reaction; it must not accidentally charge per hit in a multi-hit sequence. Define baseline
  incoming Break damage, successful Brace mitigation and successful Evade avoidance in data/config.
  Keep existing HP/reaction timing/effect outcomes except the authorized Break extension.
- Publish ordering for failed reactions, AOE/multi-hit, Intercept, damage-over-time, lethal hits,
  simultaneous breaks and breaking during a reaction. Proposed party policy: no reactions while
  Broken; skip next activation, then recover. Do not inherit enemy weak points, growing caps,
  vulnerability bonuses or Break Focus rewards onto party members accidentally.
- Current `StaggerRules` explicitly calls enemy definitions and rejects non-enemies. Refactor/
  extend safely rather than merely removing its enemy guard. Keep enemy Break behavior intact.
- Provide deterministic events, preview/readout facts and presentation ledger values for both
  party bars. UI does no rule mutation. Add replay/seeded tests; changed outcomes are expected for
  this authorized mechanic, but nondeterminism and unrelated balance changes are not.

### 6. Save, operation sound and outcome facts

- Add authoritative manual/automatic origin to successful save facts while retaining one owner.
  Explicit Save/Save-and-return/Save-and-quit → normal compact save confirmation. All automatic
  writes → quiet short icon, no noise/card. Preserve atomic write/adopt, no event on rejection,
  no-op or failure; don't remove actual autosaves. Preserve legacy `game_saved` consumers or migrate
  them deliberately. Director uses one presentation path, not both events for the same write.
- Expose adopted changed-operation facts for equip/unequip, prepared supply, Brew, Craft, Fit/
  Remove and current purchases. Reuse `crafting_completed` where possible. Director plays sounds
  once from these facts; do not scatter duplicate UI/SFX ownership across host and widgets.
- You exclusively own `AudioManager` additions. Proposed new cues: UI_EQUIP, UI_UNEQUIP,
  CRAFT_SMITH, CRAFT_BREW and PURCHASE (UI_MOVE/UI_CONFIRM/UI_CANCEL already exist). Document exact
  enum/file names for Director-created assets; append enum values to preserve existing indices.
  Assets missing during the overlap should retain the current safe no-op loader behavior.
- Return saved Bestiary Learnings as enemy ID/public name/icon/old tier/new tier plus existing
  salvage receipts. Capture before adoption and preserve the old value through failed-write
  Retry. No transition for no tier increase; no hidden knowledge leak or duplicate grants.
  Codex will remove excess victory prose and the redundant outcome inspector.

## Parallel ownership — enforce this

You own backend/data/save/rules/tests and **exclusive routing edits** to
`src/world/world_host.gd`, `scenes/battle/battle_scene.gd`, `src/autoload/audio_manager.gd`,
`src/ui/battle/presentation/presentation_ledger.gd` and
`src/ui/battle/presentation/unit_readout.gd` during the overlap. See plan §3 for the exact test split.
You own `docs/DATA_CONTRACTS.md` and your new return report/test note.

Codex owns the other UI files, main menu/settings views, `world_copy.gd`, art/SFX assets, capture
tools, Director UI tests, Decision Log, GDD, testing index and return queue. Do not restyle or edit
those. Publish reason enums/facts; list exact requested consumer changes in your report. As soon
as view APIs are available, wire them in your exclusively owned host files. If views are not yet
ready, keep compatible current consumers and document the final wiring required.

Do not message another chat/person automatically. Give Adrian the concise contract/return to
pass across. No concurrent imports/suites/captures in the shared checkout; you own the Godot
execution window first. Transfer it explicitly when you finish. Separate isolated user homes
protect saves/settings but do not remove the shared project-cache/timing hazard.

## Verification and final return

Use `tools/qa_godot.py` with unique homes under `.godot/qa-playtest-revision/`. Known local tools:
`C:\Users\Adrian\Code\Games\Godot_v4.7.2-stable_win64_console.exe` and
`C:\Users\Adrian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`.
Run all-script compile, full headless and full Compatibility/Dummy suites sequentially, relevant
determinism/replay/simulation checks, and affected validators. Do not claim historical 452-test
results as new evidence or weaken transactional tests because a redesigned view changed labels.

Finish the return report with changed files/contracts, source/slot capacities, migration/refund/
consumption policies, provisional values, exact tests and results, expected diagnostics, regressions,
remaining work, and precise integration edits for Codex. State when the Godot execution window is
free. Human control/art/listening/balance gates stay open. Do not declare V2 complete.
