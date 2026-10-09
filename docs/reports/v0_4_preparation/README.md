# First Footsteps — Director preparation

8 October 2026 · application still 0.3.0 · V0.3 pushed as `6d8401d`

This is **preparation for Claude's backend work**, not a playable overworld or a V0.4 release.
The [Director contract](../../design/V04_FIRST_FOOTSTEPS.md),
[authored layout](../../design/world/v04_layout.json),
[art/copy brief](../../design/V04_WORLD_ART.md) and
[Claude handoff](../../briefs/V0_4_CLAUDE_HANDOFF_PROMPT.md) define the next journey.

## Delivered presentation

- `ExplorationReadout`: already-filtered area, objective, interaction and active binding strings.
- `ExplorationHUD`: real Godot area/objective header, Map/Menu signals and contextual prompt. No
  state mutation, knowledge calculation, quest logic or world/engine references.
- F6-only `scenes/prototypes/v04_world_study.tscn`: town/route layout diagram, before/after study
  controls and explanatory Map/Menu panels. No player movement, collision, save writes or title entry.
- One authored Gloamstead layout and one Reedway loop, with stable portal/encounter/landmark IDs.
  Study geometry is intentionally plain; no finished walking sprites or terrain atlas is claimed.

The study's Map panel lists the layout for authoring review; it is not the runtime discovered map.
“After” illustrates a completed journey; the backend keeps bell and shortcut flags independent.
Actual runtime movement, portal guards, battle completion transactions, persistence, local-map
filtering, dialogue and home-lamp presentation remain Claude's work followed by Director integration.

## Display correction requested during preparation

Adrian explicitly retired the independent text-size setting and free window resizing. The
[fixed display contract](../../design/DISPLAY_PRESETS.md) now governs the game and Claude handoff:
1280×720 design canvas, 22 px body text, uniform whole-canvas scaling, five window presets and
letterboxing in fullscreen. Old font settings are ignored/removed on write; all other settings and
progress formats retain their meanings. Window fitting chooses another supported preset, never an
arbitrary rectangle. If none fits, it selects borderless fullscreen.

`UITheme.build()` now creates only the fixed theme. Existing UI regressions exercise that layout;
the former font-size/resolution cross-product was removed. The two-line reaction footer uses its
authored lines directly, avoiding the native autowrap minimum-height cache at an initial zero width.
No combat timing, reaction key or gameplay result changes.

The earlier 150/200% preparation captures were discarded as superseded working artifacts. New
captures use supported game resolutions only. Tests and captures use isolated user data and Dummy
audio, protecting the real player profile and avoiding audio-device noise in UI evidence.

## Reproduce the study

Open the development scene and run it directly, or use the isolated launcher:

```sh
python tools/qa_godot.py --godot <Godot executable> --home .godot/qa/world-study --hidden --rendering-method gl_compatibility --audio-driver Dummy res://scenes/prototypes/v04_world_study.tscn -- --study-area=briarfen --study-capture=res://docs/reports/v0_4_preparation/reedway_1280.png
```

Optional `--study-restored` shows the completed-journey illustration. `--study-size=1600x900` uses
that supported window preset. No separate text scale is accepted. The canonical scene remains the
same 1280×720 layout at either output size.

## Validation

The post-release full suite passed **213 tests / 1,721 assertions / 0 failures** in 43.27 seconds.
The final compile check passed **192 scripts / 0 failures**. The assertion count reflects removal
of the retired independent-font-scale matrix; the V0.3 release record retains its original counts.

The following native captures were visually reviewed:

- [Settings at 1280×720](settings_fixed.png): fixed window preset and no text-size control.
- [Gloamstead study at 1280×720](gloamstead_1280.png): area/objective header and interaction prompt.
- [Restored Reedway study at 1600×900](reedway_1600.png): the same logical 1280×720 canvas and
  22 px theme, uniformly scaled to the selected output preset.

The study reported a non-resizable window at each preset. The capture harness now completes its
music shutdown before exiting; the final Settings capture exited cleanly. These checks cover the
display correction and presentation starter, not the unimplemented world gameplay or human
controller, combat-comprehension and soundtrack-listening gates.
