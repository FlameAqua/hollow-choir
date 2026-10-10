# V0.5 playtest revision — rendered evidence

10 October 2026 · Godot 4.7.2 · Compatibility renderer, Dummy audio · isolated QA homes.

These are reviewed implementation captures, not human acceptance or a full playthrough.
[Feedback coverage, verification and open gates](../V0_5_PLAYTEST_DIRECTOR_IMPLEMENTATION.md).
[Broad-suite failure inventory](FAILURE_INVENTORY.md). No player saves are used.

## Main presentation

| Screen | 1280×720 | 1920×1080 |
|---|---|---|
| Title | [view](title_1280x720.png) | [view](title_1920x1080.png) |
| Settings | [view](settings_1280x720.png) | [view](settings_1920x1080.png) |
| Long dialogue | [view](dialogue_1280x720.png) | [view](dialogue_1920x1080.png) |
| Loadout | [view](loadout_1280x720.png) | [view](loadout_1920x1080.png) |
| Inventory | [view](inventory_1280x720.png) | [view](inventory_1920x1080.png) |
| Forge | [view](forge_1280x720.png) | [view](forge_1920x1080.png) |
| Stillroom | [view](stillroom_1280x720.png) | [view](stillroom_1920x1080.png) |
| Journal | [view](journal_1280x720.png) | [view](journal_1920x1080.png) |
| Mixed reward + learning | [view](reward-learnings_1280x720.png) | [view](reward-learnings_1920x1080.png) |
| Battle planning | [view](battle_planning_1280x720.png) | [view](battle_planning_1920x1080.png) |
| Reaction at impact | [view](battle_reaction_1280x720.png) | [view](battle_reaction_1920x1080.png) |
| Field Guide | [view](battle_field-guide_1280x720.png) | [view](battle_field-guide_1920x1080.png) |

Loadout at the other supported presets: [1366×768](loadout_1366x768.png),
[1600×900](loadout_1600x900.png), [2560×1440](loadout_2560x1440.png).

## Capacity, ownership and feedback variants

- [15 of 20 bag capacity](inventory15_1280x720.png); [owned gear popup](loadout-popup_1280x720.png).
- Forge: [locked/mastery](forge-locked_1280x720.png), [crafted → Fit](forge-owned_1280x720.png),
  [installed → Remove](forge-fitted_1280x720.png).
- Stillroom: [no ingredients](stillroom-poor_1280x720.png), [depleted supplies](stillroom-depleted_1280x720.png),
  [unprepared stock](stillroom-stock_1280x720.png).
- [Reward inspection](reward_inspection.png): no fixed inspector; both reward rows and Continue stay visible.
  [No changed learning](reward_1280x720.png) omits that section.
- [Reduced-motion title](title_reduced.png).
- Checkboxes: [unchecked](settings_checkbox_unchecked.png), [hover](settings_checkbox_hover.png),
  [pressed](settings_checkbox_pressed.png), [checked/focused](settings_checkbox_focused.png),
  [checked/disabled](settings_checkbox_disabled.png). All retain the same row and icon reservation.
- Supplied HUD facts: [countdown](countdown_1280x720.png), [frozen](countdown-frozen_1280x720.png),
  [quest change](quest_1280x720.png), [automatic save](autosave_1280x720.png),
  [manual save](manual-save_1280x720.png).

## Tooltip edge sweep

The small `?` control is a capture-only source placed at a canvas corner, with New Journey copy.
The game keeps its fixed 1280×720 canvas at each display preset.

| Preset | Top left | Top right | Bottom left | Bottom right |
|---|---|---|---|---|
| 1280×720 | [view](tooltip_tl.png) | [view](tooltip_tr.png) | [view](tooltip_bl.png) | [view](tooltip_br.png) |
| 1366×768 | [view](tooltip_tl_1366x768.png) | [view](tooltip_tr_1366x768.png) | [view](tooltip_bl_1366x768.png) | [view](tooltip_br_1366x768.png) |
| 1600×900 | [view](tooltip_tl_1600x900.png) | [view](tooltip_tr_1600x900.png) | [view](tooltip_bl_1600x900.png) | [view](tooltip_br_1600x900.png) |
| 1920×1080 | [view](tooltip_tl_1920x1080.png) | [view](tooltip_tr_1920x1080.png) | [view](tooltip_bl_1920x1080.png) | [view](tooltip_br_1920x1080.png) |
| 2560×1440 | [view](tooltip_tl_2560x1440.png) | [view](tooltip_tr_2560x1440.png) | [view](tooltip_bl_2560x1440.png) | [view](tooltip_br_2560x1440.png) |

## Actual host integration

| Capture | What is real / what is held for review |
|---|---|
| [Countdown](host_revision-countdown.png) / [cancelled](host_revision-cancelled.png) | WorldHost countdown rules and HUD, 1.80 s active then cancelled with zero new writes. Player placement and clock are held fixtures, not traversal/fairness acceptance |
| [Quest update](host_revision-quest.png) | Actual restore_bell transaction from an explicit guard-cleared setup; supplied quest change and saved pickups |
| [Journal](host_revision-journal.png) | Actual host open_journal and session.quests readout |
| [Manual save](host_revision-save-manual.png) / [automatic](host_revision-save-auto.png) | Actual session.save versus changed equip command; authoritative save origin drives card/icon |
| [Loadout](host_character-equipment.png), [Forge](host_forge.png), [Stillroom](host_stillroom.png) | Actual host routing, supplied production readouts and memory writer; station funding/mastery are explicit fixtures |
| [Saved victory](host_victory.png) | Real captured encounter entry and commit_victory path, with a synthetic BattleResult. Shows actual tier transition and granted receipt; not a played victory |
| [Upright Broken enemy](battle_broken.png) / [independent party Break](battle_party_break.png) | Production battle controls over a display-ledger fixture. The party image empties one meter and marks that unit Broken, leaving the other full; no engine rule is fabricated |

`capture_playtest_revision.gd` supplies isolated production-widget fixtures; its runner is not a
standalone main-loop script. `capture_world.gd` and `capture_battle.gd` exercise host/battle routes
as described above. Static captures cannot accept controller feel, motion, sound, countdown fairness,
Break balance, economy or the [earlier full human checklist](../../playtests/V0_5_INTEGRATED_TEST.md).

## Latest additional-feedback captures

These supersede the earlier matching layouts: [Anvil](followup_forge.png), [Stillroom and empty stock](followup_stillroom.png), [Character](followup_loadout.png), [continuous controls](followup_settings.png), [tiny Menu hint and toolbelt order](followup_menu-hint.png), [reaction preparation at 0 ms](followup_reaction_initial.png). All six were rendered and reviewed at 1280×720. No further title captures were taken in this follow-up. Human acceptance remains open.
