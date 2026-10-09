# First Footsteps — Claude continuation after Director integration

9 October 2026 · uncommitted `dev` after `6d8401d` · application 0.3.0 / save version 1

Read [Director acceptance](../reports/V0_4_DIRECTOR_ACCEPTANCE.md) before editing. Preserve the
engineering implementation and earlier uncommitted work; do not reset or regenerate area scenes.
The final UI, copy and authored dressing are now integrated. There is no new gameplay system to build.

## Decisions to preserve

1. Guard moved to the bell steps: feet (2000,736), point (2000,720), planning tile (62,22).
   The existing safe anchor stays. The outside loop/far-side junction must remain free of cards;
   the bell still requires guard victory and a separate Ring the bell interaction.
2. Defeat records nothing, including `battles_lost`. Retry retains the exact entry.
3. Threat categories stay Patrol / Guard; reveal species only through the filtered readout.
4. `WorldCopy` and runtime landmark descriptions now contain approved Director text. The town
   bell remains non-interactive. Restored-home chart copy derives from the existing bell flag.
5. Save and Save and return to title stay separate; normal title return saves first. A failed
   write never publishes progress and keeps Retry save / Return to title.
6. Keep application 0.3.0 and save version 1 until Adrian's walkthrough and subsequent release
   instruction. Exploration is intentionally silent. No commit or push is requested here.

## Engineering follow-up

The Director found no need for a combat/save/rule change. Handle concrete issues from Adrian's
acceptance sessions within the existing rules. Run world tests after geometry changes and the
full suite alone after behavioral/UI fixes. Keep the explicit theme assignment on CanvasLayer
roots. `WorldEncounterView` consumes typed public facts; the map view never loads raw definitions.
Modal focus stays contained; pointer selection updates map descriptions without travel or writes.

The fresh-copy cold import emitted a Windows **Safe save failed** startup diagnostic although
import finished. Check whether it reproduces in a normal authorized local editor run before
calling import clean. Do not disable the user's global safe-save or security preferences.
The requested 1440p capture fell back to 1080p under the screen policy; qualify 1440p on a suitable
display, not by bypassing production window safeguards.

Art follow-up belongs with the Director/artist: residual tile seams/repetition, source pose contours
and the willow's clipped canopy edge. Keep generated source/atlas provenance and version any
replacement. Scene-level bell/lamp component reuse, gate post orientation, roof overlap and shore
joins are already applied. Collision must not be derived from sprite alpha.

## Acceptance boundary

All uncoached journey, real controller, remapped-input comfort, real-profile-copy persistence,
display/art-in-motion and combat clarity/listening sessions remain **OPEN**. The report lists the
next sessions and the evidence to record. Automated traversal, seeded screenshots and dummy audio
cannot fill or pass them. Wider zones, new encounters, economy, attrition and adaptive world music
remain outside this stage. The aligned-audio pilot is separately authorized and not a dependency.
