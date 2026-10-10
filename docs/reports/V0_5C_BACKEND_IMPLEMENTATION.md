# V0.5C — Exploration vocabulary backend (gathering, secret, rune puzzle)

Claude · 10 October 2026 · uncommitted `dev` after `35c8763` · application 0.5.0 / save version 1
**Not committed or pushed. No version bump, no save-version bump, no combat change, no area or
scene edits, and no production placement.** Implemented with V0.5B at Adrian's direct request ("Work
on Phase 5B and 5C now"). See the [V0.5B report](V0_5B_BACKEND_IMPLEMENTATION.md) for that stage.

## 0. Read this first: what was and was not decided here

The [continuation](../briefs/V0_5_CONTINUATION_FOR_CLAUDE.md) gives Codex the bounded C
specification: exact placement, reward budget, gathering persistence and puzzle grammar. Claude
implements against it. **That specification does not exist yet.** Rather than wait or invent
placements in Codex's scenes, this stage delivers:

1. **The reusable backend vocabulary** the roadmap names:
   - a gathering node with an explicit refresh policy;
   - a discoverable secret;
   - the first puzzle grammar (rune sequence, GDD "Pressure / Rune mechanisms").

   It includes typed definitions, deterministic state, validation, persistence and reset policy,
   reward hooks, readouts and minimal host routing.
2. **A concrete, tested content proposal** for the Codex brief:
   - an iron seam, a three-stone rhythm and the niche the rhythm reveals;
   - a second fixture puzzle that proves reuse.

   These live in `tests/fixtures/exploration_kit.gd`, not in `data/world` or any scene.
3. **No production placement.** Every authored landmark must have a scene marker (enforced by
   `test_world_rules`). Placement is Codex's, so `first_footsteps.tres`, the area scenes and
   `data/rewards` are unchanged. A player sees nothing new until Codex places the agreed content.
   That is data-only once the placements are agreed (§7).

Treat every content value below (names, tiles, rewards, copy) as a proposal. The engineering
policies (§3) are the part that needs explicit Director confirmation or correction.

## 1. Proposed First Footsteps content (fixture data)

| Feature | Landmark(s) (kind) | Rule | Reward (claim id) |
|---|---|---|---|
| Iron seam | `iron_seam` (GATHERING), outer loop, planning tile (11, 38) | Gathered once per save | 1 Bog Iron (`first_footsteps.iron_seam`) |
| Listening rhythm | `rhythm_stone_low/mid/high` (RUNE), around the Listening stones overlook | Strike low → high → middle | None itself: it reveals the niche |
| Drowned niche | `drowned_niche` (SECRET), below the overlook | Imperceptible until the rhythm is solved, then searchable | Fenrunner Leathers (`first_footsteps.drowned_niche`) |
| Gate chimes (reuse fixture only) | `gate_chime_a/b/c` (RUNE), Gloamstead | A → B → A → C (a repeated rune) | 1 Storm Salt (`fixture.gate_chimes`) |

- **Planning tiles.** The tiles are suggestions; one fixture tile lies in painted collision, which
  shows why placement belongs with Codex.
- **Reward choice.** Fenrunner Leathers is an existing, unowned garb. Its trait reads "Successful
  Evades grant 1 Focus; Evading in Flooded Ground no longer soaks you." It would be a real
  alternative to Pilgrim's Coat for a fen route.
- **Budget effect.** The iron seam raises the route's Bog Iron from 4 to 5 against V0.5B's 3. That
  is spare, harmless iron, which the B catalog invariant allows.
- **Open choices (§8):** the puzzle's own reward, the secret's reward and whether the rhythm should
  reveal the niche at all.

## 2. Architecture

```
WorldDefinition.gathering / .secrets / .puzzles  (GatheringDefinition, SecretDefinition,
  RuneSequenceDefinition; LandmarkDefinition.Kind + GATHERING, SECRET, RUNE)
ExplorationRules (pure): lookups · revealed / perceivable · strike (the grammar) · readout ·
  secrets_revealed_by · validate (run by WorldDefinition.validate)
WorldState (world section): gathered · found · solved · rune_input  (+ sanitize, helpers)
RewardDefinition.Source + GATHERED, SECRET_FOUND, PUZZLE_SOLVED  → RewardRules (accomplished,
  catch-up, catalog sources): the V0.5A claim/receipt path, unchanged
WorldSession: gather · find_secret · strike_rune · puzzle() · last_exploration
  └─ _field_write: pending check → typed reason → commit (change + chart + anchor + grant) → publish
WorldRules: prompts, dialogue, map (optional WorldDefinition; hidden secrets imperceptible)
WorldStateView.Source + GATHERED, FOUND, SOLVED, RUNE_LIT   (scene visibility only)
WorldHost: routing (GATHERING/SECRET → dialogue → command → reward card; RUNE → strike; signal
  rune_struck), discovery skips imperceptible landmarks
```

- **Truth and visibility.** Puzzle truth is `WorldState` plus the pure grammar. Scenes only follow
  it through `WorldStateView`; art never writes state.
- **Rewards.** Rewards are ordinary `RewardDefinition` claims, so receipts, catalog checks,
  previews and old-save catch-up behave exactly as for salvage.
- **No quest framework.** No generic quest or objective framework was added. The main objective is
  untouched.

## 3. Rules and persistence policy (for confirmation)

| State | Saved where | Reset journey | Why |
|---|---|---|---|
| Gathered node (`world.gathered`) | `world` section, carried over by `reset_journey` | **Kept** | A node yields once per save (`Refresh.ONCE_PER_SAVE`, the only policy). No clock, timer, visit count or regrowth. The scene must not show a full node that yields nothing. |
| Found secret (`world.found`) | `world` | Reset | Finding a place is route knowledge, like the bell. Its reward claim is kept, so searching again after a reset grants nothing ("Whatever was hidden here has already been taken."). |
| Solved puzzle (`world.solved`) and current attempt (`world.rune_input`) | `world` | Reset | Like the bell and latch. Re-solving grants nothing again. |
| Reward claims | `rewards` (V0.5A) | Kept | Exactly once per save. |

**Puzzle grammar.**
- **Strikes.** The expected rune advances the attempt; the final expected rune solves the puzzle.
- **Mistakes.** A wrong rune clears the attempt with no other penalty. When the wrong rune is the
  solution's first rune, it starts a fresh attempt instead.
- **Saving.** Every strike is one saved write, so an attempt survives reload and area changes.
  Strikes on a solved puzzle are ignored (`ALREADY_DONE`, no write).
- **Readouts.** `PuzzleReadout` exposes lit runes and progress, never the order.

**Secrets.**
- **Imperceptible while hidden.** A SECRET landmark whose reveal condition does not hold has no
  prompt. It is never discovered by proximity and never charted, even if an earlier journey
  discovered it.
- **Reveal kinds:**
  - `ALWAYS`: hidden only by placement;
  - `PUZZLE_SOLVED`: a puzzle id;
  - `WORLD_FLAG`: a world flag.

**Interactions.**
- **Typed results.** Gather, search and strike each return a typed `ExplorationResult`.
- **Pending encounters.** They are refused while an encounter is pending.
- **Charting.** Each charts its landmark, and makes it the resume point when it is a safe anchor.
- **Optional content.** It never gates the route: the main objective, bell and latch complete
  without it (tested).

## 4. Files

**Created:**
- `src/world/exploration/`: `gathering_definition.gd`, `secret_definition.gd`,
  `rune_sequence_definition.gd`, `exploration_rules.gd`
- `src/world/readouts/`: `exploration_result.gd`, `puzzle_readout.gd`
- `tests/fixtures/exploration_kit.gd`, `tests/unit/test_exploration_rules.gd`,
  `tests/world/test_world_exploration.gd`
- `tools/demo_v05c.gd`, `demo_v05c_runner.gd`
- Godot `.uid` files for each new script

**Modified:**
- `src/world/landmark_definition.gd`: kinds and their validation
- `src/world/world_definition.gd`: the three lists and validation
- `src/world/world_state.gd`: fields, save keys, parsing, sanitize, helpers
- `src/world/world_session.gd`: commands, `puzzle()`, `last_exploration`, reset carry-over
- `src/world/world_rules.gd`: prompts, `perceivable`, dialogue, map
- `src/world/world_state_view.gd`: four sources
- `src/world/world_copy.gd`: placeholder copy
- `src/world/world_host.gd`: surgical routing in Codex's shared file:
  - the `rune_struck` signal;
  - the RUNE branch in `interact()`;
  - `gather`/`search` dialogue actions;
  - `strike()`;
  - the discovery and prompt calls pass the world definition.
- `src/data/progression/reward_definition.gd`: three sources
- `src/progression/reward_rules.gd`: `accomplished` and catalog sources
- Docs: `DATA_CONTRACTS.md`, `TESTING.md`, `briefs/CLAUDE_RETURN_QUEUE.md`

**Save format:** additive `world.gathered`, `world.found`, `world.solved`, `world.rune_input`.
Older saves have none; save version stays 1.

## 5. Verification

The shared numbers for the whole session (both stages) are in the
[V0.5B report §8](V0_5B_BACKEND_IMPLEMENTATION.md#8-verification-exact-runs-isolated-godotqa-homes-godot-472).

**V0.5C-specific:**
- `test_exploration_rules` 6/0 and `test_world_exploration` 5/0 (run alone).
- The authored world still validates and keeps a marker for every landmark (`test_world_rules`
  unchanged and passing).
- Battles and the simulation smoke are identical to `35c8763`.
- **All 16 V0.5C mutations were caught:**
  1. Mistakes keep the attempt.
  2. No restart on the first rune.
  3. Reset regrows gathered nodes.
  4. Reset keeps puzzles solved.
  5. Gathering repeats.
  6. Secrets ignore their reveal.
  7. Field rewards are granted outside the write.
  8. Hidden secrets are discovered.
  9. Hidden secrets prompt.
  10. Invalid rune input is kept.
  11. Gathering proves no catch-up.
  12. The readout ignores the attempt.
  13. The scene view lights solved runes only.
  14. Puzzles may span areas.
  15. A strike saves nothing.
  16. Exploration state is not saved.

Demo output, verbatim (fixture world, public results only):

```
1. New game in throwaway slot 7 on the V0.5C fixture world.
2. Gather the iron seam → OK, received Iron seam → 1 Bog Iron
   Gather it again → Already exists, Already Done
3. Search the drowned niche before the puzzle → Unavailable, Hidden
   Strike rhythm_stone_low → OK, Advanced 1/3
   Strike rhythm_stone_mid → OK, Mistake 0/3
   Strike rhythm_stone_low → OK, Advanced 1/3
   Strike rhythm_stone_high → OK, Advanced 2/3
   Strike rhythm_stone_mid → OK, Solved 0/3, revealed drowned_niche
4. Search the drowned niche → OK, received Drowned niche → Fenrunner Leathers
5. Reloaded from disk. Gathered [&"iron_seam"], solved [&"listening_rhythm"], found [&"drowned_niche"]. Claims: [&"first_footsteps.drowned_niche", &"first_footsteps.iron_seam"]. Bog Iron 1. Owns Fenrunner Leathers: true.
6. Reset journey. Gathered [&"iron_seam"], solved [], found []; claims kept: 2.
   Gather again → Already exists, Already Done
   Strike rhythm_stone_low → OK, Advanced 1/3
   Strike rhythm_stone_high → OK, Advanced 2/3
   Strike rhythm_stone_mid → OK, Solved 0/3, revealed drowned_niche
   Search the niche again → OK, no reward (already claimed)
7. After the repeat: Bog Iron 1, Fenrunner Leathers owned once: true.
Demo finished.
```

## 6. API and fixture guide for Codex

**Placing content (data only, after agreement):**
1. Add LandmarkDefinitions to `data/world/first_footsteps.tres`:
   - kinds `GATHERING = 9`, `SECRET = 10`, `RUNE = 11`;
   - `interact_radius > 0`;
   - `safe_anchor` if wanted.
2. Add `Interactions/<id>` WorldPoints (and anchors if needed) to the area scene.
3. Add `GatheringDefinition` / `SecretDefinition` / `RuneSequenceDefinition` entries to the
   world's `gathering`, `secrets` and `puzzles`.
4. Add `RewardDefinition`s with sources `GATHERED` / `SECRET_FOUND` / `PUZZLE_SOLVED` to
   `data/rewards`.

`ExplorationKit.world()` / `registry()` show the exact shapes. `DefinitionRegistry.validate()` and
`test_content` reject wrong kinds, orphans, missing reveal keys, cross-area runes, foreign solution
runes, lengths outside 2–8 and rewards naming non-features.

**Presentation hooks:**
- **Scene art.** Use `WorldStateView` with source `GATHERED` (node id), `FOUND` (secret id),
  `SOLVED` (puzzle id) or `RUNE_LIT` (rune id, lit while in the current attempt). Pair `SOLVED`
  with `show_when` to show all runes lit or the revealed niche.
- **Strike feedback.** `WorldHost.rune_struck(result: ExplorationResult)` fires after each saved
  strike, with `strike` = `ADVANCED` / `MISTAKE` / `SOLVED` and `progress` / `length` (plus
  `revealed` on a solve). Hook sounds and VFX here. A solve shows a short card (with receipts if
  any). Mistakes open nothing today.
- **Puzzle state.** `session.puzzle(id) -> PuzzleReadout` gives `{solved, entered, length,
  runes[{id, label, lit}]}`.
- **Copy.** Prompts and dialogue come from `WorldRules` and `WorldCopy` (`PROMPT_GATHER`,
  `PROMPT_SEARCH`, `PROMPT_STRIKE`, `GATHERED_TEXT`, `GATHER_DONE`, `SECRET_FOUND_TEXT`,
  `SECRET_FOUND_BODY`, `SECRET_EMPTY`, `PUZZLE_SOLVED_TEXT`). All are engineering placeholders.

**Commands and receipts.**
- **Commands.** `session.gather(area, id)`, `find_secret(area, id)` and `strike_rune(area, id)` go
  through `_commit`. Failed writes show the existing Retry card; Retry applies once.
- **Rewards.** Use the V0.5A receipt path (`last_receipts`, `EventBus.rewards_granted`, `_show_rewards`).
- **Testing.** `test_world_exploration.gd` places runtime WorldPoints at the planning tiles and
  disables the player's collision mask for teleports. Real placement should be walked, not
  teleported.

## 7. Known limitations

- **Nothing placed.** No production content exists; the full V0.5 human test needs Codex's
  placement first.
- **Placeholder host presentation.** Plain dialogue cards, no mistake feedback, no puzzle clue text.
- **Map.** The map does not mark runes specially. Lit-state art depends on scene views Codex adds.
- **One refresh policy.** "Per expedition" waits for V0.6's expedition definition (Pressure); no
  timer-based refresh exists by design.
- **Second grammar.** Only one grammar (rune sequence). Bloom Routing / Resonance Mirrors remain later work.

## 8. For the Director (decisions and questions)

1. **Content.** Approve, adjust or replace the proposal: iron seam (1 Bog Iron), the listening
   rhythm, and the drowned niche (Fenrunner Leathers), plus placements. Should the puzzle reward
   something itself, or should the secret be `ALWAYS` (hidden by placement only)?
2. **Persistence.** Confirm the policy above: gathered nodes survive Reset journey; puzzles and
   secrets reset; claims never repeat. If confirmed, the Reset journey card could add "Gathered
   nodes stay gathered; solving a puzzle or finding a secret again grants nothing."
3. **Grammar details.** Confirm the mistake rule (a wrong rune clears the attempt, or restarts it
   when it is the first rune) and the per-strike saves (one write per strike).
4. **Interaction.** Runes strike immediately on Confirm (no dialogue), and secrets and nodes use a
   dialogue with an explicit action, like the bell. Codex may restyle either.
5. **Clue.** The rhythm currently has no in-world clue. The Listening stones text ("water keeps its
   own slow rhythm") could carry one. Clue copy is yours.
