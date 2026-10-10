# V0.5 revision — integration failures retained for Claude

10 October 2026. These failures are not waived. All listed files remain Claude-owned; the Director
has not changed their rules or assertions. Logs are isolated QA runs, with engine processes run
sequentially. Claude continued file edits during these observations.

| Run | Passed | Failed | Assertions | Seconds |
|---|---:|---:|---:|---:|
| [headless-01](logs/director-full-headless-01.log) | 449 | 27 | 7,724 | 126.17 |
| [Compatibility-01](logs/director-full-compatibility-01.log) | 476 | 26 | 9,592 | 126.94 |
| [headless-02](logs/director-full-headless-02.log) | 497 | 26 | 10,143 | 141.52 |
| [Compatibility-02](logs/director-full-compatibility-02.log) | 511 | 8 | 10,129 | 139.99 |

Counts differ because new suites and owner fixes landed during the window. The last Compatibility
run skipped one suite with a load error, so 511/8 is not full acceptance. The later all-script check
passes **350/0**, but that alone does not rerun the skipped assertions. Source snapshots in `logs/`
record hashes before/between/after the `02` pair. Files changed across that pair:

- `src/ui/battle/hover_inspector.gd` and `tests/ui/test_playtest_revision.gd` (Director: short-tooltip
  footer sizing and regression; verified again separately after the broad runs).
- `tests/unit/test_loadout_rules.gd`, `tests/unit/test_supply_rules.gd` and
  `tests/world/test_world_revision_session.gd` (Claude).

## Last observed Compatibility failures

| File / test | Observed evidence | Required owner follow-up |
|---|---|---|
| `test_loadout_rules.gd` (suite load) | Missing `_action_ids()` at lines 73/74/88/89 while the file was being edited | Later compilation passes; rerun the complete suite, then verify no shared-resource contamination across the full run |
| `test_world_combat_arrangement::test_character_view_arranges_equips_and_shows_typed_reasons` | Removed legacy status node accessed at line 221 | Target the current Loadout source/destination/short-status controls; preserve saved order, rejection and read-only assertions |
| `test_world_revision_host::test_entering_reach_counts_down_and_walking_away_cancels_for_free` | Expected false at line 146 | Investigate cancellation/rearm/arming state. Keep the movement-away and zero-write contract; do not dismiss as a layout migration |
| `test_world_revision_host::test_tapping_into_a_wall_never_reads_as_walking` | Physics error: `body->get_space()` is null | Ensure the test body has entered a physics space, then verify repeated taps/held input/slide/footsteps against the real correction |
| `test_world_salvage_host::test_inventory_round_trip_is_read_only_and_retains_the_selected_slot` | Material button text now empty instead of ×4/×1, lines 222/223 | Quantities are child `Quantity` labels in the shared IngredientStrip. Preserve read-only, focus and selected-slot checks |
| `test_world_salvage_host::test_failed_bell_write_shows_no_receipt_and_retry_shows_one` | Expected 1 write, got 2, line 279 | Account for authoritative one-time finite-stock reconciliation in the setup; preserve no grant/receipt on failed writes and one adoption on Retry |
| `test_world_save_events::test_host_adds_no_notice_of_its_own_and_hides_cards_in_battle` | Old automatic-card expectation (line 126); then freed AutosaveIcon.show | Line 130 deletes every JourneyNotices child, including permanent AutosaveIcon/OperationFeedback. Clear Notice cards only; assert automatic icon/manual card and battle hiding with one event owner |
| `test_world_session::test_world_section_round_trips_through_a_real_save_file` | Pending-entry `potion_charges` [2,2] becomes JSON [2.0,2.0], lines 282/284 | Investigate and normalize persisted snapshot integers as needed; retain whole-snapshot and retry determinism coverage |

The `headless-02` run also exposed shipped sword/charm fixture contamination: Earthsplitter appeared
in the starter loadout and pushed real gear beyond capacity. The owner was editing its duplicate
array fixture during the pair. This explains a cluster of observations, but requires a stable full
rerun to prove closure. The earlier runs contain old permanent-kit/unlimited-supply/encounter-card/
quest-reset expectations; migrate their setups and preserve transaction/replay/knowledge coverage.

The Director-owned focused suites pass separately; they do not override these failures.
Stable full headless and Compatibility/Dummy verification remains Claude's integration gate after
the protected files stop changing. Human input, listening, economy and balance gates remain open.

## Exact failure names by snapshot

The lists below are extracted verbatim from each run's FAIL headings. Full assertions remain in
the linked logs, including assertions whose large dictionaries are unsuitable for this index.

### director-full-headless-01

- `test_stage_art::test_title_menu_has_focus_and_a_bounded_fixed_layout`
- `test_world_combat_arrangement::test_old_saves_migrate_deterministically`
- `test_world_combat_arrangement::test_character_view_arranges_equips_and_shows_typed_reasons`
- `test_world_crafting::test_station_services_gate_station_work_and_supplies_are_field_choices`
- `test_world_crafting::test_rejections_are_typed_change_nothing_and_publish_nothing`
- `test_world_crafting::test_duplicate_traits_are_rejected_without_removing_anything`
- `test_world_crafting::test_an_over_limit_loadout_rejects_station_commands_whole`
- `test_world_crafting::test_failed_writes_change_nothing_and_a_retry_publishes_once`
- `test_world_crafting::test_refunds_conserve_materials_and_clear_the_fitting_together`
- `test_world_crafting::test_the_real_route_funds_everything_and_unlocks_survive_reset_and_reload`
- `test_world_crafting::test_older_saves_reconcile_potions_and_keep_unknown_ids_inert`
- `test_world_crafting::test_the_fitting_reaches_the_next_entry_and_a_retry_never_changes`
- `test_world_crafting::test_potion_preparation_reaches_battle_with_unchanged_capacities`
- `test_world_crafting::test_readouts_are_typed_copies_without_creature_facts`
- `test_world_crafting::test_other_saves_and_shared_resources_are_unaffected`
- `test_world_host::test_encounter_card_cancel_costs_nothing_and_engage_launches_once`
- `test_world_host::test_victory_return_rearms_triggers_from_the_engagement_spot`
- `test_world_journey::test_complete_journey_walks_every_authored_link`
- `test_world_presentation::test_guard_card_still_opens_on_the_bell_steps`
- `test_world_reset::test_reset_restarts_only_the_journey_and_keeps_combat_progression`
- `test_world_reset::test_confirmed_reset_rebuilds_the_host_at_the_square_once`
- `test_world_reset::test_reset_writes_only_the_active_slot`
- `test_world_rewards::test_incomplete_older_saves_receive_only_what_their_journey_proves`
- `test_world_salvage_host::test_inventory_round_trip_is_read_only_and_retains_the_selected_slot`
- `test_world_salvage_host::test_failed_bell_write_shows_no_receipt_and_retry_shows_one`
- `test_world_save_events::test_host_adds_no_notice_of_its_own_and_hides_cards_in_battle`
- `test_world_session::test_world_section_round_trips_through_a_real_save_file`

### director-full-compatibility-01

- `test_world_combat_arrangement::test_old_saves_migrate_deterministically`
- `test_world_combat_arrangement::test_character_view_arranges_equips_and_shows_typed_reasons`
- `test_world_crafting::test_station_services_gate_station_work_and_supplies_are_field_choices`
- `test_world_crafting::test_rejections_are_typed_change_nothing_and_publish_nothing`
- `test_world_crafting::test_duplicate_traits_are_rejected_without_removing_anything`
- `test_world_crafting::test_an_over_limit_loadout_rejects_station_commands_whole`
- `test_world_crafting::test_failed_writes_change_nothing_and_a_retry_publishes_once`
- `test_world_crafting::test_refunds_conserve_materials_and_clear_the_fitting_together`
- `test_world_crafting::test_the_real_route_funds_everything_and_unlocks_survive_reset_and_reload`
- `test_world_crafting::test_older_saves_reconcile_potions_and_keep_unknown_ids_inert`
- `test_world_crafting::test_the_fitting_reaches_the_next_entry_and_a_retry_never_changes`
- `test_world_crafting::test_potion_preparation_reaches_battle_with_unchanged_capacities`
- `test_world_crafting::test_readouts_are_typed_copies_without_creature_facts`
- `test_world_crafting::test_other_saves_and_shared_resources_are_unaffected`
- `test_world_host::test_encounter_card_cancel_costs_nothing_and_engage_launches_once`
- `test_world_host::test_victory_return_rearms_triggers_from_the_engagement_spot`
- `test_world_journey::test_complete_journey_walks_every_authored_link`
- `test_world_presentation::test_guard_card_still_opens_on_the_bell_steps`
- `test_world_reset::test_reset_restarts_only_the_journey_and_keeps_combat_progression`
- `test_world_reset::test_confirmed_reset_rebuilds_the_host_at_the_square_once`
- `test_world_reset::test_reset_writes_only_the_active_slot`
- `test_world_rewards::test_incomplete_older_saves_receive_only_what_their_journey_proves`
- `test_world_salvage_host::test_inventory_round_trip_is_read_only_and_retains_the_selected_slot`
- `test_world_salvage_host::test_failed_bell_write_shows_no_receipt_and_retry_shows_one`
- `test_world_save_events::test_host_adds_no_notice_of_its_own_and_hides_cards_in_battle`
- `test_world_session::test_world_section_round_trips_through_a_real_save_file`

### director-full-headless-02

- `test_loadout_rules::test_positions_supplies_and_bag_report_the_backends_capacities`
- `test_reward_rules::test_shipped_rewards_follow_the_v05a_table`
- `test_world_combat_arrangement::test_commands_write_once_and_reject_whole`
- `test_world_combat_arrangement::test_entries_capture_the_order_and_a_retry_never_changes`
- `test_world_combat_arrangement::test_gear_changes_reconcile_the_arrangement_in_the_same_write`
- `test_world_combat_arrangement::test_old_saves_migrate_deterministically`
- `test_world_combat_arrangement::test_character_view_arranges_equips_and_shows_typed_reasons`
- `test_world_crafting::test_an_over_limit_loadout_rejects_station_commands_whole`
- `test_world_crafting::test_readouts_are_typed_copies_without_creature_facts`
- `test_world_preparation::test_equipment_is_a_field_command_blocked_only_by_an_encounter`
- `test_world_preparation::test_failed_equip_write_changes_nothing_and_retry_applies_once`
- `test_world_preparation::test_an_over_limit_loadout_is_rejected_whole`
- `test_world_preparation::test_every_owned_shipped_choice_fits_the_eight_slots`
- `test_world_preparation::test_readouts_match_ownership_and_never_share_state`
- `test_world_preparation::test_the_charm_reaches_the_next_entry_and_a_real_wet_shock_battle`
- `test_world_revision_host::test_entering_reach_counts_down_and_walking_away_cancels_for_free`
- `test_world_revision_host::test_tapping_into_a_wall_never_reads_as_walking`
- `test_world_revision_session::test_every_successful_write_publishes_its_origin_once`
- `test_world_revision_session::test_equipment_publishes_one_structured_fact_per_changed_command`
- `test_world_salvage_host::test_the_anvil_interaction_owns_the_station_context_and_equipment_needs_none`
- `test_world_salvage_host::test_charm_ui_equips_retries_and_removes_without_leaving_the_station`
- `test_world_salvage_host::test_inventory_round_trip_is_read_only_and_retains_the_selected_slot`
- `test_world_salvage_host::test_failed_bell_write_shows_no_receipt_and_retry_shows_one`
- `test_world_save_events::test_every_world_write_publishes_one_save_event_after_adoption`
- `test_world_save_events::test_host_adds_no_notice_of_its_own_and_hides_cards_in_battle`
- `test_world_session::test_world_section_round_trips_through_a_real_save_file`

### director-full-compatibility-02

- `res://tests/unit/test_loadout_rules.gd: could not load (parse error?)`
- `test_world_combat_arrangement::test_character_view_arranges_equips_and_shows_typed_reasons`
- `test_world_revision_host::test_entering_reach_counts_down_and_walking_away_cancels_for_free`
- `test_world_revision_host::test_tapping_into_a_wall_never_reads_as_walking`
- `test_world_salvage_host::test_inventory_round_trip_is_read_only_and_retains_the_selected_slot`
- `test_world_salvage_host::test_failed_bell_write_shows_no_receipt_and_retry_shows_one`
- `test_world_save_events::test_host_adds_no_notice_of_its_own_and_hides_cards_in_battle`
- `test_world_session::test_world_section_round_trips_through_a_real_save_file`
