class_name BattleReplay
extends RefCounted
## Re-runs a battle from its setup and the input log recorded by BattleEngine. Because the engine
## is deterministic this reproduces any reported battle exactly (GDD "Bug reproduction").
## Input logs are plain dictionaries so they survive JSON round-trips (numbers may become floats).


static func replay(setup: BattleSetup, inputs: Array[Dictionary]) -> BattleEngine:
	var engine := BattleEngine.new(setup)
	var index := 0
	while not engine.is_finished():
		engine.advance()
		engine.drain_events()
		var request := engine.get_request()
		if request == null or index >= inputs.size():
			break
		var input := inputs[index]
		index += 1
		var err := _apply(engine, request, input)
		if err != OK:
			push_warning("BattleReplay: input %d (%s) could not be applied" % [index - 1, str(input)])
			break
	return engine


static func _apply(engine: BattleEngine, request: BattleRequest, input: Dictionary) -> Error:
	match String(input.get("kind", "")):
		"action":
			var select := request as ActionSelectRequest
			if select == null:
				return ERR_INVALID_DATA
			var action_id := StringName(input.get("action", ""))
			var slot := int(input.get("slot", -1))
			for option in select.options:
				if option.action.id == action_id and option.item_slot == slot:
					return engine.submit_action(ActionChoice.from_option(select.unit_uid, option, int(input.get("target", -1))))
			return ERR_DOES_NOT_EXIST
		"command":
			return engine.submit_command_result(int(input.get("grade", 1)) as Enums.ExecutionGrade)
		"reaction":
			return engine.submit_reaction(ReactionResult.make(int(input.get("type", 0)) as Enums.ReactionType,
				bool(input.get("success", false))))
	return ERR_INVALID_DATA
