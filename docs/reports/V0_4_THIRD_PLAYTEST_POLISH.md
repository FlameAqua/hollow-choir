# First Footsteps — third playtest presentation pass

**Small-icon frame follow-up, 9 October:** Adrian requested thinner borders for compact controls.
Toolbar/condition icons, exploration map/menu, turn-order portraits and reaction key badges now use
the existing thin atlas frame scaled as a whole, instead of the wide nine-sliced panel fittings.
Compact controls use 4px content margins; header artwork can occupy 32px and exploration artwork
40px. Portrait inset is 3px rather than 6px. Large panels, action buttons and lists keep their richer
borders. Focus/hover/pressed feedback and party/enemy/current-turn cues remain visible. Native
evidence: [compact icon frames](v0_4_control_polish/thin-icon-frames.png),
[reaction key badges](v0_4_control_polish/thin-reaction-keys.png),
[exploration controls](v0_4_control_polish/thin-exploration-icons.png).
Compilation: 241/0; focused icon UI checks: 6/0, 129 assertions. These follow-up counts include
Claude's newly returned engineering changes in the shared tree; those changes were preserved.

9 October 2026. Director/UI/art work complete in the existing uncommitted `dev` checkout after `6d8401d`; application 0.3.0 / save 1. Gameplay action switching, journey reset and outstanding tree collision work are delegated to Claude in [the new engineering continuation](../briefs/V0_4_THIRD_PLAYTEST_ENGINEERING.md).

## Implemented

- Generated and integrated 20 additional bitmap controls/materials: gold-bone selected check, dropdown chevron, vertical/horizontal scrollbar materials, map/menu/log/pause/setup/restart/turn-order icons, opaque intent socket, clearer Brace/Evade/Parry medallions, quiet peat canvas and carved botanical title wordmark. Original v02 sources/assets remain preserved.
- Popup selectors explicitly use the bundled native-grid pixel font, the game theme and nearest filtering. The Practice summary and Begin practice button now use the painted material styles. Scrollbars and top-right toolbar/map/menu controls use actual raster assets.
- All six title options fit without scrolling. Reflow after minimum-size changes fixes an initial wrapped-label measurement that could otherwise leave the panel below the screen. Native final panel bounds are (40,40), size (550.4,640), entirely inside 1280×720.
- Combat header uses the encounter title and `Round: N`; surrounding gray fill is replaced with a dark moss/peat material. Number badges use actual font metrics for centering. Intent icons regain opaque dark backing; unreadable tiny recipient portraits are removed. Hovering a move marks its public recipients with a painted rim at their feet, independently of the current action selection.
- Inspection reaction medallions are 44px before compact scaling, with a thin asset border and large emblem. Their extra square backing is removed. Active reaction-card emblems are enlarged to 36px. Reaction rules/timing are unchanged.
- Battle log has explicit wheel ownership and a higher presentation layer; history stays in place as new events arrive, then resumes following at the bottom. Log text uses the legible native 22px body grid.
- Bell Crow uses a new six-cell authored atlas: two quiet breathing frames at 0.8fps and a four-frame one-shot fidget at 4fps. A private presentation RNG schedules fidgets after 8–18 seconds of quiet. Reduce Motion holds neutral. The alpha repair is generated, not a scripted matte; generated alpha is preserved through native export. Native transparent corners and zero isolated opaque pixels were checked, and the crow was reviewed against the actual stage background. The original atlas also had zero isolated opaque pixels, so that statistic alone does not establish the earlier artifact's cause.
- The Pick an enemy/ally/target prompt now has a painted frame. Its interaction behavior is left for Claude's explicitly delegated action-switching fix.

## Verification

- Final full suite, run alone: **272 passed / 0 failed / 2,843 assertions / 63.92s**. Clean full-suite shutdown. `.godot/qa/control-full-final.log`.
- Compilation: **235 scripts / 0 failures**. Material integrity: **264 checks / 0 failures**.
- Input regression covers actual wheel-up/down over the log, appending while reading history, hovering a move's public recipients, clearing markers on exit, and retaining the selected action. Crow checks cover breathing, quiet interval, one-shot return and Reduce Motion.
- The old title test requiring a ScrollContainer was replaced with checks that no title scrollbar exists and all six buttons are on canvas; existing focus checks remain. The first full run found only that retired assertion, then the final suite passed.
- Focused UI test exits still show the previously recorded 4-object/2-resource disposal warnings; the complete suite does not. The engineering continuation retains that investigation.

Native Godot captures at 1280×720, using isolated profiles: [title](v0_4_control_polish/title.png), [dropdown](v0_4_control_polish/dropdown.png), [intent inspection and recipient rim](v0_4_control_polish/intent.png), [battle log](v0_4_control_polish/log.png), [target review](v0_4_control_polish/target.png), [reaction preparation](v0_4_control_polish/reaction.png), [settings](v0_4_control_polish/settings.png), [exploration icons](v0_4_control_polish/exploration.png). These are held capture fixtures, not timing/latency or human-play certification.

## Assets and next engineering work

Exact prompts: `docs/art/first_footsteps_v01/control_polish_v03_prompts.json`. Immutable source hashes/provenance: `control_polish_v03_sources.json`. Native mechanical export: `tools/prepare_control_polish.gd`. UI files: `assets/art/global/ui/material_v03/`; crow source/native/frames: `assets/art/global/familiars/`. Generated originals remain in the generation directory as well.

No player-facing exploration reset existed at inspection; no user save was reset. Claude's brief specifies a confirmed, transactional journey-only reset that preserves research/mastery/equipment/settings, plus direct action replacement during recipient selection and the earlier intentional trunk/root physics pass. Shared map dressing, saves, combat rules, earlier audio and new user music inbox files are preserved.
