extends TestCase
## V0.5C through the production WorldSession and the real WorldHost, on the fixture world (the
## authored journey plus the proposed, not yet placed, exploration content): gathering yields once
## per save and survives Reset journey; the rune puzzle saves every strike, reveals the secret and
## survives reload; the secret's reward is claimed once; failed writes change nothing and a retry
## publishes once; the grammar's second fixture rewards on its own; optional content never blocks
## the main route; the host routes prompts, dialogue and strikes without discovering hidden secrets.

var kit: WorldKit
var world_def: WorldDefinition
var granted: Array[RewardReadout] = []
var tree: SceneTree
var host: WorldHost


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	world_def = ExplorationKit.world()
	granted.clear()
	EventBus.rewards_granted.connect(_on_reward)
	tree = Engine.get_main_loop() as SceneTree


func after_each() -> void:
	EventBus.rewards_granted.disconnect(_on_reward)
	for action in InputBindings.WORLD_ACTIONS + [InputBindings.CONFIRM, InputBindings.CANCEL]:
		Input.action_release(action)
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


func _on_reward(receipt: RewardReadout) -> void:
	granted.append(receipt)


func _session(rng_seed: int = 7) -> WorldSession:
	var session := ExplorationKit.session(kit, world_def, rng_seed)
	session.open()
	return session


static func _snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(GameState.progress.to_dict())), "", true)


func _reload() -> void:
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))


func _strikes(session: WorldSession, runes: Array) -> Array:
	var outcomes := []
	for rune: StringName in runes:
		var area := ExplorationKit.TOWN if String(rune).begins_with("gate_") else ExplorationKit.REEDWAY
		var err := session.strike_rune(area, rune)
		outcomes.append(ExplorationResult.Strike.keys()[session.last_exploration.strike] if err == OK else error_string(err))
	return outcomes


func test_gathering_yields_once_per_save_and_survives_reset() -> void:
	var session := _session()
	var reedway := ExplorationKit.REEDWAY
	assert_eq(session.gather(reedway, &"listening_stones"), ERR_INVALID_PARAMETER, "not a gathering node")
	assert_eq(session.last_exploration.reason, ExplorationResult.Reason.UNKNOWN_FEATURE)
	var before := _snapshot()
	kit.writer.fail = true
	assert_eq(session.gather(reedway, ExplorationKit.NODE), ERR_FILE_CANT_WRITE)
	assert_eq(session.last_exploration.reason, ExplorationResult.Reason.WRITE_FAILED)
	assert_eq(_snapshot(), before, "a failed write changes nothing")
	assert_true(granted.is_empty() and session.last_receipts.is_empty(), "and publishes nothing")
	kit.writer.fail = false
	assert_eq(session.gather(reedway, ExplorationKit.NODE), OK, "Retry repeats the exact interaction")
	assert_eq(granted.size(), 1, "published once")
	assert_eq(granted[0].summary(), "1 Bog Iron")
	var progress := GameState.progress
	assert_true(progress.world.is_gathered(ExplorationKit.NODE) and progress.has_claim(ExplorationKit.NODE_CLAIM))
	assert_eq(progress.material_count(&"bog_iron"), 1)
	assert_true(progress.world.is_discovered(ExplorationKit.NODE), "charted by the interaction")
	assert_true(session.last_exploration.rewarded)
	var writes := kit.writer.writes.size()
	assert_eq(session.gather(reedway, ExplorationKit.NODE), ERR_ALREADY_EXISTS)
	assert_eq(session.last_exploration.reason, ExplorationResult.Reason.ALREADY_DONE)
	assert_eq(kit.writer.writes.size(), writes, "no write")
	# Reload and Reset journey: the node stays gathered and never yields again.
	_reload()
	var reloaded := _session()
	assert_true(GameState.progress.world.is_gathered(ExplorationKit.NODE))
	assert_eq(reloaded.reconcile(), OK)
	assert_true(reloaded.last_receipts.is_empty(), "nothing to catch up")
	assert_eq(reloaded.reset_journey(), OK)
	assert_true(GameState.progress.world.is_gathered(ExplorationKit.NODE), "Reset journey keeps the node gathered")
	assert_true(GameState.progress.world.discovered.is_empty(), "while the rest of the journey resets")
	assert_eq(reloaded.gather(reedway, ExplorationKit.NODE), ERR_ALREADY_EXISTS)
	assert_eq(GameState.progress.material_count(&"bog_iron"), 1, "no Reset journey exploit")
	assert_eq(granted.size(), 1)
	# A pending encounter blocks field interactions.
	var other := ExplorationKit.world()
	var fresh_kit := kit
	GameState.new_game()
	var pending := ExplorationKit.session(fresh_kit, other)
	pending.open()
	assert_not_null(pending.begin_entry(&"reedway_patrol", &"reedway_patrol"))
	assert_eq(pending.gather(reedway, ExplorationKit.NODE), ERR_UNAVAILABLE)
	assert_eq(pending.last_exploration.reason, ExplorationResult.Reason.ENCOUNTER_PENDING)


func test_the_rune_puzzle_saves_each_strike_and_reveals_the_secret() -> void:
	var session := _session()
	var reedway := ExplorationKit.REEDWAY
	assert_eq(session.find_secret(reedway, ExplorationKit.SECRET), ERR_UNAVAILABLE, "the niche is hidden before the puzzle")
	assert_eq(session.last_exploration.reason, ExplorationResult.Reason.HIDDEN)
	assert_eq(_strikes(session, [ExplorationKit.LOW, ExplorationKit.MID]), ["ADVANCED", "MISTAKE"])
	assert_true(GameState.progress.world.rune_input.is_empty(), "a mistake clears the attempt")
	assert_eq(_strikes(session, [ExplorationKit.LOW, ExplorationKit.HIGH]), ["ADVANCED", "ADVANCED"])
	assert_eq(session.last_exploration.progress, 2)
	assert_eq(session.puzzle(ExplorationKit.PUZZLE).entered, 2)
	assert_eq(String(kit.writer.last().world.rune_input[String(ExplorationKit.PUZZLE)][1]), String(ExplorationKit.HIGH),
		"every strike is saved")
	# Reload mid-attempt: the attempt continues where it was.
	_reload()
	var resumed := _session()
	assert_eq(GameState.progress.world.rune_input_of(ExplorationKit.PUZZLE), [ExplorationKit.LOW, ExplorationKit.HIGH] as Array[StringName])
	# A failed final strike changes nothing; Retry solves once.
	var before := _snapshot()
	kit.writer.fail = true
	assert_eq(resumed.strike_rune(reedway, ExplorationKit.MID), ERR_FILE_CANT_WRITE)
	assert_eq(resumed.last_exploration.strike, ExplorationResult.Strike.NONE)
	assert_true(resumed.last_exploration.revealed.is_empty())
	assert_eq(_snapshot(), before)
	kit.writer.fail = false
	assert_eq(resumed.strike_rune(reedway, ExplorationKit.MID), OK)
	var solved := resumed.last_exploration
	assert_eq([solved.strike, solved.puzzle_id, solved.progress, solved.length], [ExplorationResult.Strike.SOLVED,
		ExplorationKit.PUZZLE, 0, 3])
	assert_eq(solved.revealed, [ExplorationKit.SECRET] as Array[StringName])
	assert_false(solved.rewarded, "the rhythm itself grants nothing; it reveals the niche")
	assert_true(GameState.progress.world.is_solved(ExplorationKit.PUZZLE))
	assert_true(GameState.progress.world.rune_input.is_empty())
	assert_eq(resumed.strike_rune(reedway, ExplorationKit.LOW), ERR_ALREADY_EXISTS, "a solved puzzle ignores strikes")
	# The revealed secret: found once, its reward claimed once.
	assert_eq(resumed.find_secret(reedway, ExplorationKit.SECRET), OK)
	assert_true(resumed.last_exploration.rewarded)
	assert_eq(granted.map(func(receipt: RewardReadout) -> String: return receipt.summary()), ["Fenrunner Leathers"])
	assert_true(GameState.progress.owned_equipment.has(&"fenrunner_leathers"))
	assert_eq(resumed.find_secret(reedway, ExplorationKit.SECRET), ERR_ALREADY_EXISTS)
	# Reset journey: the puzzle and the secret reset; their claims do not.
	assert_eq(resumed.reset_journey(), OK)
	var world := GameState.progress.world
	assert_false(world.is_solved(ExplorationKit.PUZZLE) or world.is_found(ExplorationKit.SECRET))
	assert_eq(resumed.find_secret(reedway, ExplorationKit.SECRET), ERR_UNAVAILABLE, "hidden again")
	assert_eq(_strikes(resumed, [ExplorationKit.LOW, ExplorationKit.HIGH, ExplorationKit.MID]), ["ADVANCED", "ADVANCED", "SOLVED"])
	assert_eq(resumed.find_secret(reedway, ExplorationKit.SECRET), OK, "found again")
	assert_false(resumed.last_exploration.rewarded, "but its reward stays claimed")
	assert_true(resumed.last_receipts.is_empty())
	assert_eq(granted.size(), 1)
	assert_eq(GameState.progress.owned_equipment.count(&"fenrunner_leathers"), 1)


func test_a_second_puzzle_reuses_the_grammar_and_rewards_once() -> void:
	var session := _session()
	assert_eq(_strikes(session, [ExplorationKit.CHIME_A, ExplorationKit.CHIME_A, ExplorationKit.CHIME_B, ExplorationKit.CHIME_A,
		ExplorationKit.CHIME_C]), ["ADVANCED", "MISTAKE", "ADVANCED", "ADVANCED", "SOLVED"])
	assert_true(session.last_exploration.rewarded)
	assert_eq(session.last_receipts[0].label, "Gate chimes")
	assert_eq(GameState.progress.material_count(&"storm_salt"), 1)
	assert_eq(session.puzzle(ExplorationKit.CHIMES).solved, true)
	assert_eq(session.puzzle(ExplorationKit.PUZZLE).solved, false, "puzzles keep separate state")
	assert_eq(session.strike_rune(ExplorationKit.TOWN, &"town_bell"), ERR_INVALID_PARAMETER, "not a rune")
	assert_eq(session.last_exploration.reason, ExplorationResult.Reason.UNKNOWN_FEATURE)
	assert_eq(session.reset_journey(), OK)
	assert_eq(_strikes(session, [ExplorationKit.CHIME_A, ExplorationKit.CHIME_B, ExplorationKit.CHIME_A, ExplorationKit.CHIME_C]),
		["ADVANCED", "ADVANCED", "ADVANCED", "SOLVED"])
	assert_false(session.last_exploration.rewarded, "solving again after a reset grants nothing")
	assert_eq(GameState.progress.material_count(&"storm_salt"), 1)


func test_older_saves_catch_up_and_optional_content_never_blocks_the_route() -> void:
	# An older (or hand-edited) save that recorded the accomplishments but not the claims.
	GameState.progress.world.gathered.append(ExplorationKit.NODE)
	GameState.progress.world.solved.append(ExplorationKit.CHIMES)
	var session := _session()
	assert_eq(session.reconcile(), OK)
	assert_eq(session.last_receipts.map(func(receipt: RewardReadout) -> StringName: return receipt.claim_id),
		[ExplorationKit.NODE_CLAIM, ExplorationKit.CHIMES_CLAIM])
	var writes := kit.writer.writes.size()
	assert_eq(session.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), writes, "caught up once")
	# The main route completes without touching any exploration content.
	GameState.new_game()
	var route := _session()
	for site in [&"bell_guard"]:
		var entry := route.begin_entry(site, site)
		assert_eq(route.commit_victory(entry, WorldKit.victory(site)), OK)
	assert_eq(route.restore_bell(ExplorationKit.REEDWAY), OK)
	assert_eq(route.open_latch(ExplorationKit.REEDWAY, &"short_return"), OK)
	assert_eq(WorldRules.objective(route.world(), world_def, world_def.start_area), WorldCopy.OBJECTIVE_DONE)
	var world := route.world()
	assert_true(world.gathered.is_empty() and world.found.is_empty() and world.solved.is_empty())
	# And the exploration content changes nothing on the route.
	assert_eq(_strikes(route, [ExplorationKit.LOW, ExplorationKit.HIGH, ExplorationKit.MID]), ["ADVANCED", "ADVANCED", "SOLVED"])
	assert_eq(WorldRules.objective(route.world(), world_def, world_def.start_area), WorldCopy.OBJECTIVE_DONE)
	assert_true(route.world().wayside_bell_restored and route.world().return_latch_open)


# --- Host routing ---------------------------------------------------------------------------------

func _start_host(area_id: StringName, anchor: StringName) -> void:
	GameState.progress.world.area = area_id
	GameState.progress.world.anchor = anchor
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = ExplorationKit.session(kit, world_def)
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame
	# The planning tiles are not placement (Codex's); let teleports ignore the painted collision.
	host.player.collision_mask = 0
	_place_markers()


## The fixture landmarks have no scene markers yet (placement is Codex's): add runtime points at
## their planning tiles so the real host can reach them.
func _place_markers() -> void:
	var interactions := host.area.get_node("Interactions")
	for landmark in host.area_def.landmarks:
		if host.area.has_point(landmark.id):
			continue
		var point := WorldPoint.new()
		point.name = String(landmark.id)
		point.position = (Vector2(landmark.tile) + Vector2(0.5, 0.5)) * world_def.tile_size
		interactions.add_child(point)


func _stand_at(landmark_id: StringName) -> void:
	host.player.place(host.area.point(landmark_id) + Vector2(0, 12))
	await tree.physics_frame
	host._discover()


func test_the_host_routes_gathering_strikes_and_hidden_secrets() -> void:
	await _start_host(ExplorationKit.REEDWAY, &"listening_stones")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	# A hidden secret: no prompt and no discovery while standing on it.
	await _stand_at(ExplorationKit.SECRET)
	assert_null(host.interaction_target())
	assert_false(GameState.progress.world.is_discovered(ExplorationKit.SECRET), "an imperceptible secret is never discovered")
	# Gathering through the node's dialogue and the reward card.
	await _stand_at(ExplorationKit.NODE)
	assert_eq(host.interaction_target().id, ExplorationKit.NODE)
	assert_eq(host.readout().interaction, "Gather from the iron seam")
	host.interact()
	assert_eq(host.modal.kind, &"dialogue")
	host.modal.chosen.emit(WorldRules.ACT_GATHER)
	assert_eq(host.modal.kind, &"reward", "a saved receipt is shown once")
	assert_eq(granted.size(), 1)
	host.modal.chosen.emit(&"continue")
	assert_null(host.interaction_target(), "a gathered node offers nothing more")
	# Rune strikes: direct, saved, announced through rune_struck.
	var struck: Array[ExplorationResult] = []
	host.rune_struck.connect(func(result: ExplorationResult) -> void: struck.append(result))
	for rune in [ExplorationKit.LOW, ExplorationKit.HIGH]:
		await _stand_at(rune)
		host.interact()
		assert_eq(host.mode, WorldHost.Mode.EXPLORE, "a strike opens no card")
	assert_eq(struck.map(func(result: ExplorationResult) -> int: return result.strike),
		[ExplorationResult.Strike.ADVANCED, ExplorationResult.Strike.ADVANCED])
	await _stand_at(ExplorationKit.MID)
	host.interact()
	assert_eq(struck.back().strike, ExplorationResult.Strike.SOLVED)
	assert_eq(host.modal.kind, &"dialogue", "solving shows a card")
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	# The secret is now perceivable, discoverable and searchable.
	await _stand_at(ExplorationKit.SECRET)
	assert_true(GameState.progress.world.is_discovered(ExplorationKit.SECRET))
	assert_eq(host.readout().interaction, "Search the drowned niche")
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_SEARCH)
	assert_eq(host.modal.kind, &"reward")
	assert_true(GameState.progress.owned_equipment.has(&"fenrunner_leathers"))
	host.modal.chosen.emit(&"continue")
	assert_eq(host.readout().interaction, "Look at the drowned niche")
	# A failed write on a strike shows the save-failure card and Retry applies it once.
	GameState.progress.world.solved.erase(ExplorationKit.PUZZLE)
	kit.writer.fail = true
	await _stand_at(ExplorationKit.LOW)
	host.interact()
	assert_eq(host.modal.kind, &"save_failed")
	assert_true(GameState.progress.world.rune_input.is_empty(), "nothing applied")
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(GameState.progress.world.rune_input_of(ExplorationKit.PUZZLE), [ExplorationKit.LOW] as Array[StringName])
