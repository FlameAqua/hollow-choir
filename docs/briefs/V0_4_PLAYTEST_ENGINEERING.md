# First Footsteps — first playtest engineering continuation

9 October 2026 · `dev` after `6d8401d` · uncommitted · application 0.3.0 / save 1.

Adrian completed a first walkthrough: the loop and interactions work. His next priorities are
movement/collision consistency and much quieter presentation. Codex owns direction, art, UI, copy
and sound; Claude owns gameplay/backend work and may implement bug fixes directly. This brief
is prepared for Adrian to pass on; it has not been sent to another chat.

Read [playtest polish](../reports/V0_4_PLAYTEST_POLISH.md), the actual working diff and your
[previous integration review](../reports/V0_4_INTEGRATION_ENGINEERING_REVIEW.md). Preserve existing
uncommitted work. No commit, push or version bump is requested.

## Engineering ownership and concrete review/fix work

1. **Post-art physics pass.** Adrian could enter trees, lamps and bell frames from their sides;
   water stopped him too far from the visible bank. Candidate corrections are already applied
   to the authored native scenes: 16×9 player feet, willow 54×24, town/wayside bell 78×24,
   square lamp 26×14, preparation bench 44×18. Water collision tiles use 3 px insets only on
   sides adjacent to walkable land; interior water remains solid. Inspect these at game scale
   and revise geometry where appropriate. Test side approaches, shore corners, narrow boards,
   facade fronts, latch and all interaction radii. Keep collision backend-owned and independent
   of sprite alpha. Do not run `build_world_areas.gd --force` over the dressed scenes.
   `tools/polish_world_physics.gd` records the one-time pass; it is not a new runtime map builder.
   Area/anchor/portal/painted-tile integrity was compared against the pre-polish working copy.

2. **Return after victory.** The host now retains live feet/facing before Engage and restores them
   after a successful victory commit; it previously reloaded the named approach anchor, producing
   the reported several-tile jump. Persistent saves still store safe anchors. Review failed-write
   retry, defeat retry, leave/re-enter, duplicate completion and restored-session paths. Fix any
   stale-position edge case through the host/session boundary, without extending the save schema
   merely to retain a transient coordinate. Synthetic journey tests now expect the captured feet.

3. **Travel sound boundary.** `WorldPlayer.footstep(at)` is emitted per 34 px of actual travel,
   rather than held input. `WorldArea.surface_at()` reads the authored `surface` TileSet data,
   detail over ground. The host selects peat/stone/wood SFX only in Explore. Check wall pushing,
   short starts/stops, portals, modals, frame-rate independence and boardwalk intersections.
   The three appended cue enum values preserve all original 22 indices and original WAV bytes.

4. **Combat/pause integration.** Verify the embedded Settings screen remains a real pause,
   including controller, rebindings, focus loss and safe-point queueing during timed inputs.
   `BattleScene.apply_battle_theme()` must survive world theme updates: it deliberately suppresses
   Godot's native tooltip rendering because the shared dock owns inspection. Assigning a plain
   root theme afterward recreates Adrian's duplicate popup and literal-BBCode bug.
   Keep the action preview as hidden readout storage only; the visible inspector is docked.

5. **Regression audit.** Run the world tests and full suite alone in isolated homes, plus the
   existing simulation smoke if backend logic changes. The candidate UI/geometry pass does not
   intentionally change combat rules, encounter IDs, save transactions or research filtering.
   Existing expected invalid-save and QA-isolation diagnostics are not production failures.
   Some interrupted native captures / focused UI runs emit `4 ObjectDB instances leaked` and
   `2 resources still in use` on teardown. The SFX smoke exits cleanly after stopping voices and
   allowing the audio thread to release playback. Investigate fixture shutdown separately from
   actual play if the warning persists; do not silence genuine ownership errors.

## Preserve the presentation decisions

- World HUD: transient area name, one quiet objective, map/menu icons, nearby interaction prompt.
- Bench: fixed weapon choices, initial focus on equipped item, checkmark state, separate scrolling
  detail cards; never restore the paragraph wall or force first-item focus.
- Bellkeeper: 38 characters/sec; first Confirm reveals, next advances. No per-character bleeps.
- Combat: one inspection dock, compact supplies under turn order, small footer; no floating
  duplicate cards. Keep mouse/controller inspection, expanded analysis and scrolling accessible.
- Generated eight-facing motion resources, 5 fps walks, held breathing idles; original north/south
  retained. Art refinement belongs with Codex/artist. Reduce motion freezes breathing.
- Support/buff feedback is presentation-ledger-driven; do not show a resolved buff before its event.

## Later engineering/design work

Adrian wants terrain to understand neighbouring tiles for coherent transitions, texture variation
and blending, followed eventually by post effects. That is recorded as a later map/art pipeline
task. The current `surface` metadata and shore insets are **not** a terrain/autoconnect solution.
Propose a small explicit terrain-neighbour contract and post-art collision-validation workflow
before changing authored maps. Keep the current playable loop available during that work.

New town/exploration music is awaiting Adrian's generation and selection; requests live in
[soundtrack prompts](../audio/FIRST_FOOTSTEPS_MUSIC_REQUESTS.md). Do not substitute combat tracks
or invented assets for the missing cues. Human movement, collision feel, controller and listening
acceptance remain open for the revised build.
