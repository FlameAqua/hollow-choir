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
## Playtest revision: Break each reacting party target loses to this action by outcome: no reaction
## or a failed one, a successful Brace, a successful Evade, and the cost of a successful Parry.
var break_unreacted: float = 0.0
var break_brace: float = 0.0
var break_evade: float = 0.0
var break_parry_cost: float = 0.0
## The lowest current Break among the reacting targets (0 when none has a meter): an outcome whose
## Break reaches it leaves that target Broken.
var break_remaining: float = 0.0


func is_allowed(reaction: Enums.ReactionType) -> bool:
	return allowed.has(reaction)


## Break one reacting target loses for [param reaction] ([param success]: the reaction succeeded;
## a failed one loses the unreacted amount, as BalanceConfig.party_break_failed_multiplier is 1).
func break_for(reaction: Enums.ReactionType, success: bool) -> float:
	if not success:
		return break_unreacted
	match reaction:
		Enums.ReactionType.BRACE:
			return break_brace
		Enums.ReactionType.EVADE:
			return break_evade
		Enums.ReactionType.PARRY:
			return break_parry_cost
	return break_unreacted


## Would that outcome leave a reacting target Broken?
func would_break(reaction: Enums.ReactionType, success: bool) -> bool:
	return break_remaining > 0.0 and break_for(reaction, success) >= break_remaining


func window_for(reaction: Enums.ReactionType) -> float:
	match reaction:
		Enums.ReactionType.BRACE:
			return brace_window_ms
		Enums.ReactionType.EVADE:
			return evade_window_ms
		Enums.ReactionType.PARRY:
			return parry_window_ms
	return 0.0
