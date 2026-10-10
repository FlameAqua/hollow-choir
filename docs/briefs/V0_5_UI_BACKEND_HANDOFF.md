# V0.5 UI iteration — backend handoff to Claude

10 October 2026 · from the Frontend & Creative Lead · Adrian requested this assignment.
Shared uncommitted `dev`; application 0.5.0 / save version 1. Inspect status and preserve ALL work.
Do not reset, commit, push, regenerate authored areas or change versions without a separate request.

## IMPLEMENTATION BRIEF

Adrian has reviewed the early V0.5 UI and requested the new
[journey/station/character prototype](../design/V05_UI_PROTOTYPE.md). The frontend, original icons,
generated station art, dedicated stations, chronological picker and notification queue are wired.
Complete the real functionality below, using typed readouts and atomic candidate-write-adopt
transactions. Keep combat balance and the B/C recipe/reward/puzzle rules unchanged.

1. **New Journey.** Connect `MainMenu.new_journey_requested(options)` before the setup opens.
   Validate difficulty and preset, build fresh progress from an approved starter preset, write to
   an explicitly chosen free slot, adopt only after success, then enter the world. The UI currently
   supplies `{difficulty: int, preset_id: StringName}`; values are Story=0, Adventurer=1,
   Tactician=2 and `pilgrims_edge`, `mire_maul`, `reedbow`. Weapon IDs are presentation choices,
   not permission to skip a complete validated starter loadout. Publish approved preset names,
   descriptions and icons for the inspector. Never overwrite an occupied slot automatically.
   With all three slots full, show a deliberate save-management/replace decision before writing.
   Cancel/failure preserves the current journey and every existing save. Difficulty must affect the
   selected campaign and persist consistently; do not invent new damage or timing modifiers.
2. **Continue Journey.** The current picker uses `SaveManager.slot_info`, sorts newest first and
   loads the chosen slot. Harden summaries against unreadable, corrupt, unsupported or missing
   saves. Empty/corrupt entries must not crash the title. Dates must retain explicit timezone
   meaning. Selection cannot change `active_slot` or progress before a successful load.
3. **Autosave and notification ownership.** Existing WorldSession transactions already save
   arrivals, victories, rune inputs, crafting and interactions. Preserve their atomic boundary.
   Audit entering an area, finishing combat, completing a puzzle, gathering/searching and discrete
   story interactions. Add only missing event saves; do not add a second write after transactions
   that already saved. Publish one successful save event AFTER adopted state, and no success
   event for failure/rejection/no-op. `SaveManager.write_progress` is a low-level candidate writer
   and currently emits nothing; `save_slot` emits `EventBus.game_saved(slot, ok)`. Choose one
   owner and avoid duplicate events. The UI temporarily pushes notices at known successful host
   boundaries (manual Save, crafting/equipment, rune, arrival, victory); remove redundant host
   pushes when the common event path is complete. `JourneyNotices` already consumes successful
   `game_saved` and positive `rewards_granted` receipts. It never grants or writes. Save and Quit
   must quit only after success, retry the same candidate on failure and preserve the safe anchor.
4. **Equipment without the preparation bench.** Equipment tab emits equip/unequip/potion IDs and
   already uses existing validation. Backend still requires an open preparation station, so field
   changes remain disabled honestly. Move equipment and prepared-supply selection to Character
   outside active/pending combat, preserving ownership, slot type, required weapon, duplicate
   trait/potion and action-capacity validation. Never fabricate station context to make it pass.
   Remove the old bench from the public flow; keep its stable ID or provide compatible sanitation.
5. **Distinct station services.** Forge uses stable `preparation_bench`, displayed as Forge;
   Stillroom uses new `stillroom_table` in Gloamstead. Both currently have PREPARATION kind because
   existing API accepts that kind. Add typed service availability: only the anvil authorizes Forge
   purchases/fittings/refund; only Stillroom authorizes Stillroom purchases. Reject direct or stale
   cross-service calls. Merely standing at an anchor is not an open station. Closing/walking,
   transitions and combat end station context. Preparation of owned potion choices belongs in
   Equipment; purchasing their recipes belongs at Stillroom.
6. **Saved Combat arrangement.** Replace the unsaved `_preview` in WorldCharacterView with a
   typed loadout: eight visible positions, initial active capacity six, two locked. Supply available
   Actions/Magic/Skills, icon facts, eligibility/reasons and ordered equipped choices. Add commands
   to put/replace/swap/reorder by stable ID with atomic save/adopt and retries. No duplicate active
   choices, no hidden truncation, no unlocked position usable early. Keep the existing hard
   `PartyLoadout.MAX_ACTIONS = 8` ceiling separate from progression capacity. Passives remain
   inspectable skills unless an existing rule explicitly defines a slot-consuming skill: a UI tab
   does not authorize converting traits into executable battle commands. Preserve supply and
   companion semantics. Capture the exact ordered arrangement in EncounterEntry so retry/replay
   cannot be changed through the current save. Reconcile weapon/gear changes that remove granted
   actions using an explicit valid result/readout, never an invalid persisted arrangement.
   Publish authored synergy facts from approved definitions; do not infer new bonuses in UI.

## DATA CONTRACT

- Reuse current `ProgressState`, `WorldSession`, `SaveManager`, migrator and registry patterns.
  Any new optional fields need deterministic defaults, round-trip sanitation and old-save tests.
  Report whether save version 1 can remain compatible; do not bump silently.
- Publish a journey setup/preset readout and a result with success, changed, rejection reason,
  affected slot and writer error. UI must not choose or overwrite a slot behind the player.
- Publish a Combat readout with active capacity, max positions, per-slot lock/choice, filtered
  candidates, stable IDs, structured facts, eligibility and reason text. Capacity unlock policy is
  future content: default six, keep two locked until explicitly authored progression exists.
- Three Forge sockets and four potion positions are display concepts. Current fitting capacity
  is one (Pilgrim's Edge); current supply capacity is two. Publish locks and capacity if needed,
  but do not implement new modification categories or unlock rewards in this assignment.
- Existing `InventoryReadout`, `PreparationReadout`, `CraftingReadout` and receipt icon paths
  remain the integration basis. Return public facts, not raw hidden definitions or UI prose dumps.
- Save-event metadata can include reason/slot if useful, but retain the current subscriber
  signature or update all consumers together. Reward receipts emit only after adopted state.

## STATE FLOW

Title → choose saved journey → successful validated load → world.
Title → New Journey → choose difficulty/preset → choose free slot or explicit replacement →
candidate write → adopt → world; failure stays on setup with retry and no overwritten save.
World event → validate candidate → atomic write → adopt → publish save/receipt facts → UI notices.
Character → slot/filter → candidate → explicit command → same transaction → rebuilt readout.
Combat → arrange valid active choices → save → entry snapshot → immutable retry/replay.
Forge/Stillroom → open exact service context → command → typed result → refresh → close context.

## ACCEPTANCE TESTS

- Existing saves remain untouched by opening/cancelling title/setup/picker; newest/tied summaries
  sort deterministically; empty Continue is disabled; corrupt/incompatible save is handled safely.
- Each starter/difficulty creates the intended loadout in a free slot; all-full and failed writes
  cannot overwrite by accident; restart/resume preserves choice and the correct slot.
- Arrival, victory, puzzle solve, gathering and story boundaries save exactly once where needed.
  Every success notice corresponds to adopted saved truth. No notice/event/grant for failure,
  stale command or no-op. Simultaneous receipts stack; queued notices are not lost.
- Save and Quit/return-to-title wait for success; failed write → Retry keeps exact intent.
- Gear and prepared supplies change from Character in allowed field states; pending/active
  combat rejects; unowned/wrong-slot/duplicate/over-capacity requests reject whole.
- Each station rejects the other service and every forged/stale station context.
- Six usable Combat positions initially; locked seventh/eighth cannot accept or execute anything.
  Replacement/reordering survives reload, affects actual action order, and never duplicates or
  hides actions. Old saves migrate deterministically. Gear changes reconcile validly.
- Encounter/retry/replay use captured difficulty, equipment, supplies, fittings and action order.
- Run script checks, full headless suite and full rendered Compatibility/Dummy suite alone in
  isolated QA homes. Update frontend tests that explicitly assert preview-only/NO_STATION behavior
  only once the corresponding real transaction is implemented. Retain atomicity coverage.

## KNOWN EDGE CASES

All slots occupied; tied/zero timestamps; broken summary but valid JSON; failed load; stale view
after a save appears/disappears; duplicate notifications; two separate reward sources at once;
already claimed rewards; no-op equip/prepare; changed equipment while a retry is pending; a skill
that is a passive; loss of a granted action after swapping weapon; an old arrangement larger than
six; companion actions; reduced motion; Field Guide return to a freed Character view.
Current frontend captures are fixtures, not claims of human/controller/balance acceptance.

## NON-GOALS

No new economy, trait stack, modification type, potion charge/slot unlock, recipe, quest, encounter,
region, boss, fast travel, continuous position autosave, cloud saves, audio system or combat retune.
No final environment minimap; current circular chart is the approved prototype direction.
Keep the new art/layout and iterate through typed integration seams. Return a concise implementation
report listing changed contracts, migration/defaults, tests, screenshots and remaining human gates.
