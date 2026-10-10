# V0.5 playtest revision — Codex Director fresh-chat prompt

10 October 2026 · Creative & Frontend Director restart · Hollow Choir

Continue at `C:\Users\Adrian\Code\Games\hollow-choir` as Creative & Frontend Director.
Adrian gave a full human-review feedback pass and asked you and Claude (Backend, Systems and
Architecture Lead Engineer) to implement it alongside each other in separate chats.
The preceding chat prepared this plan and prompts **only**; it implemented none of these fixes.

Read first:

1. `docs/reports/V0_5_PLAYTEST_REVISION_PLAN.md` — the full feedback matrix, ownership, confirmed
   decisions, proposed policies, contracts and acceptance gates. This is the latest assignment.
2. `docs/briefs/V0_5_PLAYTEST_BACKEND_PROMPT.md` — Claude's bounded responsibilities.
3. `docs/reports/V0_5_PLAYTEST_BACKEND_IMPLEMENTATION.md` **if it exists** — actual current backend
   APIs/status. Do not assume a proposed contract has been implemented or that Claude has finished.
4. `docs/reports/V0_5_UI_PRESENTATION.md`, `docs/reports/V0_5_UI_DIRECTOR_ACCEPTANCE.md`, relevant
   `docs/DATA_CONTRACTS.md` and the current code — baseline integration, not this revision's results.
5. `docs/reports/v0_5_playtest_feedback/reward-tooltip-overlap.png` — actual supplied regression
   reference: offscreen tooltip plus a redundant inspector covering Storm Salt Charm and a bordered
   Equipment slots +5 row. Use `view_image` before comparing a new render.

Inspect current status and applicable instructions first. Preserve ALL uncommitted/untracked
work. Shared `dev`; application **0.5.0**, save version **1**. No reset/commit/push/version bump,
branch/worktree or authored-area regeneration. Do not implement wider V2/V0.6/Pressure content.
Do not spawn subagents unless Adrian or applicable repository/skill instructions explicitly ask.

## Confirmed decisions

- Six usable combat positions, two locked; eight visible. Do not unlock all eight.
- Brewing creates limited finite stock each time, paying ingredients. The backend must replace
  permanent recipe ownership as a source of unlimited encounter supplies.
- One combined Loadout page replaces separate Equipment and Combat. Inventory and Field Guide
  remain accessible. Smaller portrait/cells, gear-source action strips up to three each, destination
  positions right, passive icons beneath; pet below relic with one selected authored passive.
- Four visible supply positions and three visible fitting sockets do not authorize capacity
  increases: currently two supplies and one fitting are usable. Inventory displays 20 cells;
  actual capacity remains earned 10/15 with the others locked.
- Current backdrop is configured once, **not randomly cycled**. Answer/document this; random
  cycling was not requested. Do not mix decorative RNG into gameplay.

## Implement your independent work first

1. **Shared UI primitives.** Fix stretched scrollbars game-wide through correct shared style/
   slicing geometry. Apply the existing checkmark art to Settings with invariant row/frame sizes
   across normal/hover/checked/focus/disabled. Establish compact slot metrics shared across bag,
   gear, actions, supplies and stations; locked cells have the same bounds as occupied cells.
2. **One tooltip system.** Smaller consistent font, bounded width/wrapping, hierarchy/padding,
   viewport-edge placement, and equivalent keyboard/controller inspection. Cover native title/
   Settings tooltips and richer items/actions/rewards. Avoid native tooltip plus custom inspector
   appearing simultaneously. Remove the redundant fixed inspector **from reward/victory popups**;
   preserve knowledge-filtered detailed inspection/hold-details/pinning elsewhere.
3. **Title.** Remove “Where the old song takes root” and the surrounding frame; darken behind
   logo, gentle local smoothing, a few sparse drifting green wisps/motes. UI text stays crisp.
   Put actual version bottom right. Respect reduced motion/flashing without adding settings.
4. **Dialogue.** Allow reading back with wheel and keyboard/controller. The typewriter currently
   forces scroll every frame, so implement deliberate follow versus manual-scroll modes while
   retaining reveal/Confirm/cancel semantics and input ownership.
5. **Combat/Field Guide visual defects.** Remove residual Broken sprite tilt without breaking the
   floor anchor or status display. Layer Brace/Evade/Parry indicators above the shrinking ring
   without changing timing. Inset Field Guide research content from its scrollbar.
6. **SFX.** Reuse soft UI_MOVE/UI_CONFIRM/UI_CANCEL, add hover/focus and select routing once per
   real change, with no rebuild chatter. Design equip/unequip, smith/craft, brew and purchase cues.
   Claude owns AudioManager cue additions; you own assets, palette documentation and a presentation
   feedback adapter. Success sounds follow adopted operation facts, never speculative clicks or
   failed/no-op commands. Autosave has no sound.

## Build dependent presentation from published backend contracts

Do not calculate rules in widgets or call guessed APIs in production. While Claude works, you can
build view layout with **explicit test/capture-only fixtures**. Keep production on valid existing
consumers until actual contracts are available. Missing fields should not fabricate stock/locks/
ownership in a playable path.

- **Inventory/materials:** four rows of five cells beside a same-height higher detail panel;
  ingredients below in one non-scrolling horizontal strip, icon and quantity including zero. Reuse
  that strip in Stillroom/Forge with stable approved catalog order. Entering Inventory must not
  highlight the first ingredient automatically.
- **Loadout:** small portrait and gear cells; source action strips alongside weapon/garb/charm/
  relic; truthful supplemental Core/stance group for existing grants that cannot fit three cells.
  Preserve Inspect/stance/innate spells; never hide actions or pretend an empty relic grants them.
  Right side: eight destination cells, six usable. Choose destination then source; show active-source
  membership/highlight. Passives below, no confusing Skills placement tab. Show pet selector and
  one selected passive. Four supply cells and gear/pet selectors open compact owned-choice popups.
  Hovering a prepared supply inspects its actual effects/finite quantities. Reserve fixed regions
  so equip selection/status never shifts the page. Replace weapon-change prose with short status/
  structured highlights. Preserve Field Guide return context and focus.
- **Stillroom:** Prepared top left, Unprepared stock below; separate Brew catalog/selected recipe
  at top right; costs and availability in that detail area. Button says Brew and is gated by backend
  facts. Show produced item/quantity and refreshed stock after success, not just “Unlocked”. No
  extra instructional paragraphs to compensate for confusing layout. Status, effects and costs
  have distinct visual hierarchy. Help is centered at consistent header top right.
- **Forge:** same ingredients/help/details/compact cells; align three sockets symmetrically. A
  chosen socket shows compatible fitting choices on the right. Uncrafted choice → Craft with costs;
  crafted → Fit/Remove. No kit purchase in the new UI. Backend owns compatibility/legacy kit policy.
- **Exploration:** remove permanent floating objective and pre-encounter information box. Present
  authoritative three-second countdown unobtrusively while movement stays live. Add quest journal
  access and brief new/update text with a few gentle icon pulses (static attention under reduced
  motion/flashing); no continuous text clutter or loaded-save notice replay.
- **Party Break:** visible individual Hollow/ally bars and Broken/recovery states from backend
  readout/ledger events. No battle-state mutation in renderers. Existing enemy bars remain intact.
- **Outcome:** compact content-sized frame, “Bestiary Learnings” with enemy icon/name and previous
  → new tier, then “Salvage” with correct border padding and consistent unbordered reward rows.
  Use one bounded tooltip per reward; no fixed info panel obscuring other items. Continue stays
  visible and focusable; omit empty learning/loot sections instead of filling with prose.
- **Save:** explicit manual save gets compact confirmation; automatic writes get only a brief quiet
  icon. Use one authoritative origin event path and never show success for no-op/failure.
- **Controls:** wire Claude's published extra mouse button capture/helper into the Settings view,
  retain cancel/conflict behavior and verify actual middle/X1/X2 labels/actions/persistence.

## Ownership and working alongside Claude

You own `src/ui/**` **except**
`src/ui/battle/presentation/presentation_ledger.gd` and `unit_readout.gd`; main menu/settings
views; `src/world/world_copy.gd`; UI/art/SFX assets; presentation captures; Director UI tests;
GDD/Decision Log/testing index/return queue and your report. Exact world-test split is plan §3.

**Do not edit** `src/world/world_host.gd`, `scenes/battle/battle_scene.gd`,
`src/autoload/audio_manager.gd`, backend rules/readouts/data/save files or those two technical
presentation files while Claude owns the overlap. Record exact required wiring changes in your
report for him. If he has finished, the work may transfer explicitly to you; do not assume it.
Publish your new view constructors/signals/readout requirements early so he can wire the hosts.
Keep constructor/signals compatible until the replacement is ready where practical.

Neither prompt authorizes automatic messages to another chat/person. Use user-visible contract/
return notes for Adrian to pass across. No concurrent Godot imports/full suites/captures/timing
tests: Claude owns the engine execution window first. Independent edits and existing-image review
can continue. Run your engine checks only after that window is explicitly transferred; distinct
user-data homes alone do not isolate the shared project cache.

## Delivery and acceptance

Create `docs/reports/V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md`, initially In progress. Track each
plan matrix ID as pending/implemented/verified/deferred with honest dependencies. Use shared
components and existing art before requesting new art; new bitmap artwork, if actually needed,
must follow the imagegen skill. Do not mistake a UI fixture for a functional backend implementation.

After integration, run appropriate UI regressions and all-script/full headless/full
Compatibility-Dummy checks sequentially through `tools/qa_godot.py` in separate homes under
`.godot/qa-playtest-revision/`. Known runtimes are listed in plan §6. Preserve meaningful atomicity/
knowledge tests. Capture real 1280×720 and 1920×1080 states, inspect images, verify other supported
presets, and cover edge tooltips, checkbox states, all new loadout/station states, countdown,
quest journal, party Break, compact mixed reward popup and save origins. Log test counts freshly;
old 315-script/452-test results belong to the prior baseline only.

Update current-authority docs and Decision Log after actual integration, preserving unique existing
IDs (D-049–D-054 already exist; do not overwrite them). Clearly record the finite-supply rule
superseding permanent refill semantics. Return changed behavior, images, tests, unresolved backend
seams and the remaining human/controller/art/listening/Break-balance/economy gates. Do not call the
earlier full human checklist passed or V2 complete. Carry authorized implementation through to
reviewable completion; ask only for material decisions that cannot be inferred safely.
