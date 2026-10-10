# V0.5 human feedback — revision plan and parallel ownership

10 October 2026 · Adrian's latest playtest · prepared by Codex, Creative & Frontend Director

**Assignment plan retained; implementation now tracked in the
[Director report](V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md) and
[backend report](V0_5_PLAYTEST_BACKEND_IMPLEMENTATION.md).** The preceding chat completed planning
only. The current Director pass implements and renders the presentation; backend verification and
human acceptance remain explicit gates in those reports.
Application remains **0.5.0**, save version **1**, on the shared uncommitted `dev` tree.
The earlier integrated build is the baseline, not a release or a claim that human acceptance passed.
This document records the new feedback and supersedes conflicting presentation requirements in
older V0.5 briefs for this assignment. It does not authorize the rest of the V0.6/V2 roadmap.

- [Claude's complete implementation prompt](../briefs/V0_5_PLAYTEST_BACKEND_PROMPT.md)
- [Codex's fresh-chat implementation prompt](../briefs/V0_5_PLAYTEST_DIRECTOR_RESTART_PROMPT.md)
- [Previous integrated presentation and evidence](V0_5_UI_PRESENTATION.md)
- [Previous backend contracts and implementation](V0_5_UI_BACKEND_IMPLEMENTATION.md)
- [Previous integrated human checklist](../playtests/V0_5_INTEGRATED_TEST.md)
- [User's reward/tooltip screenshot](v0_5_playtest_feedback/reward-tooltip-overlap.png)

## 1. Confirmed direction and bounded interpretations

Adrian confirmed during planning:

1. **Keep six usable combat positions and two locked.** Eight positions remain visible. This
   redesign does not grant extra capacity or remove the hard eight-action ceiling.
2. **Brew limited supplies each time.** Brewing spends ingredients and produces a finite saved
   quantity. This replaces the current permanent potion-unlock/per-encounter refill model for
   brewed supplies; changing the button's name alone is insufficient.

The rest follows the feedback, with these explicit planning defaults:

- Hollow and the companion have **separate Break meters**, not one shared party resource.
  Each can lose one activation independently. Successful Parry still earns its existing Focus
  and now costs some of the defender's Break. Values are provisional; balance is a later pass.
- Equipment and Combat become **one Loadout page**. Inventory and Field Guide stay accessible.
  Weapon, garb/robe, charm and relic each support up to three associated action icons. Pet sits
  below relic, offering up to three passive choices with exactly one selected. Existing content
  may supply fewer choices; the UI must not invent missing actions or passives.
- Four supply positions and three Forge sockets remain visible. Their **actual usable capacities
  stay backend facts**: presently two supply positions and one fitting socket. Adrian has not
  authorized additional capacity unlocks. Locked and usable cells have identical outer dimensions.
- Inventory shows **20 cells in four rows of five**. Only the actual earned capacity is usable:
  presently 10, or 15 after the existing bell reward. Remaining cells show locks. Drawing 20 cells
  grants no capacity and changes no reward.
- All currently authored, player-facing ingredients appear in one non-scrolling horizontal strip,
  including quantity **0**. This means the approved material catalog, not every raw registry entry
  or future hidden content. Inventory, Stillroom and Forge use the same component/order.
- Craft individual fittings using salvage; remove fitting-kit purchase from the new public flow.
  Existing installed fittings, paid kits, mastery and old saves need a non-lossy compatibility policy.
- Quest log covers the existing bell journey and its current objective stages. No new quest chain,
  reward, Pressure, NPC arc or region is part of this request.
- The three-second encounter approach is a **move-away countdown**, not a key-press minigame.
  Movement stays available; leaving the threat area cancels it. The information modal is removed.
- Tooltip styling means one smaller, wrapped, bounded design system. It does not add an independent
  player font-size setting or change the fixed 1280×720 canvas/display preset policy.
- **Background answer:** `BattleScene.start` assigns `defaults.battle_backdrop`; `defaults.tres`
  names one image. Existing day/night alternatives do **not** rotate randomly. This was deliberate
  in `STAGE_PRESENTATION_REFRESH.md`. Audit/document this; no random cycling is requested yet.

Suggested implementation details below are a plan, not claims about existing APIs. Claude may
choose better internal names/structures while delivering the same behavior and publishing the
actual contract before Codex connects dependent screens.

## 2. Feedback coverage and acceptance

Owner abbreviations: **Director** = Codex presentation; **Backend** = Claude rules, state and
persistence; **Both** = Claude supplies facts/commands, Director presents them.

| ID | Feedback / resulting behavior | Owner | Review that closes it |
|---|---|---|---|
| S01 | Soft hover/highlight sound and distinct selection sound throughout menus | Director | Mouse and keyboard/controller focus sound once per change; rebuilding a screen does not chatter |
| S02 | Equip and unequip sounds | Both | Cue follows a successful changed operation, never a failed write or re-choice |
| S03 | Purchase, craft/smith, brew and fit interaction sounds | Both | Appropriate material cue once after adopted success; no duplicate generic-confirm/success cue |
| T01 | Remove “Where the old song takes root” and the logo's surrounding frame | Director | Title composition contains neither |
| T02 | Shade behind logo, gentle local smoothing, a few drifting green motes/wisps | Director | Logo remains legible; UI text stays crisp; reduced motion/flashing respected |
| T03 | Version at bottom right | Director | Reads actual project version and stays inside safe margins |
| T04 | New Journey tooltip is too large and runs off screen | Director | Shared smaller wrapped tooltip fits all four canvas edges at every display preset |
| U01 | Make tooltip font, width, padding, placement and detailed styling consistent game-wide | Director | Title, items, rewards, actions, settings and keyboard focus use the same policy; no duplicate native tooltip |
| U02 | Settings, battle log and Field Guide scrollbars look stretched/pixelated | Director | Shared art uses correct slice/tile geometry and stable width at short and long thumb sizes |
| U03 | Settings checkboxes use old art, lose their frame on hover and change row height | Director | Existing checkmark asset; identical minimum size/padding in normal, hover, checked, focus and disabled states |
| I01 | Controls cannot capture extra mouse buttons | Both | Middle/X1/X2 capture, labels, persistence, reload, conflict handling and actual actions work; opening click is not rebound |
| D01 | NPC text cannot be scrolled back | Director | Wheel and keyboard/controller scrolling work; typewriter follow stops while browsing earlier text and resumes deliberately |
| E01 | Repeated movement taps into a wall flash a walking frame | Backend | Repeated wall/corner taps and held movement remain idle with no footsteps when blocked; real sliding still animates |
| E02 | Remove pre-encounter information/Engage box; start after three seconds unless player moves away | Both | Movement stays live, cancel/rearm is stable, expiry launches once; pause/focus loss and save failure are safe |
| E03 | Floating objective needs a quest log and brief new-quest text/icon attention | Both | Current task is readable in a journal; brief acquisition/update text fades, icon softly pulses; load does not reannounce everything |
| C01 | Remove the residual tilt of Broken enemy models | Director | Upright floor anchor remains stable while Broken icon/bar state still communicates the condition |
| C02 | Brace/Evade/Parry indicators are hidden behind shrinking circle | Director | All three remain above/in front of the ring for the entire timing sequence without changing its timing |
| C03 | Explain whether battle backgrounds cycle | Director | Report current single configured backdrop; keep random scenery independent of simulation if separately requested later |
| C04 | Add individual Hollow/companion Break and Parry cost | Both | Independent readable bars, one lost activation, recovery, deterministic events/replay; Brace/Evade offer distinct Break outcomes |
| C05 | Simplify victory to Bestiary Learnings and Salvage | Both | Enemy icon/name and old → new knowledge tier only when changed; accurate saved receipts; no explanatory paragraphs |
| C06 | Salvage title/list padding and overly large frame | Director | Content-sized compact outcome with safe border insets and a clear Continue action |
| C07 | Equipment slots +5 has inconsistent border | Director | Capacity reward uses same row treatment as other rewards in all focus/hover states |
| C08 | Reward tooltip overflows and info box covers Storm Salt Charm | Director | One bounded tooltip on rewards; remove redundant fixed info box in these popups; both reward rows remain visible |
| L01 | Equip action appearing shifts portrait, supply row and info box | Director | Reserve action/selection areas; selecting, equipping and clearing a slot does not move surrounding layout |
| L02 | Prepared supply slots show generic selection hint rather than their contents | Both | Each occupied slot exposes actual item effects, held quantity and usable charges/cap; empty/locked slots have their own short state |
| L03 | Inventory info panel higher, 20 visible cells, panel matches grid height | Director | Four equal rows beside aligned detail panel; bottom region remains available for ingredients |
| L04 | Ingredients horizontal, icons with quantities, all approved ingredients including zero | Both | Same non-scrolling strip in all three menus, stable order, no initial ingredient highlight stealing focus |
| L05 | Remove confusing separate Skills placement tab, shrink candidate icons, put passives below | Director | Active choices and passive icons are visually distinct; passive cannot be placed in an action position |
| L06 | Remove the massive weapon-change text block | Both | Backend returns structured reconciliation facts; Director uses highlights/short status rather than dumping summary paragraphs |
| L07 | Merge Equipment and Combat: small portrait/gear, three action subslots per source, eight combat positions right | Both | Select destination then source icon; active sources highlight; six usable/two locked; exact order reaches real battle/reload |
| L08 | Pet below relic, up to three passives, choose one | Both | Owned pet swap and selected passive are saved/validated; active passive icons agree with actual battle traits |
| L09 | Four supply slots and gear open small candidate popups | Both | Owned and eligible choices only; popup supports mouse/focus/cancel, returns to original slot, shows locks honestly |
| F01 | Field Guide research bar touches scrollbar | Director | Content/right gutter separates bar and scrollbar at all research levels and scroll positions |
| A01 | Stillroom and Forge share the new ingredient strip | Both | Complete approved catalog with zero quantities and correct post-transaction refresh |
| A02 | Help is low/misaligned | Director | One consistent header anchor, top right and centered in its button, on both stations |
| A03 | Locked slots narrower; all slots could be smaller | Director | Shared compact slot metric and equal locked/filled cell geometry across Character/stations |
| A04 | Owned/prepared supplies and purchasable recipes are mixed | Both | Stillroom has Prepared at top left, Unprepared stock below, separate Brew catalog/details at top right |
| A05 | “Unlocked” alone gives no useful acquisition feedback | Both | Brew shows produced item and quantity, stock increases, affordable button state refreshes; sound only on success |
| A06 | Price belongs with item details, status has no hierarchy | Director | Cost icons/required and held counts in details; short ownership/availability state visually separated from description |
| A07 | Brew only with ingredients; produce limited supplies | Backend | Repeated paid batches, stock overflow/insufficient ingredients rejected atomically, actual battle use consumes finite stock exactly once |
| A08 | Forge descriptions too verbose, slots too large, help/ingredients inconsistent | Director | Structured effects, costs and short state; same shared components as Stillroom |
| A09 | Three Forge sockets offset left; select socket to show candidates on right | Both | Symmetric aligned row; selected socket drives compatible candidates; locks come from backend |
| A10 | Craft fittings directly, uncrafted choice shows Craft rather than Fit | Backend | Owned fitting shows Fit/Remove; unowned shows cost and Craft; stale/direct commands enforce ownership and service |
| N01 | Large save popup only on explicit save; autosave a quiet brief icon | Both | Manual vs automatic origin is authoritative; no autosave sound/card; same atomic writes, no duplicate events |

## 3. Parallel work and file ownership

Two fresh chats may work in this **same uncommitted checkout**. Do not create commits, branches,
worktrees, pushes, resets or version bumps as routine handoff work. Do not regenerate area scenes.
Inspect status first. Existing modified and untracked files belong to the integrated baseline.

### Claude owns

- `src/battle/**`, `src/data/**`, `src/progression/**`, `src/save/**`, `src/core/input_bindings.gd`
  and backend settings serialization where required; approved gameplay resources under `data/**`.
- `src/world/world_session.gd`, `world_rules.gd`, `world_state.gd`, `world_player.gd`, encounter
  snapshots, backend world definitions/readouts and new quest/countdown rules.
- `src/autoload/game_state.gd`, `save_manager.gd`, `event_bus.gd`, and **`audio_manager.gd`**
  for cue/API additions (Director owns sound design/assets and UI routing).
- **Exclusive integration ownership of `src/world/world_host.gd` and
  `scenes/battle/battle_scene.gd` during the parallel phase.** These combine routing and gameplay;
  both chats editing them would collide. Implement minimal contract/routing changes here, retaining
  existing views until replacements are ready. Do not redesign the screens.
- Technical event playback fields in `src/ui/battle/presentation/presentation_ledger.gd` and
  public party Break facts in `src/ui/battle/presentation/unit_readout.gd`. These are explicit
  exceptions to Director's general `src/ui/**` ownership. Publish event order/fields before UI use.
- Backend/unit tests and backend world suites; `docs/DATA_CONTRACTS.md`, a new backend return
  report and a separate backend test note. Do not edit the Director-owned documentation below.

### Codex owns

- `src/ui/**` except the two technical files above; `scenes/main/main_menu.gd` and
  `scenes/main/settings_screen.gd`, presentation shaders/components and presentation assets.
- `src/world/world_copy.gd` (text only; Claude returns reason codes/facts instead of editing copy).
- UI SFX assets, sound palette documentation and a new presentation feedback adapter; agree cue
  enum names with Claude rather than both editing `AudioManager`.
- UI suites under `tests/ui/**`; `tests/world/test_world_ui_prototype.gd`,
  `test_world_character_menu.gd`, `test_world_journey_setup.gd` and
  `test_world_v05_integration.gd`; presentation capture tools and evidence.
- `docs/DESIGN_DOCUMENT.md`, `docs/DECISION_LOG.md`, `docs/TESTING.md`,
  `docs/briefs/CLAUDE_RETURN_QUEUE.md`, this plan, and a separate Director implementation report.

Claude retains `tests/world/test_world_combat_arrangement.gd` plus crafting/preparation/reward/
save-event/exploration/host suites during this phase. If a protected test needs a UI assertion
updated, record the exact needed change for its owner; preserve the functional coverage.

**No file has two simultaneous writers.** A needed cross-owner change goes in the return note
with file/function and required behavior, or transfers ownership explicitly before editing.
Existing methods/readouts stay compatible through the overlap where practical; publish additive
contracts first, then retire superseded paths after both consumers are integrated.

### Sequence and checkpoints

| Phase | Claude | Codex | Gate |
|---|---|---|---|
| 0 — contract first | Publish actual readout/command/event names, migration and outcome policies | Read plan, establish compact metrics/component API and capture baseline | New consumers have a documented contract; no guessed production API |
| 1 — independent changes | Controls core, movement defect, save origin, catalogs, countdown and bounded quest state | Title, shared tooltip/scroll/check styles, dialogue scrolling, Broken tilt, reaction layering, Field Guide gutter | Existing behavior/tests remain usable |
| 2 — major systems | Gear-source loadout/pet, finite brewing/consumption, direct fitting ownership, party Break, structured victory learnings | Build new views/components with explicit capture/test fixtures | Fixture art is labelled; no gameplay facts or eligibility invented in views |
| 3 — integration | Wire new view signals/readouts in the two exclusively owned host scenes | Connect views to published contracts and replace fixture providers | One actual operation path; save/failure/retry and real battle checked |
| 4 — verification | Backend regressions, determinism/replay and migration evidence | Rendered UI evidence, input/audio checks, final copy and decision documentation | Full sequential QA, then Adrian's human acceptance |

No full Godot suites, imports, rendered captures or timing tests run simultaneously in this
checkout. Distinct `user://` homes do not isolate the shared project `.godot` cache. In the parallel
phase Claude owns the engine/import/test window; Codex can edit independent files and inspect
existing images. Explicitly transfer that window in the return note before Director captures/full
QA. If testing overlaps ongoing edits, record the tested file state and rerun after integration.

Coordination is through these files and each chat's user-visible return. Neither prompt authorizes
messaging another chat/person automatically. Adrian can pass the contract/return note between chats.

## 4. Backend contracts needed by presentation

These are required facts/behaviors, with suggested grouping rather than fixed class names.

### Public ingredient catalog

Supply ordered stable IDs, names, icons, descriptions and nonnegative held quantities, including
zero. Separate “available to display” from “owned.” Keep unknown saved IDs inert. Reuse approved
material definitions; the UI must not enumerate hidden content or calculate spending eligibility.

### Unified Loadout and source actions

Publish each gear slot's equipped item, allowed choices, empty/required/locked state, authored
actions by source, and current arrangement membership. Source IDs must be stable, not display names.
Three cells per equipment source is a compact layout requirement, **not permission to truncate**
the current weapon's basic attack + two techniques + stance, or remove Inspect/innate Spark/Kindle.
Expose a small supplemental Core/stance group with truthful source attribution for existing actions
that do not fit those strips. Do not silently reassign innate spells to an empty relic. Do not
fabricate three actions for every item. Any future definition reassignment needs a documented design
decision, preserving the existing action set in this revision.

Reuse saved arrangement commands and gear reconciliation: no duplicates, locks respected, kept
actions retain positions, new grants refill only according to the existing deterministic rule.
Expose removed/added/kept facts for highlights; a multi-paragraph summary is not the visual API.
Prepared slots expose the actual item inspection payload and finite quantity, not a generic hint.
Return both active passives and mastery facts, distinctly; mastery is not a selectable pet passive.

Pets use the existing familiar system (Bell Crow/Cinder Pup), not a separate creature framework.
Expose owned familiar choices and up to three authored passive choices; save one selected passive.
Legacy `trait_def` remains a valid one-choice default. A pet never becomes targetable or takes a turn.
Validate ownership and passive membership and snapshot the chosen trait for encounter retry/replay.

### Finite brewing, preparation and consumption

Repeatable Brew atomically spends recipe costs and increases saved stock. Keep recipe access and
stock separate; owning an old recipe does not mean infinite stock. Publish cost, yield, held count,
available/prepared quantity, per-encounter usable cap, eligibility, rejection and produced receipt.
Represent unprepared stock independently of prepared position selection. No duplicate prepared
types until a separate rule changes the current restriction; no negative/overflow quantities.

**Proposed dose model for Claude to document before integration:** one saved quantity unit is one
combat use; a batch yields authored doses, with current `PotionDefinition.charges` retained as a
carry/use cap unless separated into an explicit field. Usable charges are limited by held stock,
not magically reset above it. Brewing does not automatically equip or consume a slot. Empty stock
can retain its prepared choice at zero, disabled, so another brew repopulates it predictably.
Stock does not consume equipment bag capacity. Recipe yields/prices and starter batch quantities
must be data, not widget constants. Include the existing starter supplies in the stock/access policy
and a bounded way to brew them using existing ingredients; do not leave an undocumented infinite
starter refill exception. No new potion effects or ingredient species are requested.

Claude must publish the exact lifecycle for victory, defeat → Retry, defeat → home, Leave battle,
quit/reload and failed finalization. Preferred checkpoint behavior: Retry rewinds the same immutable
attempt allowance; an accepted concluded attempt consumes the uses it actually made exactly once.
An unfinished quit/reload follows the existing documented pending-entry recovery policy. Do not
charge a Retry twice, regenerate inventory by reload, or couple consumption to presentation timing.
Use result/snapshot facts and transactional reservation/settlement if needed; UI never decrements
inventory. Practice remains isolated from campaign stock.

Old recipe owners/prepared supplies need a **one-time bounded stock conversion**, with an explicit
migration marker so zero stock after use never triggers another grant. Do not silently drop their
access. New Journey gets a defined finite starter batch. Reset journey must not mint more stock or
repeat migration. Existing route materials are mostly one-time: finite supply introduces scarcity;
do not add repeatable farming, merchant refills or free stock as an unreviewed fix. Combat remains
possible without a potion, and the eventual resource balance stays an open human gate.

### Direct-crafted fittings

Expose socket index/lock/compatibility, compatible fitting catalog, crafted ownership, installed
choice, recipe costs and Craft/Fit/Remove eligibility. Craft acquires the selected fitting, not a
generic kit; Fit/Remove uses owned fittings and does not buy again. Use current approved fitting
effects; do not implement extra socket capacity or new modification families. Proposed initial
price: reuse the existing two-Bog-Iron price per distinct fitting as provisional data, with the
existing mastery gate; report this before integration as an economy change, not a tuned result.

For old kits, the default is to grandfather their previously available fitting choices and preserve
the installed choice. Claude must document how legacy kit refund rights/paid value remain safe,
without an automatic refund, a second refund, or clearing a working build on load. New crafted
fittings need no new dismantle/refund mechanic in this request. A legacy compatibility path may
remain internal until its removal is safe. All commands still require the exact open Forge service.

### Per-unit party Break

Extend the existing stagger/Break/event/turn systems without calling enemy-only `enemy_def()`
on party members. Publish current/max Break, Broken status and recovery for both Hollow and ally.
One unit's break does not skip the other's turn. A successful Parry retains Focus gain but pays
a configured Break cost once per defending unit per resolved reaction, not accidentally per hit.
Define baseline incoming Break damage, successful Brace mitigation and successful Evade avoidance
as authored/configured values. Failed reactions, multi-hit/AOE, Intercept, statuses, lethal hits,
simultaneous breaks and break during a reaction need deterministic ordering.

Proposed bounded policy: Broken costs the next activation, recovers at its end, and disallows that
unit's reactions while Broken. Do not copy enemy weak-point exposure, growing enemy stagger caps,
bonus Focus rewards or damage-vulnerability multipliers onto the party by accident. Existing enemy
Break remains intact. Add provisional config/definitions and report the numbers, not a balance
claim. Readouts/ledger drive the bar animation and icons; renderers never mutate battle state.

### Encounter countdown and quest journal

The host/rules own a stable threat ID and three-second remaining time. Leaving the radius cancels;
existing rearm hysteresis prevents immediate retriggers. Deterministically choose one overlapping
site. Pause/focus loss/modal ownership freezes the timer, and opening/closing a menu must not keep
resetting it. Cleared sites, portals and area transitions cancel correctly. Only expiry may call
the single encounter-entry save/launch boundary. The countdown itself writes/grants nothing.
Save failure freezes the transition with the existing Retry flow; no duplicate launch.

Quest readout supplies stable quest ID, public title, current objective, stage/completed state and
one adopted change event. Reuse current bell/return facts and the existing `quests` placeholder
where useful. Derive old-save stages without new rewards; load/open/rebuild is not a new-quest
event. Reset journey reconciles this bounded route journal with the reset world. The Director owns
brief on-screen text, journal icon attention and journal layout.

### Save origin, operation feedback and victory learnings

Keep one save owner. Add typed successful save facts distinguishing **explicit manual** Save /
Save-and-return / Save-and-quit from **automatic** arrival, loadout, craft, puzzle, reward and entry
writes. Retain `game_saved(slot, ok)` compatibility or update all backend consumers deliberately;
the Director should subscribe to one presentation path. No success on failure/rejection/no-op.
Autosave yields a quiet short icon; explicit save yields the existing compact confirmation.

Publish changed-operation facts for equip/unequip, preparation, Brew, Craft, Fit/Remove and existing
purchases, so SFX follow adopted success. Reuse `crafting_completed` where it covers the operation;
do not add a second source for the same sound. Cue names are agreed with the Director; only Claude
edits the audio manager enum/loader, only the Director edits UI sound hooks/assets. Generic select
is allowed for navigating; a success sound must not play on pressing a command that later fails.

Victory returns knowledge transitions `{enemy_id, public name, icon, previous tier, new tier}` and
the saved salvage receipts. Capture the old tier before adoption, keep it stable through failed
writes/Retry, and show only actual tier increases. The current host makes prose after the write;
replace that with structured facts. Preserve research filtering and exactly-once rewards.

### Extra mouse buttons

`InputBindings` already serializes/deserializes `mouse:N`. Settings' capture currently accepts keys
and joypad buttons only, and prompt selection skips mouse bindings. Claude supplies supported mouse
capture validation, conflict/primary-binding behavior and human labels; Director wires the capture
screen. Middle, X1 and X2 must work end to end. Handle the initiating click/release, Cancel and
held-input gates. Wheel remains owned by scrollable UI unless explicitly rebound through an
intentional policy. Do not alter action timing, reaction fresh-press logic or default bindings.

## 5. Director visual implementation plan

Build shared components first: compact slot variants (gear/action/supply/locked), horizontal
ingredient strip, bounded tooltip/detail presentation, stationary selection footer, header Help,
and pixel-safe scrollbar/checkmark theme. Suggested initial metrics at 1280×720: 48 px inventory/
gear cells, 36 px source/passive icons, 48 px combat positions and 18 px tooltip text. Verify the
real font/material minimums before freezing them. Keep body text readable and whole-canvas scaling.

Loadout composition: small portrait left; equipment with adjacent source strips; pet under relic;
four supplies beneath the character area; destination positions at right in two rows of four;
active passive icons beneath them. Source highlights and destination highlight express selection.
Small owned-choice popups perform equipment/pet/supply swaps; no separate Equip row appearing and
moving the page. Inventory gets a four-row grid and a same-height detail panel, ingredients below.

Stillroom: Prepared above Unprepared on the left; Brew catalog and selected recipe information/
costs/action on the right; ingredient strip at bottom. Crafted stock, preparation and prospective
recipe results are separate visual sections. Forge: centered sockets, compatible choices on the
right, recipe facts/costs with Craft versus Fit based on backend ownership. Neither station uses
additional explanatory paragraphs to compensate for layout. Short states (“Prepared”, “Empty”,
“Need 1 Bog Iron”, “Crafted”) get distinct hierarchy/color, not description-colored prose.

Use one tooltip policy for native text and rich item/action facts, adapted to the same font and
safe bounds. In outcome popups remove the redundant fixed inspector. Preserve detailed, knowledge-
filtered inspection, Alt/hold-details and pin behavior elsewhere; native tooltip + inspector must
not open together. Long details may scroll with clear ownership; a tooltip must never obscure its
source or Continue. Keyboard focus has an equivalent inspection path.

Dialogue scrolling needs manual-scroll/follow modes, not just a visible scrollbar: the current
`WorldModal._process` assigns scroll position every frame. Retain reveal/Confirm behavior, stop
auto-follow when the player reads back and offer a deliberate return to the latest text.

Title smoothing applies locally to logo/background, not Departure Mono/UI. Keep the particles
sparse and low contrast; disable motion/pulsing for reduced-motion/flashing settings. Do not
introduce global blur or new art generation as a prerequisite for simple shader/layout changes.

## 6. Verification and delivery

This planning task ran no game tests and claims no fixes. The preceding Director report records
315 scripts compiling and 452 tests passing in each full mode; those are **historical baseline
results**, not verification of the proposed changes. New Break/finite-supply rules intentionally
change some simulation outcomes; compare determinism/replay of the new rules and preserve unrelated
mechanics rather than demanding identical old battle totals.

Backend must add meaningful regressions for migration/round trips, stock spend/use/settlement,
duplicate/no-op/failure/Retry boundaries, fitting ownership, source action reconciliation, pets,
party Break/event order, countdown cancellation and mouse binding persistence. Retain existing
atomic-save and knowledge-filter tests. A documentation-only change needs only link/diff checks.

After integration, run all-script checks, headless full suite, Compatibility/Dummy full suite,
relevant replay/simulation checks and affected validators **sequentially** through `tools/qa_godot.py`
in distinct isolated homes. On this Windows machine the known tools are:

- Godot: `C:\Users\Adrian\Code\Games\Godot_v4.7.2-stable_win64_console.exe`
- Python: `C:\Users\Adrian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`
- QA homes: separate directories under ignored `.godot/qa-playtest-revision/`.

Director evidence must include title/tooltips at canvas edges, checkbox states and scrollbar sizes,
dialogue scrolled back during reveal, threat countdown/cancel, quest update/journal, Loadout with
source/destination/pet/supply states, 10/15-of-20 bag cells, zero-count ingredients, each station's
locked/owned/affordable/failed states, party Break/reaction layering, compact victory with two
reward rows, and manual versus automatic save indication. Capture actual rendered states at
1280×720 and 1920×1080; verify the supported display presets. Fixtures are labelled as fixtures.

Human gates remain mouse/keyboard/controller behavior, tooltip readability, selection clarity,
SFX mix/repetition, particles/reduced motion, countdown fairness, finite-supply economy and Break
balance. Do not mark the full earlier checklist passed merely because these defects are fixed.

Claude returns `docs/reports/V0_5_PLAYTEST_BACKEND_IMPLEMENTATION.md` with actual contracts,
changed files, migration/outcome policies, provisional values, tests and cross-owner integration
requests. Codex returns `docs/reports/V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md` with this matrix's
status, screenshots, tests and remaining human decisions. Keep pending work explicit and no version
bump, commit, push or “V2 complete” claim.
