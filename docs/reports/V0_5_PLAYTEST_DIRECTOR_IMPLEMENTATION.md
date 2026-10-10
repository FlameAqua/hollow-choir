# V0.5 playtest revision — Director implementation

10 October 2026 · Codex, Creative & Frontend Director · **Presentation implemented and rendered;
backend regression closure and human acceptance remain open**

Application **0.5.0**, save version **1**, shared uncommitted `dev`. Existing modified and untracked
work is preserved. No reset, commit, push, branch, worktree, version bump or area regeneration.
Authority: [revision plan](V0_5_PLAYTEST_REVISION_PLAN.md),
[restart brief](../briefs/V0_5_PLAYTEST_DIRECTOR_RESTART_PROMPT.md).

## Integration status and ownership

Claude's [backend report](V0_5_PLAYTEST_BACKEND_IMPLEMENTATION.md) §2 supplies the consumed contracts.
Its §6/§7 status describes the mid-implementation transfer, not the latest file state. Subsequent
code inspection and execution confirm host countdown/Journal/Loadout/station/learnings routes,
familiar trait forwarding, party Break ledger fields and the wall-movement correction have landed.
Protected test migration is still underway. Published APIs and release acceptance remain distinct.

Claude retains exclusive ownership of world_host.gd, battle_scene.gd, audio_manager.gd,
presentation_ledger.gd, unit_readout.gd, backend/data/save files and protected tests. No edits to
those files were made here. Claude explicitly transferred the **Godot execution window to Codex**
in §6 on 10 October; Adrian confirmed that handoff here. Claude continues independent file edits.
Fresh import passed; the latest all-script check passed **350 scripts, 0 failed**. The tooltip local
type and published static mouse-binding calls are corrected. The focused presentation suite passes
**11 tests, 187 assertions, 0 failed** in headless and Compatibility/Dummy. The four Director-owned
world suites pass **28 tests, 450 assertions, 0 failed** headless. Combined focused coverage is
**39 tests / 637 assertions**. Broad runs, captures and limitations are recorded below; historical
315-script/452-test counts are not evidence for this revision.

## Presentation implementation

- Shared 48×48 cells and 36×36 source/passive icons; identical occupied/locked geometry. Scrollbar
  native 16 px continuous strips use stretched centers and preserved 8 px end caps. Settings uses the existing
  checkmark with invariant state frames, icon reservation and padding.
- One contextual inspection policy for title, Settings, world menus and outcomes. Native tooltip
  paint is suppressed; source text remains available to the shared pointer/focus inspector.
  Floating cards wrap to 380 px, clamp to safe bounds and choose an adjacent side. Existing detailed
  inspection, hold-details, pinning, filtered knowledge and wheel ownership remain. Reward/victory
  popups have one ContextTooltip and no fixed LootInspector; Continue is outside tooltip bounds.
- Title tagline/frame removed, darker left shade, local five-tap scenic/logo smoothing only,
  six sparse green motes and actual project version bottom right. Motion is static under reduced
  motion or flashing. No gameplay random stream is consumed.
- Dialogue separates typewriter follow from manual reading. Wheel/arrows/Page Up/Down pause follow;
  Latest resumes it. Reveal and Confirm semantics remain. Manual reading does not pause reveal.
- Broken sprites remain upright. Reaction indicators draw after the shrinking ring. Field Guide
  research/details panes reserve a 16 px right gutter. Party Break draws supplied ledger facts.
- Inventory has four rows of five cells, actual 10/15 capacity with locks, aligned higher details
  and a shared horizontal ingredient strip. Catalog order and zero quantities come only from the
  readout. Entering Inventory focuses equipment, never an ingredient.
- Unified Loadout accepts actual LoadoutReadout: small portrait, gear and three source cells per
  gear row, truthful supplemental Core/stance actions, eight destination positions (six usable),
  active passives, pet and authored passive choices, four supply cells. Owned-choice popups emit
  existing commands; no widget determines stock, ownership, grants or capacity. Arranged sources
  highlight; unplaced actions remain named. The legacy constructor remains compatible until the
  host supplies the new readout. Inventory and Field Guide stay available; Journal signal added.
- Stillroom accepts stock/recipe facts: Prepared, Unprepared stock, separate Brew catalog,
  effects/cost icons/required and held counts, short state and fixed action space. Forge consumes
  symmetric three-socket facts and direct Craft/Fit/Remove eligibility. Both share ingredients and
  header Help. Commands emit brew/craft/fit/remove/potion; rules stay in WorldSession.
- Journal renders supplied active/completed route steps. Countdown renders supplied remaining time,
  fraction and frozen state; it owns no clock. HUD quest notices are brief, with bounded gentle
  attention and reduced-motion/flashing fallback. Persistent objective hides only when Journal is
  actually connected, avoiding an inaccessible objective during the overlap.
- Victory renders supplied changed Bestiary Learnings and actual Salvage receipts, removes the
  explanatory victory paragraph, sizes the frame to content and treats capacity rewards like items.
- JourneyNotices prefers save_completed exclusively when available: automatic saves show a quiet
  brief icon; manual saves use the reserved confirmation card. No autosave sound.
- UIFeedback coalesces real hover/focus navigation and avoids initial-focus/rebuild chatter.
  OperationFeedback is installed once by JourneyNotices and consumes adopted crafting_completed,
  preparation_completed and familiar_changed through AudioManager.operation_cue(result).

## Integration seams and remaining Claude work

**Integrated in actual code:** OperationFeedback is installed once; host generic-confirm success
calls are removed. HUD and Character Journal signals route to open_journal. BattleScene forwards
the selected TraitDefinition as FamiliarCard.setup's fourth argument. The host calls
WorldCharacterView.present_loadout, present_preparation and present_combat, station
WorldCraftingView.present_operation, HUD present_countdown and victory present_learnings. Concise
success states replace the old long outer-modal summaries. Existing constructors remain compatible.
WorldCopy supplies QUEST_BELL_TITLE/COMPLETE and the exact CRAFT_/FAMILIAR_ reasons; stock overflow
retains its %d substitution. New reason names/format arguments still require publication before use.

**Open, Claude-owned:** close the broad-suite failures in the
[failure inventory](v0_5_playtest_revision/FAILURE_INVENTORY.md), preserving atomic write/failure/
Retry/replay/knowledge assertions. The observed failures include superseded encounter-card,
permanent-kit, infinite-supply and automatic-save-card expectations, old UI paths, one-time
migration write counts, quest reset stages and pending-entry numeric round-trip equality. The
latter requires investigation, not an assumption that the test is obsolete. New host regressions
also report countdown cancellation and wall-animation failures; these remain functional gates.
Update the backend
report's progress/verification sections after the landed host changes and run stable integrated QA.
No ownership of protected files/tests has transferred to the Director.

## Feedback coverage

“Verified” names automated or rendered evidence only. It does not close Adrian's human acceptance
gates. Image names below resolve through the [capture index](v0_5_playtest_revision/README.md).

| IDs | Status | Evidence / remaining dependency |
|---|---|---|
| S01 | Implemented; input/listening gate | UIFeedback coalesces hover/focus and stays silent on initial/rebuilt focus; deliberate selection uses the existing palette. Real mouse/controller audition remains open |
| S02, S03 | Integrated; automated adoption checks pass | 8-test presentation suite checks one equip/retry/smith/fit/remove/brew cue, failed write/re-choice silence and silent saves; mix/listening remains open |
| T01–T04 | Implemented; rendered | title at 720p/1080p, reduced-motion fixture and four tooltip corners at all five presets; actual project version; title motion remains a human gate |
| U01–U03 | Implemented; automated/rendered | Tooltip safe bounds/source/Continue tests, shared styles, checkbox state geometry and state renders, native-size tiled scrollbar caps; detailed/pinned inspection retained |
| I01 | Integrated; backend tests available | Settings calls the actual capture/cancel/rebound/conflicts helpers; new backend mouse suite covers labels/save/reload/actions. Real middle/X1/X2 hardware and opening-click feel remain open |
| D01 | Implemented; automated/rendered | Manual scroll survives continuing reveal; Latest resumes follow; Confirm reveals first. Long dialogue render reviewed; controller reading feel remains open |
| E01 | Backend correction landed; owner/human gate | WorldPlayer collision correction inspected; no Director rule edits. Repeated wall/corner taps, sliding and footsteps require final owner evidence and human playtest |
| E02 | Integrated; host rendered | Real host countdown 1.80 s and cancellation/0 writes, held-clock placement fixtures; countdown unit suite present. Expiry/focus/failure/rearm owner regressions and fairness gate remain explicit |
| E03 | Integrated; host rendered | Actual restore_bell command drives brief quest update; Journal opens from real host. No-load-replay coverage is in backend revision session suite; human notice/readability gate remains |
| C01, C02 | Implemented; rendered | battle_broken and reaction captures at impact; upright floor anchor and three front indicators. Timing specifications untouched |
| C03 | Inspected/documented | defaults.tres supplies one battle_backdrop; BattleScene.start assigns it once; no random cycle |
| C04 | Integrated; rendered; balance gate | Individual actual has_break/stagger/max_stagger bars; one-Broken-party display fixture; backend party Break tests cover rules/replay. Final integrated regression closure and human balance remain open |
| C05–C08 | Integrated; automated/rendered | Real host saved victory learning + salvage, mixed capacity/item fixture and focused reward inspection; one ContextTooltip, no fixed LootInspector, visible rows/Continue |
| L01, L03, L05 | Implemented; automated/rendered | 20 equal bag cells with earned 10/15 capacity, aligned details, fixed slots/footer, distinct passive/source strips; five Loadout presets reviewed |
| L02, L04, L07–L09 | Integrated; automated/rendered | Actual LoadoutReadout/stock/catalog/source/pet facts; eight destinations/six usable, four supplies/two usable, owned popup and lock states. Real battle/reload pathways covered in world tests; controller feel open |
| L06 | Integrated; automated/rendered | Source membership and short saved/positions-kept status, adopted present_preparation/present_combat hooks; old summary suppressed |
| F01 | Implemented; rendered | field-guide 720p/1080p shows full research bar with reserved right gutter beside scrollbar |
| A01–A04, A06, A08, A09 | Integrated; automated/rendered | Shared catalog/help/cells, separate stock and Brew, costs/held counts/effects, symmetric three sockets/one usable. Poor/rich station bounds and Close safety asserted |
| A05 | Integrated; host/transaction tested | present_operation shows produced item ×count; stock/yield/after-Brew readouts refresh; failure/Retry keeps selection and emits only after adoption |
| A07, A10 | Backend implemented; owner regression closure open | Finite paid Brew and direct Craft/Fit/Remove tested through real Director world integration; legacy refund deliberately reachable. Protected crafting/supply/reward suite closure remains Claude's work |
| N01 | Integrated; automated/host rendered | One save_completed path, quiet automatic icon/manual card. Actual host equip vs Save captures, manual footer dock and no cue/duplicate-card assertions pass |

## Fresh validation and rendered repairs

- Supplied reward-tooltip-overlap.png inspected as the regression reference.
- Fresh all-script check: **350 checked / 0 failed** (`director-script-final-ui`). New backend test
  files arrived during the pass; counts grew from 344 to 347 to 350, not a change in test policy.
- Five original material operation cues generated using the existing standard-library synthesizer
  with private seeds. 44.1 kHz, mono PCM16; peaks -17.08 dBFS. playtest_operations_manifest.json
  records hashes/duration/peak/RMS. Measurements are not listening acceptance.
- Static Python validation: all five WAV hashes/formats and available import settings match the
  manifest; the generator parses, and no duplicate UI/capture method definitions were found.
  Python lexical checks found balanced delimiters/indentation in 92 UI/main/test/capture sources.
  This is source/asset hygiene, not GDScript compilation or game execution.
- `test_playtest_revision`: **8/0, 158 assertions**, headless and Compatibility/Dummy, including
  tooltip corners/source/Continue, native suppression, manual dialogue reveal, read-only bag/catalog,
  checkbox/scroll caps, Journal width, poor/rich station bounds and adopted audio/save feedback.
- Director world suites, headless: character_menu **5/0, 77**; ui_prototype **9/0, 122**;
  journey_setup **6/0, 129**; v05_integration **8/0, 122**. These cover actual host Craft failure/Retry,
  finite Brew/preparation/entry allowance, Fit no-op, stale/rejected commands, deliberate legacy
  refund, quiet automatic save/manual footer and exploration walking. Combined with presentation:
  **36 tests, 608 assertions, 0 failed**; this is focused coverage, not a green full suite.
- First broad headless snapshot: **449 passed / 27 failed, 7,724 assertions, 126.17 s**.
  Subsequent Compatibility/Dummy snapshot: **476 passed / 26 failed, 9,592 assertions, 126.94 s**.
  Both ran sequentially during Claude's independent edits; added backend tests explain the growing
  totals. They are not a release pass. [Exact failures and logs](v0_5_playtest_revision/FAILURE_INVENTORY.md).
- Later sequential broad snapshots, after new backend suites landed: headless **497 passed /
  26 failed, 10,143 assertions, 141.52 s**; Compatibility/Dummy **511 passed / 8 failed,
  10,129 assertions, 139.99 s**. The second snapshot includes one suite load failure in a file
  being edited; the later 350-script check passes. Source hashes before/between/after record the
  changes, including Director tooltip sizing and its regression. Neither count is a stable green
  acceptance run. Full owner verification must be repeated after protected tests and shared files
  stop changing; remaining host/persistence failures are explicitly retained.
- Captures use production controls with isolated in-memory readouts, or actual WorldHost/Session
  routes as labelled in the [capture index](v0_5_playtest_revision/README.md). Main screens are
  rendered at 1280×720 and 1920×1080; Loadout also at 1366×768, 1600×900 and 2560×1440. Four tooltip
  corners cover all five presets. Variants cover owned/locked/fitted, poor/depleted/unprepared stock,
  owned choice popup, checkbox states, reduced title, countdown/frozen, Journal/quest, save origins,
  compact mixed rewards, Broken sprites, party bars and reaction layering.
- Rendered review found and fixed: clipped second salvage row (content sizing), Journal/learning
  HBox text wrapping into vertical columns, hidden station costs, long mastery reason pushing Close
  off-canvas, missing potion icon fallback, depleted slot treatment, tooltip footer truncation and
  busy-parent feedback installation. Capture fixtures now select the fitting they name and fail a
  missing requested inspection source; host notices are captured after their entrance slide settles.
- All runs use qa_godot.py, the Godot 4.7.2 console executable and separate
  `.godot/qa-playtest-revision/` homes. Engine runs are sequential. Title capture teardown now lets
  stopped audio release; earlier transient cleanup warnings are not counted as final accepted
  captures. Wrapper tools defer runtime consumers until autoloads exist; loading a runner directly
  as the main-loop script is not their supported entry point. See the [testing index](../TESTING.md).

## Human gates and provisional decisions

Open: mouse/keyboard/controller feel, tooltip readability, selection clarity, SFX mix/repetition,
title motion/reduced motion, countdown fairness, finite-supply economy, party Break balance and the
full earlier playtest checklist. Claude's proposed defaults (starter 4+4, 1 ingredient → 2 doses,
2 Bog Iron per fitting, saved-victory-only consumption, 40 party Break/hit 8/Brace 4/Evade 0/Parry 6)
are provisional integration policies, not balance acceptance. Old paid kits must stay non-lossy;
legacy refund must remain deliberately reachable. No broad V2/V0.6 acceptance is implied.

## Additional feedback — 10 October, final checkpoint

Adrian requested stopping repetitive title captures. No title Help feature was added: the question-mark button in corner captures was a test fixture. No further title captures were taken in this follow-up.

| Feedback | Implementation and evidence |
|---|---|
| Continuous slider/scrollbar textures | Six new continuous SVG strips in material_v04, generated by tools/make_continuous_controls.py. Native end caps with stretched centers; existing art versions preserved. Settings rendered and reviewed. |
| Restore circular Anvil | Sword centered in the original ring, three fitting cells arranged in a triangle. One usable/two locked still follows the backend readout. Rendered and reviewed. |
| Empty station sections retain slots | Empty Unprepared Stock and empty fitting/catalog sections show a truthful empty cell. No stock or eligibility invented. Stillroom rendered and reviewed. |
| Help to the right of the title | WorldModal moves the existing view-owned Help button into TitleRow. Character, Anvil and Stillroom rendered and reviewed. |
| Text contrast | Label and RichTextLabel receive a dark two-pixel shadow, including titles. |
| Initial reaction circle centering | ReactionWidget resolves actual target positions at paint time, after stage layout changes. Preparing-state capture at elapsed 0 ms rendered and reviewed; regression covers initial geometry and stage resize. Shared battle_scene.gd untouched. |
| Tooltip source exit | Unpinned cards dismiss on source exit, including when hovering the card or holding expanded details. Explicit pins remain available for rich inspections. Regression covers dismissal and deliberate pin retention. |
| Tiny simple hints | Exploration toolbelt uses small plain-label hints with no pin footer, rich card or scrollbar. Final Menu hint rendered and reviewed. |
| Exploration ordering | Character, Map, Journal, Menu; Menu remains rightmost. Regression checks order. |

Latest focused verification: **11 tests / 187 assertions / 0 failures** in Compatibility/Dummy; headless passed the same counts before the final compact-label refinement. The earlier four Director world suites remain 28 tests / 450 assertions; they were not repeated for this follow-up. Combined coverage is 39 tests / 637 assertions across those runs, not a single full-suite green run. git diff --check found no whitespace errors (line-ending warnings only).

Six targeted final captures: followup_forge.png, followup_stillroom.png, followup_loadout.png, followup_settings.png, followup_menu-hint.png, followup_reaction_initial.png in v0_5_playtest_revision. The Menu capture was corrected once after visual review exposed clipping in the initial small-card implementation. Final simple hints use a plain Label.

**Stopping checkpoint at Adrian's usage-limit request.** All current changes remain uncommitted. Broad-suite regression closure remains open; see FAILURE_INVENTORY.md (latest recorded full run: 511 passed / 8 failed, during concurrent backend edits). Human playthrough, input feel, audio listening and visual acceptance remain explicit gates. No additional broad runs or title sweeps were made during this follow-up.

**Godot execution window returned to Claude at this checkpoint.** No Godot process was active when checked. Codex will not run the engine again without a new transfer.