class_name SimulationRunner
extends RefCounted
## Plays battles with no human input: the autopilot chooses actions and the execution simulator
## stands in for action commands and reactions.


static func run_battle(setup: BattleSetup, skill: ExecutionSkillProfile,
		policy: PartyAutopilot.Policy = PartyAutopilot.Policy.SMART) -> BattleMetrics:
	var engine := BattleEngine.new(setup)
	var autopilot := PartyAutopilot.new(policy, setup.seed + 1)
	var executor := ExecutionSimulator.new(skill, setup.seed + 2)
	var metrics := BattleMetrics.new()
	var guard := 0
	while not engine.is_finished():
		guard += 1
		if guard > 5000:
			push_error("SimulationRunner: battle did not finish")
			break
		engine.advance()
		metrics.consume(engine, engine.drain_events())
		var request := engine.get_request()
		if request == null:
			continue
		var err := _answer(engine, request, autopilot, executor, setup)
		if err != OK:
			push_error("SimulationRunner: could not answer %s (error %d)" % [BattleRequest.Kind.keys()[request.kind], err])
			break
	metrics.consume(engine, engine.drain_events())
	metrics.finalize(engine)
	return metrics


static func run_batch(config: SimulationConfig) -> SimulationReport:
	var report := SimulationReport.new(config)
	for index in config.runs:
		report.add(run_battle(config.make_setup(index), config.skill, config.policy))
	return report


static func _answer(engine: BattleEngine, request: BattleRequest, autopilot: PartyAutopilot,
		executor: ExecutionSimulator, setup: BattleSetup) -> Error:
	match request.kind:
		BattleRequest.Kind.ACTION_SELECT:
			var choice := autopilot.choose(engine, request as ActionSelectRequest)
			return engine.submit_action(choice) if choice != null else ERR_CANT_RESOLVE
		BattleRequest.Kind.ACTION_COMMAND:
			return engine.submit_command_result(executor.grade_command((request as CommandRequest).spec, setup.assist))
		BattleRequest.Kind.REACTION:
			return engine.submit_reaction(executor.react(setup.library.balance, request as ReactionRequest))
	return ERR_INVALID_DATA
