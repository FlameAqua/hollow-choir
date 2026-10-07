class_name ReactionResult
extends RefCounted
## The outcome of a reaction attempt. The first input locks the choice; NONE = no input.

var type: Enums.ReactionType = Enums.ReactionType.NONE
var success: bool = false
## Filled in by Execution Assist auto-Brace.
var automatic: bool = false


static func make(p_type: Enums.ReactionType, p_success: bool) -> ReactionResult:
	var result := ReactionResult.new()
	result.type = p_type
	result.success = p_success
	return result


static func none() -> ReactionResult:
	return ReactionResult.new()
