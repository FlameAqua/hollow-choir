class_name ActionSelectRequest
extends BattleRequest
## PLAYER_SELECT: choose one action (and target) for [member unit_uid].

var options: Array[ActionOption] = []


func _init() -> void:
	kind = Kind.ACTION_SELECT


func legal_options() -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	for option in options:
		if option.legal:
			result.append(option)
	return result
