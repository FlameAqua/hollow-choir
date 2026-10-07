class_name BattleDriver
extends RefCounted
## Helpers for stepping a BattleEngine in tests: advance to the next request, answer it, and
## keep every event for assertions.

var engine: BattleEngine
var events: Array[BattleEvent] = []


func _init(setup: BattleSetup) -> void:
	engine = BattleEngine.new(setup)


## Advances until a request is pending or the battle ends. Returns the request (or null).
func next_request() -> BattleRequest:
	engine.advance()
	events.append_array(engine.drain_events())
	return engine.get_request()


## Advances to the next PLAYER_SELECT, answering enemy reactions with [param reaction].
func to_player_turn(reaction: ReactionResult = null) -> ActionSelectRequest:
	for i in 200:
		var request := next_request()
		if request == null:
			return null
		if request is ActionSelectRequest:
			return request
		if request is ReactionRequest:
			engine.submit_reaction(reaction if reaction != null else ReactionResult.none())
		elif request is CommandRequest:
			engine.submit_command_result(Enums.ExecutionGrade.GOOD)
	return null


## Chooses [param action] (found by id) for the pending unit, then answers its command.
func act(action_id: StringName, target_uid: int = -1, grade: Enums.ExecutionGrade = Enums.ExecutionGrade.GOOD) -> Error:
	var request := engine.get_request() as ActionSelectRequest
	if request == null:
		return ERR_UNAVAILABLE
	for option in request.options:
		if option.action.id == action_id:
			var target := target_uid
			if target < 0 and not option.target_uids.is_empty():
				target = option.target_uids[0]
			var err := engine.submit_action(ActionChoice.from_option(request.unit_uid, option, target))
			if err != OK:
				return err
			if engine.get_request() is CommandRequest:
				return engine.submit_command_result(grade)
			return OK
	return ERR_DOES_NOT_EXIST


func events_of(type: BattleEvent.Type) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event in events:
		if event.type == type:
			result.append(event)
	return result


func count_of(type: BattleEvent.Type) -> int:
	return events_of(type).size()


func enemy(index: int = 0) -> BattleUnit:
	return engine.get_state().enemies(false)[index]


func hero() -> BattleUnit:
	return engine.get_state().protagonist()
