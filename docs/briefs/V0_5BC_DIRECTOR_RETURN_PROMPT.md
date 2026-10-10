# V0.5B + V0.5C — Return prompt for the Frontend & Creative Lead

10 October 2026 · from Claude (Lead Architecture, Systems & Backend) · shared uncommitted `dev`
tree · application 0.5.0 / save version 1

---

You are continuing Hollow Choir as Frontend Designer & Creative Director. Claude has returned
**V0.5B (Forge/Stillroom)** and **V0.5C (exploration vocabulary)** in one session, at Adrian's
direct request. Check `git status` first and preserve all uncommitted work. Do not reset, commit,
push, change versions or regenerate authored areas.

Read these first:
- [V0.5B report](../reports/V0_5B_BACKEND_IMPLEMENTATION.md). §9 is your API and fixture guide.
- [V0.5C report](../reports/V0_5C_BACKEND_IMPLEMENTATION.md). §0 and §6 matter most.
- `docs/DATA_CONTRACTS.md`, the sections "V0.5B Forge and Stillroom" and "V0.5C exploration vocabulary".
- `docs/TESTING.md`, the V0.5B and V0.5C sections.

## What is ready

**V0.5B matches your specification exactly.**

Purchases:
- The fitting kit `forge.first_fitting` costs 2 Bog Iron. It needs 1 saved mastery point on any
  owned starter weapon.
- Clotting Salve costs 1 Bog Iron; Focus Tincture costs 1 Storm Salt. Both are permanent unlocks.

Fittings on Pilgrim's Edge:
- Choose Merciful Grip, Hollow Echo or none. Fitting, swapping and removing are free and happen at
  the bench.
- Both reuse the authored traits by reference.

Kit refund:
- The refund returns exactly 2 Bog Iron and clears the fitting in one write.
- If the refund would push a stack past 999, it is rejected whole.

Potions: Mending Draught and Fen Water Flask stay free starters. The two recipes add Clotting Salve
and Focus Tincture as choices for the two campaign potion slots. Charges are unchanged.

Battle:
- Fittings are captured with each encounter entry, so a retry never changes.
- Real battles were tested: Merciful Grip gives windows ×1.6/×1.5, Perfect ×1.07 and 8 HP per
  successful Parry. Hollow Echo exposes the parried attacker.

**V0.5C is the reusable backend.** Your bounded C brief did not exist yet. The backend provides:
- a gathering node (`GatheringDefinition`, policy `ONCE_PER_SAVE`);
- a secret (`SecretDefinition`, reveal `ALWAYS`, `PUZZLE_SOLVED` or `WORLD_FLAG`);
- the rune-sequence puzzle grammar (`RuneSequenceDefinition`);
- three new landmark kinds: GATHERING = 9, SECRET = 10, RUNE = 11;
- reward sources GATHERED, SECRET_FOUND and PUZZLE_SOLVED, on the V0.5A claim and receipt path;
- persistence and reset policy, validation and readouts;
- minimal host routing.

**Nothing is placed in `data/world` or any scene.** The concrete content is a *proposal* in
`tests/fixtures/exploration_kit.gd`, and it is tested:
- an iron seam (1 Bog Iron);
- a three-stone listening rhythm (low → high → middle);
- the drowned niche the rhythm reveals (Fenrunner Leathers);
- plus a test-only second puzzle (Gate chimes) proving the grammar is reusable.

**Verification (Claude):**
- Headless full suite: **403/0**, 6,232 assertions.
- Rendered (Compatibility, Dummy audio): 403/0 on the second full run. The first run had one
  intermittent `test_fifth_playtest` hover-card height failure, in battle UI Claude did not touch.
  That suite then passed alone twice.
- Scripts 298/0, material 264/0, Python 10 OK.
- Determinism identical to `35c8763` (120 battles); simulation identical.
- 42/42 mutations caught.
- Both demos are clean:
  - `python tools/qa_godot.py --headless --script res://tools/demo_v05b.gd`
  - `python tools/qa_godot.py --headless --script res://tools/demo_v05c.gd`

Human, controller and listening gates remain **open**.

## Your tasks

### 1. Forge/Stillroom station screens (V0.5B presentation)

The bench already opens the station context, and it now hosts both services.

**Read from** `session.crafting() -> CraftingReadout`. These are plain-data copies:
- `recipes`: `RecipeReadout`, Forge first.
- `fittings`: a `FittingReadout` for Pilgrim's Edge.
- `potion_slots`: two `PotionSlotReadout`s.
- `materials`, and action counts.

Every choice carries its eligibility as data:
- `can_purchase` / `can_refund` / `selectable`;
- a typed reason, with `*_reason_text`.

**Do not compute eligibility in widgets.** Affordability, mastery, duplicate traits and potion
locks all come from the readout.

**Commands:**
- `session.purchase(id)`
- `session.refund(id)`
- `session.fit(&"pilgrims_edge", id)`
- `session.remove_fitting(&"pilgrims_edge")`
- `session.prepare_potion(slot, id)`

Run each through the host's `_commit(write, then, rejected)`, as `_prepare` does.
- **Rejection.** Pass a `rejected` callback that re-presents the station with
  `session.last_crafting.text()`.
- **Failed write.** The existing Retry card appears, and Retry repeats the exact command.
- **Receipts.** After an OK, read `last_crafting.spent`, `.refunded` and `.cleared_fitting`, or use
  `EventBus.crafting_completed`.

**Present these facts:**
- Base / Reagent / Catalyst. Bases are reusable home supplies and never cost anything; Catalyst is
  "none".
- The mastery requirement and its current value, with the exact zero-mastery reason.
- The refund preview.
- Fitting trait facts (`option.trait`), and that the weapon keeps Pilgrim's Patience.
- That a fitting applies whenever Pilgrim's Edge is equipped.
- Potion source (Starter or Stillroom recipe). A locked choice names the recipe that unlocks it.

**Equipment preparation** now has one more typed rejection: `PreparationResult.Reason.DUPLICATE_TRAIT`.
Its text is `WorldCopy.PREP_DUPLICATE_TRAIT`. An existing rejection path already shows
`last_preparation.text()`.

**All `CRAFT_*` copy is engineering placeholder.** Restyle freely. The inventory materials note
was changed because the A line "Materials have no use in this build" became false. Please replace
the placeholder.

### 2. The bounded V0.5C specification, then placement

Decide and record the following:

1. **Content:** approve, adjust or replace the proposal: names, rewards, and whether the rhythm
   reveals the niche or the puzzle rewards directly. Fenrunner Leathers was chosen as an existing,
   unowned garb, which gives a real alternative to Pilgrim's Coat. The iron seam's +1 Bog Iron is spare.
2. **Placement:** choose the exact tiles and scene positions. A fixture tile landed in painted
   collision, so walk-test every placement.
3. **Persistence policy (confirm):**
   - Gathered nodes stay gathered through Reset journey.
   - Found secrets, solved puzzles and the current rune attempt reset.
   - Claimed rewards never repeat.

   If you confirm, consider adding this to the Reset journey card: "gathered nodes stay gathered;
   solving or finding again grants nothing".
4. **Grammar details:**
   - A wrong rune clears the attempt. If that rune is the first rune of the solution, it starts a
     fresh attempt.
   - One save per strike.
   - Runes strike on Confirm with no dialogue.
   - Nodes and secrets use a dialogue with an explicit action, as the bell does.
5. **Clue copy:** the Listening stones text could carry the rhythm. Rhythm clue copy is yours.

**To place the agreed content (data only):**
1. Add the landmarks to `data/world/first_footsteps.tres`, with `interact_radius > 0`.
2. Add a WorldPoint at `Interactions/<id>` in the area scene, plus any anchors.
3. Add the definitions to the world's `gathering`, `secrets` and `puzzles` lists.
4. Add RewardDefinitions with the new sources to `data/rewards`.

`ExplorationKit.world()` / `registry()` show the exact shapes. Validation and `test_content`
reject wrong kinds, orphans, missing reveal keys, runes spread across areas and invalid sources.

**Visible feedback is yours:**
- **Scene art.** Use `WorldStateView` sources `GATHERED`, `FOUND`, `SOLVED` and `RUNE_LIT`.
  Puzzle truth stays in `WorldState`.
- **Strike feedback.** `WorldHost.rune_struck(result)` fires after each saved strike, with result
  ADVANCED, MISTAKE or SOLVED, plus progress/length. Today, mistakes open nothing.
- **Puzzle state.** `session.puzzle(id)` returns `PuzzleReadout` (lit runes, progress, solved).
  It never carries the solution.
- **Copy.** Prompt and dialogue copy are placeholders in `WorldCopy`.

If any backend contract blocks your design, report the concrete issue back to Claude. Do not
re-implement rules in widgets.

### 3. Decisions to rule on (Decision Log is yours)

- Two of the same potion in both slots is currently **rejected** (`DUPLICATE_POTION`). The
  specification was silent.
- Duplicate-trait checks look at the **resulting active loadout**, in both directions. An inactive
  fitting on an unequipped weapon does not count.
- A legacy save with Clotting Salve or Focus Tincture already prepared gets that recipe unlocked
  for free, with no material charge.
- No-op fit and potion choices write nothing. (V0.5A's equip re-choice still writes.)
- Observation, not a balance change: Merciful Grip's wider Perfect window also feeds Pilgrim's
  Patience Focus gain. Watch it in Adrian's test.

## Then

When your station screens and the C placement are integrated, run the automated checks through
`tools/qa_godot.py` (full suite alone; Compatibility for rendered fixtures). Keep inherited evidence
separate from new runs. Then hand the integrated V0.5 build to Adrian for the full human test. Cover:
- a fresh journey and older-save reconciliation;
- salvage and slot growth;
- purchase, fit and refund, and both recipe unlocks;
- preparation into a real battle;
- gather, discover and solve;
- save, reload, reset and failed-write retries;
- mouse/keyboard, controller, readability and listening.

V0.6 (Pressure, quests, bosses, new regions) remains later work.
