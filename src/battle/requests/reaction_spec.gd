class_name ReactionSpec
extends RefCounted
## Final reaction parameters for one incoming enemy action (after modifiers and assist).

var allowed: Array[Enums.ReactionType] = []
var brace_window_ms: float = 500.0
var evade_window_ms: float = 280.0
var parry_window_ms: float = 150.0
## Time from the start of the wind-up to impact; reactions are graded against impact.
var windup_ms: float = 900.0
var auto_brace: bool = false
var pause_before: bool = false


func is_allowed(reaction: Enums.ReactionType) -> bool:
	return allowed.has(reaction)


func window_for(reaction: Enums.ReactionType) -> float:
	match reaction:
		Enums.ReactionType.BRACE:
			return brace_window_ms
		Enums.ReactionType.EVADE:
			return evade_window_ms
		Enums.ReactionType.PARRY:
			return parry_window_ms
	return 0.0
