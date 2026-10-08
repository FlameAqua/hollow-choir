# Release notes

The application version is `application/config/version` in `project.godot`. The title screen shows
it, and saves record it as informational `game_version`. Save compatibility is governed separately
by `SaveMigrator.CURRENT_VERSION` (`save_version`, still 1). Detailed evidence lives in the linked
reports. Automated checks do not establish fresh-player comprehension, controller comfort or
runtime listening; those human gates remain open. V0.3 has Director engineering acceptance for
the user-authorized push: [final acceptance](reports/V0_3_DIRECTOR_ACCEPTANCE.md).

## 0.3.0 — Field Guide and music playlists (8 October 2026)

- **Field Guide:** title-screen access to saved species notes, research sources, learned affinities,
  moves/traits and weapon practice. Unknown creatures stay hidden; temporary battle reveals do not
  become saved knowledge. Enlarged details scroll while Back stays reachable. No new unlocks.
- **Music:** all six songs approved by Adrian are integrated into title, ordinary battle and boss
  playlists. Versions shuffle without immediate repeats, overlap near their endings, and crossfade
  on scene changes. Same-cue restarts preserve playback; Music/Master mute and volume still apply.
- **Future music:** inbox preparation discovers new/replaced versions and optional tone suffixes,
  such as `_calm` / `_intense`. Matching versions support full-mix tone transitions. True simultaneous
  layers remain future work requiring sample-aligned arrangements; current tracks are not beat synced.
- **Audio testing/import:** the supplied v01 intense battle mix is included. The title's Audio Lab
  changes versions/tones at the same source timestamp, supports click/drag/keyboard seeking,
  and previews endings with a five-second countdown before automatic rotation. Next version
  explicitly starts another mix from zero; rapid tone changes do not drift the playhead.
  `tools/import_music.py` takes file paths, normalizes names and rebuilds playlists; `--replace`
  archives previous audio/metadata. Boss inbox filenames and sidecars now use underscores.
- **Readability:** the reaction footer uses two measured font-height rows at 200%, preserving every
  bound reaction key and the first-press rule.
- **Tools:** measured, cached Ogg preparation preserves original hashes; new audio/readout regression
  tests and Field Guide capture fixtures. See [V0.3 evidence](reports/V0_3_FIELD_GUIDE_AND_AUDIO.md).
- **Engineering review:** corrected audio cursor drift, rapid fade reversal, end overlaps, ended-deck
  seeking and preview cancellation; shared the research predicates across engine and presentation.
  Preparation repairs incomplete cached source metadata without re-encoding and consistently rejects
  version zero. Final checks: 212 Godot tests / 1,976 assertions and nine Python tests passed.

No combat rules, balance, timing windows, saved bindings or save formats changed (`save_version` 1).
The human clarity gate remains open; no world/expedition runtime is included in this release.

## 0.2.1 — engineering cleanup and stabilization (8 October 2026)

No combat rules, balance, timing windows, content, save formats or bindings changed.
Report: [V0.2.1 engineering cleanup](reports/V0_2_1_ENGINEERING_CLEANUP.md).

- **Fixed:** an open unit inspection card could keep showing stale facts. Example: an ally became
  covered (Intercept) while hovered, and the card did not show the cover. The card's refresh key
  now comes from the same filtered `UnitReadout` that it draws.
- **Fixed:** wheel ownership between expanded details and the Actions/Supplies lists depended on
  node order. One rule (`HoverInspector.claims_wheel`) now decides for both handlers.
- **Consistent:** the pause button's explanation no longer changes after switching input devices.
- **Removed (no player-visible effect):** the hidden party panel and `PartyCard`, the hidden
  `DetailsPanel`, an unused stacked-layout dimmer and re-layouts, the action picker's unused
  group path, analysis text that nothing displayed, pinned-inspection fields, never-drawn turn and
  target words, the unused plate badge, and unused intent-strip modes, stats and selection.
  `BattleLayout.familiar` is now `BattleLayout.supplies`.
- **Tooling:** `tools/qa_godot.py` runs tests and captures with isolated user data. The test
  runner and capture tool print the user data directory and refuse to run if requested isolation
  failed. The capture tool now covers the V0.2 states: opening and condition announcements, held
  preparation, inspection, recipient review, and Setup/resume.
- **Hygiene:** Godot no longer imports `docs/` (CSV tables were being imported as translations),
  and stale generated import artifacts there were removed.
- **Docs:** corrected README controls, links, version and test commands. Updated TESTING and
  DATA_CONTRACTS.

## 0.2 — UI corrections, support presentation and pre-push polish (8 October 2026)

Committed as "V0.2". `project.godot` still read 0.1.0 at that commit. Evidence:
[V0.2 UI evidence](reports/v02_ui/README.md), [support presentation](reports/v02_ui/SUPPORT_PRESENTATION.md)
and [opening/timing preview](reports/v02_ui/OPENING_AND_TIMING_PREVIEW.md).

- One immediate contextual inspector with per-icon explanations and shared structured
  action/enemy-move cards. Explicit recipient review applies even to a sole legal target.
- Practice/Lab have a fixed footer. There are five window sizes. Setup exclusively covers and
  suspends the battle. Enter/gamepad A confirm, and Space/Z remain command inputs.
- Authored support rules and named support effects, Cinder Pup art (display scale 1.2), textured
  HP/break bars, and condition cards that dock to their header icon.
- Expanded details own the wheel over their source. A 400 ms preparation beat shows the actual
  command meter or reaction ring at zero time. Announcements fit their settled text and suppress
  hover until they finish.
