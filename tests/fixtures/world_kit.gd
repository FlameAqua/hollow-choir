class_name WorldKit
extends RefCounted
## World test helpers: an in-memory save writer that can be told to fail, progress isolation and a
## deterministic battle fingerprint (every event field + input log + outcome).

class MemoryWriter:
	extends RefCounted
	var fail := false
	var writes: Array[Dictionary] = []

	func write(candidate: ProgressState) -> Error:
		if fail:
			return ERR_FILE_CANT_WRITE
		writes.append(candidate.to_dict())
		return OK

	func last() -> Dictionary:
		return writes.back() if not writes.is_empty() else {}


var writer := MemoryWriter.new()
var _progress: ProgressState
var _resumed: bool


## Isolates GameState for one test: fresh progress, no slot load. Call restore() afterwards.
func isolate() -> void:
	_progress = GameState.progress
	_resumed = GameState._session_resumed
	GameState._session_resumed = true
	GameState.new_game()


func restore() -> void:
	GameState.progress = _progress
	GameState._session_resumed = _resumed


func session(rng_seed: int = 7) -> WorldSession:
	return WorldSession.new(WorldDefinition.load_default(), writer.write, rng_seed)


static func site(site_id: StringName) -> LandmarkDefinition:
	return WorldDefinition.load_default().find_landmark(site_id)[1]


## A victory result for [param site_id]'s encounter with some research and practice.
static func victory(site_id: StringName) -> BattleResult:
	var result := BattleResult.new()
	result.outcome = Enums.BattleOutcome.VICTORY
	for enemy in site(site_id).encounter.enemies:
		result.research[enemy.id] = PackedInt32Array([Enums.ResearchSource.ENCOUNTER, Enums.ResearchSource.DEFEAT])
	result.weapon_uses[&"pilgrims_edge"] = 4
	result.weapon_perfects[&"pilgrims_edge"] = 1
	return result


## Plays [param setup] with the party autopilot and simulated execution and hashes everything.
static func fingerprint(setup: BattleSetup) -> String:
	var engine := BattleEngine.new(setup)
	var autopilot := PartyAutopilot.new(PartyAutopilot.Policy.SMART, setup.seed + 1)
	var executor := ExecutionSimulator.new(Database.registry.skill(Enums.SimulatedExecution.GOOD), setup.seed + 2)
	var parts := PackedStringArray()
	for guard in 5000:
		if engine.is_finished():
			break
		engine.advance()
		for event in engine.drain_events():
			parts.append(_event_text(event))
		var request := engine.get_request()
		if request == null:
			continue
		match request.kind:
			BattleRequest.Kind.ACTION_SELECT:
				engine.submit_action(autopilot.choose(engine, request as ActionSelectRequest))
			BattleRequest.Kind.ACTION_COMMAND:
				engine.submit_command_result(executor.grade_command((request as CommandRequest).spec, setup.assist))
			BattleRequest.Kind.REACTION:
				engine.submit_reaction(executor.react(setup.library.balance, request as ReactionRequest))
	for event in engine.drain_events():
		parts.append(_event_text(event))
	var result := engine.build_result()
	parts.append("%d|%d|%s" % [result.outcome, result.rounds, JSON.stringify(result.input_log)])
	return "|".join(parts).sha256_text()


static func _event_text(event: BattleEvent) -> String:
	return "%d,%d,%d,%d,%s,%.4f,%.4f,%d,%d,%d,%s,%d,%d,%s,%s,%s" % [event.type, event.round, event.subject, event.other,
		str(event.uids), event.amount, event.amount2, event.status, event.grade, event.reaction, event.success,
		event.damage_type, event.flags, event.action.id if event.action != null else "", event.text, event.text2]
