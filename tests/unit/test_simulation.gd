extends TestCase
## Simulator plumbing on fixture content: battles finish, metrics add up, profiles behave.


func _skill(mode: Enums.SimulatedExecution) -> ExecutionSkillProfile:
	var skill := ExecutionSkillProfile.new()
	skill.mode = mode
	skill.display_name = EnumText.simulated_execution(mode)
	match mode:
		Enums.SimulatedExecution.MISS:
			skill.miss_weight = 1.0
			skill.good_weight = 0.0
			skill.reacts = false
		Enums.SimulatedExecution.PERFECT:
			skill.good_weight = 0.0
			skill.perfect_weight = 1.0
			skill.brace_success = 1.0
			skill.evade_success = 0.98
			skill.parry_success = 0.9
	return skill


func _config(mode: Enums.SimulatedExecution, runs: int = 12) -> SimulationConfig:
	var config := SimulationConfig.new()
	config.label = "fixture"
	config.loadout = Fixtures.loadout(null, null, Fixtures.companion())
	var encounter := EncounterDefinition.new()
	encounter.id = &"fixture_fight"
	encounter.display_name = "Fixture fight"
	var biter := Fixtures.enemy(&"biter", 120, 5, 12, [Fixtures.enemy_attack(&"bite", 12.0)])
	var rare := Fixtures.enemy_attack(&"never", 1.0)
	rare.base_priority = 0.001
	var thumper := Fixtures.enemy(&"thumper", 140, 10, 6, [Fixtures.enemy_attack(&"thump", 16.0), rare])
	encounter.enemies = [biter, thumper]
	config.encounter = encounter
	config.library = Fixtures.library()
	config.difficulty = Fixtures.difficulty()
	config.assist = Fixtures.assist()
	config.skill = _skill(mode)
	config.runs = runs
	return config


func test_batch_runs_to_completion_with_consistent_metrics() -> void:
	var report := SimulationRunner.run_batch(_config(Enums.SimulatedExecution.GOOD))
	assert_eq(report.runs(), 12)
	for metrics in report.battles:
		assert_ne(metrics.outcome, Enums.BattleOutcome.NONE, "every battle ends")
		assert_gt(metrics.rounds, 0)
		assert_gt(metrics.action_usage.size(), 0)
		assert_gt(metrics.party_turns, 0)
	assert_gt(report.win_rate(), 0.5, "GOOD execution beats the fixture fight")
	assert_false(report.to_markdown().is_empty())


func test_better_execution_takes_less_damage() -> void:
	var miss := SimulationRunner.run_batch(_config(Enums.SimulatedExecution.MISS, 16))
	var perfect := SimulationRunner.run_batch(_config(Enums.SimulatedExecution.PERFECT, 16))
	assert_lt(perfect.mean_of("damage_taken"), miss.mean_of("damage_taken"))
	assert_lte(perfect.mean_of("rounds"), miss.mean_of("rounds"))
	assert_gt(perfect.mean_of("focus_generated"), miss.mean_of("focus_generated"))


func test_flags_detect_never_used_enemy_actions() -> void:
	var report := SimulationRunner.run_batch(_config(Enums.SimulatedExecution.GOOD, 6))
	assert_has(report.never_used(true), &"never")
	var found := false
	for smell in report.flags():
		if smell.begins_with("AI NEVER USED"):
			found = true
	assert_true(found)


func test_simulation_is_deterministic() -> void:
	var a := SimulationRunner.run_batch(_config(Enums.SimulatedExecution.MIXED, 5))
	var b := SimulationRunner.run_batch(_config(Enums.SimulatedExecution.MIXED, 5))
	for index in 5:
		assert_eq(a.battles[index].rounds, b.battles[index].rounds)
		assert_eq(a.battles[index].damage_taken, b.battles[index].damage_taken)


func test_policies_all_produce_legal_play() -> void:
	for policy in [PartyAutopilot.Policy.SMART, PartyAutopilot.Policy.BASIC_ONLY, PartyAutopilot.Policy.RANDOM]:
		var config := _config(Enums.SimulatedExecution.GOOD, 4)
		config.policy = policy
		var report := SimulationRunner.run_batch(config)
		for metrics in report.battles:
			assert_ne(metrics.outcome, Enums.BattleOutcome.NONE, "policy %d" % policy)


func test_reaction_choice_matches_skill() -> void:
	var balance := Fixtures.balance()
	var request := ReactionRequest.new()
	request.spec = ReactionSpec.new()
	request.spec.allowed = [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]
	request.spec.brace_window_ms = balance.brace_window_ms
	request.spec.evade_window_ms = balance.evade_window_ms
	request.spec.parry_window_ms = balance.parry_window_ms
	var expert := ExecutionSimulator.new(_skill(Enums.SimulatedExecution.PERFECT), 1)
	assert_eq(expert.react(balance, request).type, Enums.ReactionType.PARRY, "experts take the parry")
	var novice_skill := _skill(Enums.SimulatedExecution.GOOD)
	novice_skill.evade_success = 0.3
	novice_skill.parry_success = 0.1
	var novice := ExecutionSimulator.new(novice_skill, 1)
	assert_eq(novice.react(balance, request).type, Enums.ReactionType.BRACE, "novices take the safe Brace")
	request.spec.allowed = [Enums.ReactionType.BRACE]
	assert_eq(expert.react(balance, request).type, Enums.ReactionType.BRACE)
