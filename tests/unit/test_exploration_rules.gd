extends TestCase
## V0.5C exploration vocabulary as pure rules: definition checks, the rune-sequence grammar on two
## different puzzles (reuse), reveal and perception rules, public readouts that never carry the
## solution, typed world-state parsing and sanitizing, reward sources and catch-up, and the world
## prompts, dialogue, map and scene-view sources for the new landmark kinds.

var world_def: WorldDefinition


func before_each() -> void:
	world_def = ExplorationKit.world()


static func _ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(values)
	return result


func test_the_fixture_world_validates_and_broken_definitions_are_reported() -> void:
	assert_empty(world_def.validate(), "fixture world and its exploration content validate")
	assert_empty(WorldDefinition.load_default().validate(), "the authored world is unchanged and valid")
	assert_empty(RewardRules.validate_catalog(ExplorationKit.registry(world_def)), "fixture rewards name real sources")
	var broken := ExplorationKit.world()
	var stray := GatheringDefinition.new()
	stray.landmark = ExplorationKit.LOW # A rune, not a gathering node.
	broken.gathering.append(stray)
	var twice := GatheringDefinition.new()
	twice.landmark = ExplorationKit.NODE
	broken.gathering.append(twice)
	var lost := SecretDefinition.new()
	lost.landmark = ExplorationKit.SECRET
	lost.reveal = SecretDefinition.Reveal.PUZZLE_SOLVED
	lost.reveal_key = &"no_such_puzzle"
	broken.secrets.append(lost)
	var flagless := SecretDefinition.new()
	flagless.landmark = &"wayside_bell"
	flagless.reveal = SecretDefinition.Reveal.WORLD_FLAG
	flagless.reveal_key = &"no_flag"
	broken.secrets.append(flagless)
	broken.puzzles.append(ExplorationKit.puzzle(&"split", "Split", [ExplorationKit.MID, ExplorationKit.CHIME_A], [ExplorationKit.MID, ExplorationKit.HIGH]))
	broken.puzzles.append(ExplorationKit.puzzle(&"short", "", [ExplorationKit.CHIME_B], [ExplorationKit.CHIME_B]))
	broken.area(ExplorationKit.REEDWAY).landmarks.append(ExplorationKit.landmark(&"orphan_stone", "Orphan", LandmarkDefinition.Kind.RUNE,
		Vector2i(1, 1), "x"))
	var text := "\n".join(broken.validate())
	for expected in ["gathering node rhythm_stone_low is not a GATHERING landmark", "landmark rhythm_stone_low has two",
		"landmark iron_seam has two exploration definitions", "reveal puzzle no_such_puzzle does not exist",
		"secret wayside_bell is not a SECRET landmark", "reveal flag no_flag does not exist",
		"puzzle split has runes in two areas", "solution rune rhythm_stone_high is not one of its runes",
		"puzzle 'short' needs an id and a public name", "puzzle short needs at least two runes",
		"puzzle short: the solution must take 2-8 strikes", "briarfen_reedway/orphan_stone has no exploration definition"]:
		assert_true(text.contains(expected), "reports: %s" % expected)
	# A reward naming a source that is not an exploration feature is reported.
	var registry := ExplorationKit.registry(world_def)
	var bad: RewardDefinition = registry.rewards[ExplorationKit.NODE_CLAIM].duplicate()
	bad.id = &"fixture.bad"
	bad.source_id = ExplorationKit.LOW
	registry.rewards[bad.id] = bad
	assert_true("\n".join(RewardRules.validate_catalog(registry)).contains("source rhythm_stone_low is not a gathering node"))


func test_the_rune_grammar_is_deterministic_and_reusable() -> void:
	var rhythm := ExplorationRules.puzzle(world_def, ExplorationKit.PUZZLE)
	var chimes := ExplorationRules.puzzle(world_def, ExplorationKit.CHIMES)
	var cases := [
		# [puzzle, strikes, expected outcomes, input after]
		[rhythm, [ExplorationKit.LOW, ExplorationKit.HIGH, ExplorationKit.MID], ["ADVANCED", "ADVANCED", "SOLVED"], []],
		[rhythm, [ExplorationKit.LOW, ExplorationKit.MID], ["ADVANCED", "MISTAKE"], []],
		[rhythm, [ExplorationKit.HIGH], ["MISTAKE"], []],
		[rhythm, [ExplorationKit.LOW, ExplorationKit.HIGH, ExplorationKit.LOW], ["ADVANCED", "ADVANCED", "MISTAKE"], [ExplorationKit.LOW]],
		[rhythm, [ExplorationKit.LOW, ExplorationKit.LOW, ExplorationKit.HIGH, ExplorationKit.MID], ["ADVANCED", "MISTAKE", "ADVANCED", "SOLVED"], []],
		[chimes, [ExplorationKit.CHIME_A, ExplorationKit.CHIME_B, ExplorationKit.CHIME_A, ExplorationKit.CHIME_C], ["ADVANCED", "ADVANCED", "ADVANCED", "SOLVED"], []],
		[chimes, [ExplorationKit.CHIME_A, ExplorationKit.CHIME_A], ["ADVANCED", "MISTAKE"], [ExplorationKit.CHIME_A]],
		[chimes, [ExplorationKit.CHIME_A, ExplorationKit.CHIME_B, ExplorationKit.CHIME_C], ["ADVANCED", "ADVANCED", "MISTAKE"], []],
		[chimes, [ExplorationKit.CHIME_B, ExplorationKit.CHIME_A, ExplorationKit.CHIME_B, ExplorationKit.CHIME_A, ExplorationKit.CHIME_C], ["MISTAKE", "ADVANCED", "ADVANCED", "ADVANCED", "SOLVED"], []],
	]
	for case: Array in cases:
		var entry: RuneSequenceDefinition = case[0]
		var input: Array[StringName] = []
		var outcomes := []
		for rune: StringName in case[1]:
			var before := input.duplicate()
			var step := ExplorationRules.strike(entry, input, rune)
			assert_eq(input, before, "the input passed in is never mutated")
			outcomes.append(ExplorationResult.Strike.keys()[step.outcome])
			input = step.input
		assert_eq(outcomes, case[2], "%s %s" % [entry.id, case[1]])
		assert_eq(input, _ids(case[3]))
	# The same strikes always give the same outcome (no randomness, no clock).
	var first := ExplorationRules.strike(rhythm, _ids([ExplorationKit.LOW]), ExplorationKit.HIGH)
	var second := ExplorationRules.strike(rhythm, _ids([ExplorationKit.LOW]), ExplorationKit.HIGH)
	assert_eq([first.outcome, first.input], [second.outcome, second.input])
	# Corrupt over-long input restarts instead of failing.
	assert_eq(ExplorationRules.strike(rhythm, _ids([ExplorationKit.LOW, ExplorationKit.HIGH, ExplorationKit.MID]), ExplorationKit.LOW).outcome, ExplorationResult.Strike.ADVANCED)


func test_reveal_perception_and_readouts_never_leak_the_solution() -> void:
	var world := WorldState.fresh(world_def)
	var secret := ExplorationRules.secret(world_def, ExplorationKit.SECRET)
	var niche: LandmarkDefinition = world_def.find_landmark(ExplorationKit.SECRET)[1]
	assert_false(ExplorationRules.revealed(world, secret))
	assert_false(ExplorationRules.perceivable(world, world_def, niche))
	assert_true(ExplorationRules.perceivable(world, world_def, world_def.find_landmark(ExplorationKit.LOW)[1]), "runes are always perceivable")
	assert_eq(ExplorationRules.secrets_revealed_by(world_def, ExplorationKit.PUZZLE), _ids([ExplorationKit.SECRET]))
	world.solved.append(ExplorationKit.PUZZLE)
	assert_true(ExplorationRules.revealed(world, secret))
	assert_true(ExplorationRules.perceivable(world, world_def, niche))
	var always := SecretDefinition.new()
	assert_true(ExplorationRules.revealed(WorldState.new(), always))
	var flagged := SecretDefinition.new()
	flagged.reveal = SecretDefinition.Reveal.WORLD_FLAG
	flagged.reveal_key = WorldDefinition.FLAG_BELL
	assert_false(ExplorationRules.revealed(WorldState.new(), flagged))
	var bell := WorldState.new()
	bell.wayside_bell_restored = true
	assert_true(ExplorationRules.revealed(bell, flagged))
	# Readouts: lit runes and progress, never the order.
	var attempt := WorldState.fresh(world_def)
	attempt.rune_input[ExplorationKit.PUZZLE] = [ExplorationKit.LOW, ExplorationKit.HIGH]
	var readout := ExplorationRules.readout(attempt, world_def, ExplorationRules.puzzle(world_def, ExplorationKit.PUZZLE))
	assert_eq([readout.id, readout.name, readout.solved, readout.entered, readout.length], [ExplorationKit.PUZZLE, "Listening stones", false, 2, 3])
	assert_eq(readout.runes.map(func(entry: Dictionary) -> Array: return [entry.id, entry.label, entry.lit]),
		[[ExplorationKit.LOW, "Low stone", true], [ExplorationKit.MID, "Middle stone", false], [ExplorationKit.HIGH, "High stone", true]], "authored rune order")
	assert_false("solution" in readout, "no solution field")
	attempt.solved.append(ExplorationKit.PUZZLE)
	attempt.rune_input.clear()
	assert_true(ExplorationRules.readout(attempt, world_def, ExplorationRules.puzzle(world_def, ExplorationKit.PUZZLE)).runes.all(
		func(entry: Dictionary) -> bool: return entry.lit), "every rune lit once solved")


func test_exploration_state_round_trips_and_is_sanitized() -> void:
	var world := WorldState.fresh(world_def)
	world.gathered.append(ExplorationKit.NODE)
	world.found.append(ExplorationKit.SECRET)
	world.solved.append(ExplorationKit.CHIMES)
	world.rune_input[ExplorationKit.PUZZLE] = [ExplorationKit.LOW]
	var data := world.to_dict()
	assert_eq([data.gathered, data.found, data.solved, data.rune_input],
		[["iron_seam"], ["drowned_niche"], ["gate_chimes"], {"listening_rhythm": ["rhythm_stone_low"]}])
	var back := WorldState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_empty(back.sanitize(world_def))
	assert_eq([back.gathered, back.found, back.solved, back.rune_input_of(ExplorationKit.PUZZLE)],
		[_ids([ExplorationKit.NODE]), _ids([ExplorationKit.SECRET]), _ids([ExplorationKit.CHIMES]), _ids([ExplorationKit.LOW])])
	assert_true(back.is_rune_lit(ExplorationKit.LOW) and not back.is_rune_lit(ExplorationKit.HIGH))
	# Untrusted data: wrong types dropped, unknown ids dropped, invalid input dropped.
	var odd := WorldState.from_dict({"gathered": "iron_seam", "found": [7, "drowned_niche", "nowhere"],
		"solved": ["gate_chimes", "no_puzzle"], "rune_input": {"listening_rhythm": [ExplorationKit.LOW, ExplorationKit.HIGH, ExplorationKit.MID],
		"gate_chimes": [ExplorationKit.CHIME_A], "no_puzzle": [ExplorationKit.LOW], "bad": "x"}})
	var problems := odd.sanitize(world_def)
	assert_empty(odd.gathered, "a string is not a list")
	assert_eq(odd.found, _ids([ExplorationKit.SECRET]))
	assert_eq(odd.solved, _ids([ExplorationKit.CHIMES]))
	assert_true(odd.rune_input.is_empty(), "a full-length, solved or unknown puzzle's input is dropped")
	assert_gte(problems.size(), 4)
	var foreign := WorldState.from_dict({"rune_input": {"listening_rhythm": [ExplorationKit.CHIME_A]}})
	foreign.sanitize(world_def)
	assert_true(foreign.rune_input.is_empty(), "another puzzle's rune is not valid input")
	# Production keeps placed features, but drops the second, test-only puzzle.
	var authored := WorldState.from_dict(data)
	authored.sanitize(WorldDefinition.load_default())
	assert_eq(authored.gathered, _ids([ExplorationKit.NODE]))
	assert_eq(authored.found, _ids([ExplorationKit.SECRET]))
	assert_empty(authored.solved, "Gate chimes remains test-only")
	assert_eq(authored.rune_input_of(ExplorationKit.PUZZLE), _ids([ExplorationKit.LOW]))
	# Older saves have no exploration keys.
	var older := WorldState.fresh(world_def).to_dict()
	for key in ["gathered", "found", "solved", "rune_input"]:
		older.erase(key)
	var parsed := WorldState.from_dict(older)
	assert_true(parsed.gathered.is_empty() and parsed.rune_input.is_empty())


func test_exploration_accomplishments_drive_rewards_and_catch_up() -> void:
	var registry := ExplorationKit.registry(world_def)
	var progress := ProgressState.new()
	progress.world = WorldState.fresh(world_def)
	assert_empty(RewardRules.catch_up(progress, registry), "nothing accomplished")
	progress.world.gathered.append(ExplorationKit.NODE)
	progress.world.found.append(ExplorationKit.SECRET)
	progress.world.solved.append(ExplorationKit.CHIMES)
	progress.world.discovered.append(ExplorationKit.LOW)
	var due := RewardRules.catch_up(progress, registry).map(func(reward: RewardDefinition) -> StringName: return reward.id)
	assert_eq(due, [ExplorationKit.SECRET_CLAIM, ExplorationKit.NODE_CLAIM, ExplorationKit.CHIMES_CLAIM],
		"gathered, found and solved prove their rewards (claim-id order)")
	var receipts := RewardRules.grant(progress, RewardRules.catch_up(progress, registry))
	assert_eq(receipts.size(), 3)
	assert_eq([progress.material_count(&"bog_iron"), progress.material_count(&"storm_salt")], [1, 1])
	assert_true(progress.owned_equipment.has(&"fenrunner_leathers"))
	assert_empty(RewardRules.catch_up(progress, registry), "claimed once")
	var previews := RewardRules.previews(progress, registry, RewardDefinition.Source.GATHERED, ExplorationKit.NODE)
	assert_eq(previews[0].status, RewardReadout.Status.CLAIMED)


func test_prompts_dialogue_map_and_scene_views_follow_typed_state() -> void:
	var world := WorldState.fresh(world_def)
	var node: LandmarkDefinition = world_def.find_landmark(ExplorationKit.NODE)[1]
	var niche: LandmarkDefinition = world_def.find_landmark(ExplorationKit.SECRET)[1]
	var low: LandmarkDefinition = world_def.find_landmark(ExplorationKit.LOW)[1]
	assert_eq(WorldRules.interaction_label(node, world, false, world_def), "Gather from the iron seam")
	var gather := WorldRules.dialogue(node, world, false, world_def)
	assert_eq(gather.actions.map(func(action: Dictionary) -> StringName: return action.id), [WorldRules.ACT_GATHER, WorldRules.ACT_LEAVE])
	assert_eq(WorldRules.interaction_label(niche, world, false, world_def), "", "an unrevealed secret offers nothing")
	assert_null(WorldRules.dialogue(niche, world, false, world_def))
	assert_false(WorldRules.perceivable(niche, world, world_def))
	assert_eq(WorldRules.interaction_label(low, world, false, world_def), "Strike the low stone")
	assert_null(WorldRules.dialogue(low, world, false, world_def), "runes are struck directly")
	world.solved.append(ExplorationKit.PUZZLE)
	world.gathered.append(ExplorationKit.NODE)
	assert_eq(WorldRules.interaction_label(node, world, false, world_def), "", "a gathered node offers nothing")
	assert_eq(Array(WorldRules.dialogue(node, world, false, world_def).paragraphs), [WorldCopy.GATHERED_TEXT])
	assert_eq(WorldRules.interaction_label(low, world, false, world_def), "", "a solved puzzle's runes are quiet")
	assert_eq(WorldRules.interaction_label(niche, world, false, world_def), "Search the drowned niche")
	assert_eq(WorldRules.dialogue(niche, world, false, world_def).actions[0].id, WorldRules.ACT_SEARCH)
	world.found.append(ExplorationKit.SECRET)
	assert_eq(WorldRules.interaction_label(niche, world, false, world_def), "Look at the drowned niche")
	# The map never charts an imperceptible secret, even when an earlier journey discovered it.
	var area := world_def.area(ExplorationKit.REEDWAY)
	var hidden := WorldState.fresh(world_def)
	hidden.discovered.append_array([ExplorationKit.SECRET, ExplorationKit.NODE])
	var labels := WorldRules.map_readout(area, hidden, 32, Vector2.ZERO, {}, world_def).landmarks.map(
		func(entry: Dictionary) -> String: return entry.label)
	assert_true(labels.has("Iron seam") and not labels.has("Drowned niche"))
	hidden.solved.append(ExplorationKit.PUZZLE)
	hidden.gathered.append(ExplorationKit.NODE)
	var charted := WorldRules.map_readout(area, hidden, 32, Vector2.ZERO, {}, world_def).landmarks
	assert_true(charted.any(func(entry: Dictionary) -> bool: return entry.label == "Drowned niche"))
	assert_true(charted.any(func(entry: Dictionary) -> bool: return entry.description == WorldCopy.GATHERED_TEXT))
	# Scene views read the same typed state.
	var view := WorldStateView.new()
	var lit := WorldState.fresh(world_def)
	lit.rune_input[ExplorationKit.PUZZLE] = [ExplorationKit.LOW]
	for case: Array in [[WorldStateView.Source.RUNE_LIT, ExplorationKit.LOW, true], [WorldStateView.Source.RUNE_LIT, ExplorationKit.MID, false],
			[WorldStateView.Source.SOLVED, ExplorationKit.PUZZLE, false], [WorldStateView.Source.GATHERED, ExplorationKit.NODE, false],
			[WorldStateView.Source.FOUND, ExplorationKit.SECRET, false]]:
		view.source = case[0]
		view.key = case[1]
		assert_eq(view.matches(lit), case[2], "%s %s" % [WorldStateView.Source.keys()[case[0]], case[1]])
	view.source = WorldStateView.Source.SOLVED
	view.key = ExplorationKit.PUZZLE
	assert_true(view.matches(world))
	view.free()
