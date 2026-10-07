class_name CommandRequest
extends BattleRequest
## ACTION_COMMAND: perform the action command for an already chosen action.
## Answer with BattleEngine.submit_command_result(grade).

var choice: ActionChoice
var spec: CommandSpec


func _init() -> void:
	kind = Kind.ACTION_COMMAND
