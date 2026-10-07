extends TestCase
## Save foundation, settings persistence, bindings and progression updates.

const TEST_SAVE := "user://test_saves/slot_test.json"


func after_each() -> void:
	for path in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_progress_round_trip_through_json() -> void:
	var progress := ProgressState.new()
	progress.loadout_weapon = &"thunderhead"
	progress.loadout_potions = [&"focus_tincture"]
	progress.bestiary.add(&"bogshell", Enums.ResearchSource.INSPECT, 3)
	progress.bestiary.add(&"bogshell", Enums.ResearchSource.DEFEAT, 2)
	progress.weapon_mastery[&"thunderhead"] = 7
	progress.materials[&"fen_reed"] = 12
	progress.region_pressure[&"briarfen"] = 2
	progress.world_choices[&"drowned_chapel"] = "STABILIZE"
	progress.battles_won = 4
	var text := JSON.stringify(SaveMigrator.wrap(progress.to_dict(), 1))
	var restored := ProgressState.from_dict(SaveMigrator.migrate(JSON.parse_string(text)))
	assert_eq(restored.loadout_weapon, &"thunderhead")
	assert_eq(restored.loadout_potions, [&"focus_tincture"] as Array[StringName])
	assert_eq(restored.bestiary.points_for(&"bogshell"), 5)
	assert_has(restored.bestiary.sources[&"bogshell"], Enums.ResearchSource.INSPECT)
	assert_eq(restored.weapon_mastery[&"thunderhead"], 7)
	assert_eq(restored.materials[&"fen_reed"], 12)
	assert_eq(restored.region_pressure[&"briarfen"], 2)
	assert_eq(restored.world_choices[&"drowned_chapel"], "STABILIZE")
	assert_eq(restored.battles_won, 4)


func test_atomic_write_and_read() -> void:
	var payload := {"save_version": 1, "data": {"hello": "fen"}}
	assert_eq(SaveManager.write_json_atomic(TEST_SAVE, payload), OK)
	assert_false(FileAccess.file_exists(TEST_SAVE + ".tmp"), "temp file renamed away")
	assert_eq(SaveManager.read_json(TEST_SAVE).data.hello, "fen")


func test_migrator_rejects_missing_and_future_versions() -> void:
	expect_engine_errors(2)
	assert_empty(SaveMigrator.migrate({"data": {}}), "no version")
	assert_empty(SaveMigrator.migrate({"save_version": SaveMigrator.CURRENT_VERSION + 1, "data": {"a": 1}}), "future version")
	assert_eq(SaveMigrator.migrate({"save_version": SaveMigrator.CURRENT_VERSION, "data": {"a": 1}}).a, 1)


func test_corrupt_file_is_rejected_not_crashing() -> void:
	expect_engine_errors(2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_empty(SaveManager.read_json(TEST_SAVE))


func test_battle_result_feeds_bestiary_and_mastery() -> void:
	var research := ResearchConfig.new()
	var result := BattleResult.new()
	result.outcome = Enums.BattleOutcome.VICTORY
	result.research[&"thornhound"] = PackedInt32Array([Enums.ResearchSource.ENCOUNTER, Enums.ResearchSource.INSPECT,
		Enums.ResearchSource.DEFEAT])
	result.weapon_uses[&"reedbow"] = 5
	result.weapon_perfects[&"reedbow"] = 2
	var progress := ProgressState.new()
	progress.apply_battle_result(result, research)
	assert_eq(progress.bestiary.points_for(&"thornhound"), 1 + 3 + 2)
	assert_eq(progress.bestiary.level(&"thornhound", research), Enums.ResearchLevel.STUDIED)
	assert_eq(progress.weapon_mastery[&"reedbow"], 7, "Perfect actions count double")
	assert_eq(progress.battles_won, 1)


func test_settings_persist_and_resolve_assist_overrides() -> void:
	var settings := GameSettings.new()
	settings.tactical_difficulty = Enums.TacticalDifficulty.TACTICIAN
	settings.execution_assist = Enums.ExecutionAssist.GENEROUS
	settings.auto_brace = GameSettings.Toggle.ON
	settings.text_scale = 1.3
	settings.bindings[InputBindings.PARRY] = PackedStringArray(["key:K"])
	var config := ConfigFile.new()
	settings.write_to(config)
	var restored := GameSettings.new()
	restored.read_from(config)
	assert_eq(restored.tactical_difficulty, Enums.TacticalDifficulty.TACTICIAN)
	assert_eq(restored.execution_assist, Enums.ExecutionAssist.GENEROUS)
	assert_almost_eq(restored.text_scale, 1.3)
	assert_eq(restored.bindings[InputBindings.PARRY], PackedStringArray(["key:K"]))
	var preset := ExecutionAssistProfile.new()
	var resolved := restored.resolve_assist(preset)
	assert_true(resolved.auto_brace, "override applied")
	assert_false(preset.auto_brace, "preset resource untouched")


func test_settings_clamp_bad_values() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "text_scale", 9.0)
	config.set_value("display", "combat_speed", -3.0)
	var settings := GameSettings.new()
	settings.read_from(config)
	assert_almost_eq(settings.text_scale, 1.75)
	assert_almost_eq(settings.combat_speed, 0.5)


func test_input_bindings_install_and_round_trip() -> void:
	InputBindings.install({InputBindings.BRACE: ["key:Q", "joy:4"]})
	var codes := InputBindings.codes_for(InputBindings.BRACE)
	assert_eq(codes, PackedStringArray(["key:Q", "joy:4"]))
	assert_true(InputMap.has_action(InputBindings.PARRY))
	assert_eq(InputBindings.codes_for(InputBindings.PARRY), PackedStringArray(["key:D", "joy:10"]))
	InputBindings.install()
	assert_eq(InputBindings.codes_for(InputBindings.BRACE), PackedStringArray(["key:A", "joy:9"]))


func test_reaction_keys_do_not_collide() -> void:
	var seen := {}
	for action in [InputBindings.BRACE, InputBindings.EVADE, InputBindings.PARRY]:
		for code in InputBindings.DEFAULTS[action]:
			if String(code).begins_with("key:"):
				assert_false(seen.has(code), "%s bound twice" % code)
				seen[code] = true


func test_game_state_builds_loadout_from_ids() -> void:
	var previous := GameState.progress
	GameState.new_game()
	GameState.progress.loadout_weapon = &"reedbow"
	GameState.progress.loadout_familiar = &"cinder_pup"
	var loadout := GameState.build_loadout()
	assert_eq(loadout.weapon.id, &"reedbow")
	assert_eq(loadout.familiar.id, &"cinder_pup")
	assert_eq(loadout.companion.id, &"mara")
	assert_empty(loadout.validate())
	GameState.progress.loadout_weapon = &"does_not_exist"
	assert_eq(GameState.build_loadout().weapon.id, &"pilgrims_edge", "unknown ids fall back safely")
	GameState.progress = previous


func test_recorded_battles_are_saved_and_resumed_next_session() -> void:
	var previous_progress := GameState.progress
	var previous_slot := GameState.active_slot
	var previous_resumed: bool = GameState._session_resumed
	GameState.active_slot = 99 # Throwaway slot: never touches a player's save.
	GameState.new_game()
	var result := BattleResult.new()
	result.outcome = Enums.BattleOutcome.VICTORY
	result.research[&"thornhound"] = PackedInt32Array([Enums.ResearchSource.INSPECT])
	result.weapon_uses[&"pilgrims_edge"] = 3
	GameState.record_battle(result)
	assert_true(SaveManager.has_slot(99), "recording a battle saves the active slot")
	GameState.new_game()
	GameState._session_resumed = false
	assert_true(GameState.resume_session(), "the next session loads it")
	assert_gt(GameState.progress.bestiary.points.get(&"thornhound", 0), 0, "research survived the round trip")
	assert_eq(GameState.progress.weapon_mastery.get(&"pilgrims_edge", 0), 3, "mastery survived the round trip")
	assert_eq(GameState.progress.battles_won, 1)
	assert_false(GameState.resume_session(), "resumes only once per run")
	SaveManager.delete_slot(99)
	GameState.active_slot = previous_slot
	GameState.progress = previous_progress
	GameState._session_resumed = previous_resumed
