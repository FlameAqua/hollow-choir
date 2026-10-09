# Director return prompt — V0.4 First Footsteps engineering complete

You are continuing Hollow Choir as Game Director / Systems Designer and owner of UI integration,
art consistency and copy. Claude (lead gameplay/backend engineer) has implemented the V0.4 First
Footsteps backend and a functional plain presentation in the working tree on `dev` after `6d8401d`.
**Nothing is committed or pushed.** Application stays 0.3.0; save version stays 1.

Repository: `C:\Users\Adrian\Code\Games\hollow-choir`. Inspect Git status first. Preserve Claude's
V0.4 work and your own earlier uncommitted display/HUD/art/design work; do not reset the checkout.

## Read first

1. `docs/reports/V0_4_ENGINEERING_REVIEW.md` — interfaces, decisions, verification, captures, open work.
2. Captures in `docs/reports/v0_4_engineering/` (town, town-restored, dialogue, bench, route, patrol,
   encounter, map, menu, latch, collision, battle) — fixed 1280×720, labelled capture fixtures.
3. `docs/DATA_CONTRACTS.md` §6 (world save section + world definitions) and `docs/TESTING.md`
   ("V0.4 world additions").

## What now exists

- Title **Continue journey** → `scenes/world/world_host.tscn`. The full loop is playable: Bellkeeper,
  bench (three owned starter weapons), reed gate, Reedway fork/outside loop, optional `fen_patrol`,
  `rot_grove` guard, ring the wayside bell, far-side return latch, home bell/lamp/acknowledgement.
- Runtime data `data/world/first_footsteps.tres`; editable area scenes
  `scenes/world/areas/{gloamstead,briarfen_reedway}.tscn` with layers Ground, GroundDetail,
  LowDecoration, DepthSorted (Y-sort), Overhead, WorldLighting, WorldEffects, Collision (painted,
  hidden at runtime; `--world-collision` shows it), Interactions, Anchors, Portals. Your pack's
  terrain atlas, Hollow/Bellkeeper/group SpriteFrames, props and facade walls/roofs are attached.
  The bootstrap `tools/build_world_areas.gd` will not overwrite these scenes without `--force` —
  edit the scenes directly from now on.
- Typed readouts for your UI: `ExplorationReadout` (existing HUD, unchanged), `WorldDialogueReadout`,
  `EncounterCardReadout`, `WorldMapReadout`. Plain placeholders: `src/ui/world/world_modal.gd`,
  `world_map_view.gd`. All rules/eligibility live in `WorldRules`; saves in `WorldSession`.
- One transactional save path (copy → write → adopt on success): entry saved before battle, victory
  applied once (duplicate token no-op), failed write publishes nothing (Retry save / Return to title),
  defeat records nothing, Retry reuses the exact entry, mid-battle quit returns to the approach.

Verification (fresh copy, isolated homes): 223 scripts / 0 failed; full suite alone 252 passed,
0 failed, 2,506 assertions; simulation smoke identical to `6d8401d`; Python 9 OK; world art
validation 204/0. Human, controller and listening acceptance remain **open**.

## Decisions requested from you

1. **Guard placement:** the `rot_grove` group sits on the junction where main path, outside loop and
   far-side path meet, so reaching the latch side always shows its Engage/Leave card once (Leave is
   free). Keep, or move `GuardGroup` + its `Interactions/bell_guard` point to ≈ tile (62,22)?
2. **Defeat stats:** defeat currently records nothing, including `battles_lost`. Confirm.
3. **Threat categories** on the card are "Patrol" and "Guard". Confirm or replace.
4. **Engineering placeholder copy** to finalize (all in `src/world/world_copy.gd` and landmark
   descriptions in `data/world/first_footsteps.tres`): prompt verbs ("Talk to the Bellkeeper",
   "Examine the gate", "Approach the patrol"…), map descriptions, `LATCH_FAR`, `LATCH_OPEN`,
   save note, save-failure, victory and defeat bodies. Town bell has no interaction (no approved copy).
5. **Menu wording:** "Save" plus "Save and return to title" (title return saves first). Confirm.
6. **Version:** recommend bumping to 0.4.0 only after your integration pass and Adrian's walkthrough.

## Integration work for you

- Replace the plain modals/map with final UI fed by the typed readouts; keep fixed 1280×720,
  22 px Departure Mono, existing `UITheme`. Note: Controls under a CanvasLayer do not inherit the
  window theme — the host assigns `get_tree().root.theme` to the HUD/modal/battle roots; keep that.
- Dress GroundDetail/banks/roof joins; tune facade footprints and sightlines; camera framing (2×,
  24 px upward offset for the HUD; no pixel snapping yet — check for shimmer).
- Art notes from integration: reed-gate source is a north–south gateway but the exit crosses the
  fence east–west; packed-path tile bands strongly at 2×; generated bell/lamp pairs differ beyond
  the changed part; willow canopy touches its cell edge.
- Field Guide empty state still says to record progress via Sandbox → Lab; now outdated.
- Optional exploration music via `AreaDefinition.music_cue` (silence remains intentional until approved).

Keep collision, save truth, IDs and trigger ownership backend-owned; if a dressing change needs
geometry changes, move WorldPoint/Marker2D/WorldPortal nodes and rerun the world tests
(`tests/world/`), which check anchors stay outside triggers/walls/engage radii and within reach.

## Please return

A Director review/acceptance note under `docs/reports/` and, if needed, a Claude brief under
`docs/briefs/`, answering decisions 1–6, listing any rule changes explicitly, and stating which
human acceptance sessions Adrian should run next. Do not mark human/controller/listening gates passed.
