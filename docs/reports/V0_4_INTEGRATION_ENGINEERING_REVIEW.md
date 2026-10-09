# V0.4 First Footsteps — engineering review of the Director integration

Claude · 9 October 2026 · uncommitted `dev` after `6d8401d` · application 0.3.0 / save version 1
**Not committed or pushed. No rule, save schema, version or authored-scene geometry changed.**

Scope: review the Director's integration ([acceptance](V0_4_DIRECTOR_ACCEPTANCE.md),
[brief](../briefs/V0_4_POST_INTEGRATION.md)), investigate the Windows “Safe save failed” import
diagnostic and fix concrete regressions. Area scenes were not regenerated; `--force` was not run.

## How the integration was reviewed

My final V0.4 tree from the previous session survives as a scratch snapshot, so every integration
change was reviewed as an exact diff rather than from the report. Changed code:
`world_host.gd` (bench/map/menu layout, encounter view), `world_player.gd` (presentation snap),
`world_modal.gd` (fixed frames, scrolling content, contained focus), new `world_encounter_view.gd`,
`world_map_view.gd`, `world_rules.gd` (prompt templates via `WorldCopy`, restored-home description),
`world_copy.gd`, `field_guide.gd` (empty-state copy), capture runner, new presentation tests.

Area scenes were compared structurally (node sets, transforms and properties):

- **Unchanged:** `Collision` tile data, every footprint, the latch barrier, all `Anchors`, all
  `Portals`, every `Interactions` point except the guard. Other property differences are only the
  editor renumbering ext-resource IDs on save.
- **Changed as decided:** `GuardGroup` (1936,832) → (2000,736) and `Interactions/bell_guard`
  (1936,816) → (2000,720); planning tile 60,25 → 62,22 in data and layout.
- **Presentation only:** bell/lamp states now split shared frame sprites from small changing
  regions (still under the same `WorldStateView` nodes); reed-gate posts replace the scaled sprite;
  `LowDecoration/BankEdges` mesh; boardwalk cells on `GroundDetail`. No new collision node.

Behavioural boundaries hold: `WorldEncounterView` reads only `EncounterCardReadout`; the map view
reads only `WorldMapReadout`; every world action still goes through `WorldSession`; the CanvasLayer
theme assignment remains; physics feet stay continuous while art/camera snap to world pixels.

## Concrete issues found and fixed

| # | Issue | Evidence | Fix |
|---|---|---|---|
| 1 | **Bench soft-lock after a failed save + Retry** (my original code, carried through integration). Choosing a weapon whose save fails replaces the bench with the save-failure card; a later successful *Retry save* ran a callback that relabelled the freed bench, raising a script error and leaving the host in modal mode with no modal (no input). | New test reproduced `previously freed` / `Lambda capture … was freed` errors and a null modal. Other retry paths were traced: their callbacks capture only resources, entries or the host. | `world_host.gd`: the success callback captures only `landmark`/`weapon` and calls `_show_bench_choice()`, which relabels the open bench or reopens it focused on the chosen weapon. Regression: `test_bench_choice_survives_a_failed_save_and_retry`. |
| 2 | **QA isolation gap.** `qa_godot.py` redirected `APPDATA`/`XDG_DATA_HOME` but not the cache location, so QA editor runs wrote thumbnails/class-doc caches into Adrian's real `%LOCALAPPDATA%\Godot`, shared with his own editor and concurrent QA runs. | Files stamped by this session's QA runs were present there. | Launcher sets `LOCALAPPDATA`/`XDG_CACHE_HOME` to `<home>/cache` (`isolated_environment()`); `qa_user_data.gd` refuses a run whose cache escaped the home. Verified: a windowed QA editor run wrote 903 cache files into its home and **none** into the real cache (newest write time and file count unchanged). Tests: `tests/test_qa_godot.py`, `unit/test_qa_isolation.gd`. |
| 3 | **Editor churn on a tracked file.** Every windowed editor session re-saves `project.godot` and drops the default-valued `window/stretch/aspect="keep"` added by the display correction, so opening the editor dirtied the file (and looked like a removed setting). | Reproduced with a cold copy: content changed after one windowed session; headless `--import` never touched it. | Removed the redundant line (Godot's default is `keep`; `Settings._apply_window()` also enforces KEEP at runtime). With the canonical file, a windowed session still saves but the bytes stay identical. Against HEAD the diff reads `aspect="expand"` → removed, i.e. the default `keep`. |

## “Safe save failed” investigation

**Result: not reproducible in normal local runs — 16 editor runs, 0 diagnostics** (11 headless
cold/warm imports with fresh and reused homes, 5 windowed editor sessions), all on fresh copies with
isolated homes, before and after the fixes above. No stray `*.tmp` exists in the repo, its `.godot`,
any QA home or the real `%LOCALAPPDATA%\Godot`, so no file on this machine was left half-replaced.

**Mechanism (reproduced deliberately):** Godot's editor saves through a temporary file and an atomic
replace (`file_access_windows.cpp:277`). Making a throwaway home's `editor_settings-4.7.tres`
read-only produced exactly this diagnostic; the import still exited 0, the old file was kept and
`editor_settings-4.7.tres<digits>.tmp` was left beside it. Any environment that cannot replace an
existing file within Godot's retry window (read-only/locked target, aggressive scanner, a sandbox
denying replace-over) shows it. A simulated 4 s exclusive lock on the freshly created editor
settings did not trigger it, so a normal headless import does not re-save that file early.

**History:** the same line appears in Director-environment notes since V0.2 (“sandboxed editor
settings”), and the surviving V0.3 import log shows it *before* the project scan. Headless import
writes no tracked project file; only windowed sessions re-save `project.godot`. The diagnostic is
therefore specific to the Director's sandbox, not a project content defect. Import completed in
every case. **Recommendation:** if it recurs there, look for the `<file><digits>.tmp` it leaves to
name the file; with the updated launcher, editor caches now also stay inside the QA home. No editor
safe-save, security or system setting was changed.

## Other observations (no change made)

- Running some suites alone ends with “ObjectDB instances leaked / resources still in use”. Verbose
  output shows only the battle-music Ogg stream and its playback, still fading when the process
  exits (also in the pre-existing V0.3 `test_battle_ui` / `test_presentation_boundaries`). No world
  object is retained; the Pause → Leave battle path shows no leak; the full suite reports none.
- `WorldModal` places frames in fixed 1280×720 coordinates. That is correct under the fixed display
  contract; revisit only if that contract ever changes.
- **Concurrent work:** while this review ran, another agent regenerated placeholder SFX
  (`assets/audio/sfx/*`, generator, SFX README, an `audio_manager.gd` comment, `docs/reports/v0_4_audio`).
  My verified snapshot already contained the regenerated WAV/manifest/import files; later edits were
  a comment and a generator refactor of manifest metrics. I did not review or change that work.

## Verification (fresh copy of the working tree, isolated homes, suite run alone)

| Check | Result |
|---|---|
| Cold `--import` (updated launcher) | exit 0; no safe-save line, no errors or warnings; no stray `.tmp` |
| `tools/check_scripts.gd` | **227 scripts, 0 failed** |
| Full Godot suite | **262 passed, 0 failed, 2,713 assertions** (59.3 s), exit 0 |
| Diagnostics | 4 documented invalid-save errors, the documented rejected-action warning, intended `WorldSession` sanitize warnings, and one deliberate `QA isolation failed: cache …` line from the guard test |
| Simulation smoke (all encounters, MIXED, 10 runs, seed 1) | exit 0, 0 errors; output **identical** to the `6d8401d` baseline (91 lines) |
| Python tooling tests | **10 OK** (9 existing + launcher isolation) |
| World art validation | **204 checks, 0 failures** |
| Tracked files after import/suite/sim | unchanged (only the concurrent SFX text edits differ from the snapshot) |

New tests (3): `world/test_world_journey.gd` — the real feet body walks every authored link in both
dressed areas (bench, Bellkeeper, gate, main approach with the patrol card + Leave, guard card,
Engage and committed victory, bell, outside loop, overlook, far side, opened short return, home
acknowledgement) and every landmark/link reaches the last write; plus the bench retry regression
and the QA cache-isolation guard. Traversal is scripted with synthetic battle outcomes; it is
evidence that geometry and boundaries work, not human play.

## Files changed in this pass

`src/world/world_host.gd` (bench retry), `tools/qa_godot.py`, `tools/qa_user_data.gd`,
`project.godot` (one redundant default line), `docs/TESTING.md`; new `tests/world/test_world_journey.gd`,
`tests/unit/test_qa_isolation.gd`, `tests/test_qa_godot.py` (+ generated `.uid` files); this report.

## Remaining issues

1. All human sessions in the Director acceptance remain **open**: uncoached journey, controller and
   remapped traversal, real-profile-copy persistence, display/art in motion, M1.1 clarity/listening.
2. The Director-sandbox safe-save diagnostic is unexplained in that environment only; capture the
   orphaned `.tmp` name if it recurs. Not reproducible on this machine.
3. 1440p output is still unqualified (this display falls back to 1080p under the window policy).
4. Art follow-ups stay with the Director/artist (tile seams/repetition, source pose contours, willow
   canopy edge). The 0.4.0 bump awaits Adrian's walkthrough.
