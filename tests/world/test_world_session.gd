extends TestCase
## V0.4 world state and save boundaries: old-slot compatibility, anchor recovery, one immutable
## entry saved before launch, exactly-once victory, failed writes publishing nothing, exact retry,
## quit-during-battle resume and the two independent flags.

var kit: WorldKit


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()


func after_each() -> void:
	kit.restore()


func test_definition_is_valid_and_registered() -> void:
	var definition := WorldDefinition.load_default()
	assert_empty(definition.validate())
	assert_not_null(Database.registry.world, "the registry loads data/world")
	assert_eq(definition.area(&"gloamstead").anchors().has(&"town_bell"), true)
	assert_eq(WorldKit.site(&"reedway_patrol").encounter, Database.registry.encounters[&"fen_patrol"], "existing encounter reused")
	assert_eq(WorldKit.site(&"bell_guard").encounter, Database.registry.encounters[&"rot_grove"])
	assert_true(WorldKit.site(&"reedway_patrol").optional)
	assert_false(WorldKit.site(&"bell_guard").optional)


func test_old_slot_without_world_section_keeps_progress_and_starts_at_square() -> void:
	var old := ProgressState.new()
	old.bestiary.add(&"thornhound", Enums.ResearchSource.INSPECT, 3)
	old.weapon_mastery[&"reedbow"] = 9
	old.loadout_weapon = &"reedbow"
	old.battles_won = 4
	var data := old.to_dict()
	data.erase("world")
	var envelope := {"save_version": 1, "game_version": "0.3.0", "data": data}
	GameState.progress = ProgressState.from_dict(SaveMigrator.migrate(envelope))
	kit.session().open()
	var world := GameState.progress.world
	assert_eq(world.area, &"gloamstead")
	assert_eq(world.anchor, &"town_bell")
	assert_empty(world.cleared)
	assert_false(world.wayside_bell_restored or world.return_latch_open)
	assert_eq(GameState.progress.weapon_mastery[&"reedbow"], 9, "mastery preserved")
	assert_eq(GameState.progress.loadout_weapon, &"reedbow", "loadout preserved")
	assert_eq(GameState.progress.battles_won, 4)
	assert_gt(GameState.progress.bestiary.points_for(&"thornhound"), 0, "research preserved")
	assert_eq(SaveMigrator.CURRENT_VERSION, 1, "the additive world section needs no version bump")


func test_invalid_anchor_recovers_to_square_and_keeps_valid_progress() -> void:
	GameState.progress.world = WorldState.from_dict({
		"area": "briarfen_reedway", "anchor": "behind_the_waterfall",
		"discovered": ["reedway_fork", "secret_grotto", "reedway_fork"], "links": ["entry_fork", "sky_bridge"],
		"cleared": ["reedway_patrol", "mirebell_cantor", "reed_gate"],
		"flags": {"return_latch_open": true, "wayside_bell_restored": "yes", "mirebell_defeated": true},
		"pending_entry": {"token": "x", "site": "bell_guard"},
	})
	var problems := kit.session().open()
	var world := GameState.progress.world
	assert_false(problems.is_empty())
	assert_eq([world.area, world.anchor], [&"gloamstead", &"town_bell"])
	assert_eq(world.discovered, [&"reedway_fork"] as Array[StringName], "unknown and duplicate ids dropped")
	assert_eq(world.links, [&"entry_fork"] as Array[StringName])
	assert_eq(world.cleared, [&"reedway_patrol"] as Array[StringName], "only approved encounter sites")
	assert_true(world.return_latch_open, "valid flag kept")
	assert_false(world.wayside_bell_restored, "a non-boolean value never becomes an unlock")
	assert_null(world.pending_entry, "an incomplete entry is dropped")


func test_entry_is_captured_once_and_saved_before_launch() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_not_null(entry)
	assert_eq(kit.writer.writes.size(), 1, "written before any battle starts")
	var saved: Dictionary = kit.writer.last().world
	assert_eq(String(saved.pending_entry.token), entry.token())
	assert_eq(String(saved.anchor), "reedway_patrol", "resume point is the approach")
	assert_eq(String(saved.area), "briarfen_reedway")
	assert_null(session.begin_entry(&"reedway_patrol", &"reedway_patrol"), "a second entry cannot be taken")
	assert_null(session.begin_entry(&"bell_guard", &"bell_guard"), "nor another site while one is pending")
	assert_eq(kit.writer.writes.size(), 1)


func test_failed_entry_write_launches_nothing() -> void:
	var session := kit.session()
	session.open()
	kit.writer.fail = true
	assert_null(session.begin_entry(&"bell_guard", &"bell_guard"))
	assert_eq(session.last_error, ERR_FILE_CANT_WRITE)
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(GameState.progress.world.entry_serial, 0)


func test_victory_commits_exactly_once() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	var result := WorldKit.victory(&"reedway_patrol")
	var gained := []
	var on_gain := func(enemy_id: StringName, _level: int) -> void: gained.append(enemy_id)
	EventBus.research_level_gained.connect(on_gain)
	assert_eq(session.commit_victory(entry, result), OK)
	var world := GameState.progress.world
	assert_true(world.is_cleared(&"reedway_patrol"))
	assert_null(world.pending_entry)
	assert_eq(world.last_applied_token, entry.token())
	assert_eq(GameState.progress.battles_won, 1)
	assert_eq(GameState.progress.weapon_mastery[&"pilgrims_edge"], 5)
	var points := GameState.progress.bestiary.points_for(&"thornhound")
	var writes := kit.writer.writes.size()
	assert_eq(session.commit_victory(entry, result), ERR_ALREADY_EXISTS, "duplicate token is a no-op")
	assert_eq(GameState.progress.battles_won, 1)
	assert_eq(GameState.progress.weapon_mastery[&"pilgrims_edge"], 5)
	assert_eq(GameState.progress.bestiary.points_for(&"thornhound"), points)
	assert_eq(kit.writer.writes.size(), writes, "nothing written for the duplicate")
	assert_false(gained.is_empty(), "levels announced once, after the write")
	EventBus.research_level_gained.disconnect(on_gain)


func test_failed_victory_write_publishes_nothing_then_retry_commits() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	var gained := []
	var on_gain := func(enemy_id: StringName, _level: int) -> void: gained.append(enemy_id)
	EventBus.research_level_gained.connect(on_gain)
	kit.writer.fail = true
	assert_eq(session.commit_victory(entry, WorldKit.victory(&"bell_guard")), ERR_FILE_CANT_WRITE)
	var world := GameState.progress.world
	assert_false(world.is_cleared(&"bell_guard"), "no clear published")
	assert_eq(GameState.progress.battles_won, 0)
	assert_true(GameState.progress.weapon_mastery.is_empty(), "no practice published")
	assert_eq(GameState.progress.bestiary.points_for(&"rotcap_brute"), 0, "no research published")
	assert_not_null(world.pending_entry, "the result stays pending")
	assert_true(gained.is_empty(), "nothing announced")
	assert_false(WorldRules.can_ring_bell(world), "the bell is not unlocked by an unsaved win")
	kit.writer.fail = false
	assert_eq(session.commit_victory(entry, WorldKit.victory(&"bell_guard")), OK)
	assert_true(GameState.progress.world.is_cleared(&"bell_guard"))
	assert_eq(GameState.progress.battles_won, 1)
	EventBus.research_level_gained.disconnect(on_gain)


func test_retry_rebuilds_the_exact_captured_setup() -> void:
	Settings.data.tactical_difficulty = Enums.TacticalDifficulty.ADVENTURER
	var session := kit.session()
	session.open()
	GameState.progress.loadout_weapon = &"mire_maul"
	GameState.progress.bestiary.add(&"thornhound", Enums.ResearchSource.INSPECT, 2)
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	var first := entry.build_setup(Database.registry, Database.library)
	# Later changes to the live loadout, knowledge and settings must not leak into a retry.
	GameState.progress.loadout_weapon = &"reedbow"
	GameState.progress.bestiary.add(&"bogshell", Enums.ResearchSource.INSPECT, 50)
	var previous_difficulty := Settings.data.tactical_difficulty
	Settings.data.tactical_difficulty = Enums.TacticalDifficulty.TACTICIAN
	var retry := EncounterEntry.from_dict(entry.to_dict()).build_setup(Database.registry, Database.library)
	Settings.data.tactical_difficulty = previous_difficulty
	assert_eq(retry.seed, first.seed, "no fresh seed")
	assert_eq(retry.loadout.weapon.id, &"mire_maul")
	assert_eq(retry.research_levels, first.research_levels)
	assert_eq(retry.difficulty, first.difficulty)
	assert_eq(retry.assist.auto_brace, first.assist.auto_brace)
	assert_eq(WorldKit.fingerprint(retry), WorldKit.fingerprint(first), "identical battle")


func test_world_entry_matches_a_direct_setup_fingerprint() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	var from_entry := entry.build_setup(Database.registry, Database.library)
	var direct := BattleSetup.from_encounter(GameState.build_loadout(), Database.registry.encounters[&"rot_grove"],
		Database.library, Settings.difficulty_profile(), Settings.assist_profile(), entry.battle_seed())
	direct.research_levels = GameState.research_levels()
	assert_eq(WorldKit.fingerprint(from_entry), WorldKit.fingerprint(direct), "the world host adds no combat input")
	assert_eq(from_entry.conditions, direct.conditions, "authored conditions unchanged")
	assert_eq(from_entry.advantage, Enums.Advantage.NONE, "no approach bonus")


func test_quitting_during_battle_resumes_at_the_approach_without_award() -> void:
	var session := kit.session()
	session.open()
	session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	# The app closes mid-battle: next run loads exactly what was written before launch.
	GameState.progress = ProgressState.from_dict(kit.writer.last())
	kit.session().open()
	var world := GameState.progress.world
	assert_null(world.pending_entry)
	assert_eq([world.area, world.anchor], [&"briarfen_reedway", &"reedway_patrol"])
	assert_false(world.is_cleared(&"reedway_patrol"), "encounter still available")
	assert_eq(GameState.progress.battles_won + GameState.progress.battles_lost, 0, "no attempt recorded")


func test_leave_and_defeat_return_close_the_entry_without_gains() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(session.leave_entry(entry), OK)
	assert_eq(GameState.progress.world.anchor, &"reedway_patrol")
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(session.leave_entry(entry), ERR_INVALID_PARAMETER, "an entry closes once")
	GameState.progress.world.discover(&"listening_stones")
	session.open_latch(&"briarfen_reedway", &"short_return")
	var second := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_ne(second.token(), entry.token(), "each attempt has its own token")
	assert_eq(session.return_home(second), OK)
	var world := GameState.progress.world
	assert_eq([world.area, world.anchor], [&"gloamstead", &"town_bell"])
	assert_true(world.return_latch_open, "shortcut kept")
	assert_true(world.is_discovered(&"listening_stones"), "discoveries kept")
	assert_true(GameState.progress.weapon_mastery.is_empty(), "defeat records no practice")


func test_latch_and_bell_flags_are_independent() -> void:
	var session := kit.session()
	session.open()
	assert_eq(session.restore_bell(&"briarfen_reedway"), ERR_UNAVAILABLE, "guard victory is required")
	assert_eq(session.open_latch(&"briarfen_reedway", &"short_return"), OK)
	var world := GameState.progress.world
	assert_true(world.return_latch_open)
	assert_false(world.wayside_bell_restored, "the latch never sets the bell")
	assert_true(world.links.has(&"short_return"), "the map link updates immediately")
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	session.commit_victory(entry, WorldKit.victory(&"bell_guard"))
	assert_false(GameState.progress.world.wayside_bell_restored, "victory permits; ringing is separate")
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_eq(session.restore_bell(&"briarfen_reedway"), ERR_UNAVAILABLE, "stored once")
	var reloaded := ProgressState.from_dict(kit.writer.last()).world
	assert_true(reloaded.wayside_bell_restored and reloaded.return_latch_open)
	assert_true(reloaded.is_cleared(&"bell_guard"), "clear flags survive reload")


func test_errand_completes_before_any_dialogue() -> void:
	var session := kit.session()
	session.open()
	var world := GameState.progress.world
	assert_false(world.is_discovered(&"bellkeeper"))
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	session.commit_victory(entry, WorldKit.victory(&"bell_guard"))
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	world = GameState.progress.world
	var definition := WorldDefinition.load_default()
	assert_eq(WorldRules.objective(world, definition, &"briarfen_reedway"), WorldCopy.OBJECTIVE_RETURN)
	assert_eq(WorldRules.objective(world, definition, &"gloamstead"), WorldCopy.OBJECTIVE_DONE)
	var keeper := definition.area(&"gloamstead").landmark(&"bellkeeper")
	var dialogue := WorldRules.dialogue(keeper, world, false)
	assert_eq(Array(dialogue.paragraphs), WorldCopy.BELLKEEPER_AFTER, "dialogue derives from the flag")
	assert_eq(session.complete_interaction(&"gloamstead", &"bellkeeper"), OK)
	assert_true(GameState.progress.world.wayside_bell_restored, "talking cannot reset the bell")


func test_bench_offers_only_owned_starter_weapons() -> void:
	var session := kit.session()
	session.open()
	var ids := WorldRules.bench_weapons(GameState.progress).map(func(weapon: WeaponDefinition) -> StringName: return weapon.id)
	assert_eq(ids, [&"pilgrims_edge", &"mire_maul", &"reedbow"])
	assert_eq(session.choose_weapon(&"reedbow"), OK)
	assert_eq(GameState.progress.loadout_weapon, &"reedbow")
	assert_eq(session.choose_weapon(&"thunderhead"), ERR_INVALID_PARAMETER, "no unowned or new weapons")
	GameState.progress.owned_equipment.erase(&"mire_maul")
	assert_false(WorldRules.bench_weapons(GameState.progress).any(func(weapon: WeaponDefinition) -> bool: return weapon.id == &"mire_maul"))


func test_world_section_round_trips_through_a_real_save_file() -> void:
	var session := WorldSession.new(WorldDefinition.load_default(), func(candidate: ProgressState) -> Error:
		return SaveManager.write_progress(98, candidate), 3)
	session.open()
	session.open_latch(&"briarfen_reedway", &"short_return")
	session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	var envelope := SaveManager.read_json(SaveManager.slot_path(98))
	var restored := ProgressState.from_dict(SaveMigrator.migrate(envelope))
	assert_eq(restored.world.to_dict(), GameState.progress.world.to_dict())
	assert_not_null(restored.world.pending_entry)
	assert_eq(restored.world.pending_entry.to_dict(), GameState.progress.world.pending_entry.to_dict())
	SaveManager.delete_slot(98)
