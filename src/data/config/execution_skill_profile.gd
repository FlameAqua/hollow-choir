class_name ExecutionSkillProfile
extends Resource
## A model of human execution for automated battles (GDD: simulated MISS / GOOD / PERFECT / MIXED).
## Probabilities are at STANDARD assist; ExecutionSimulator adjusts them for other assist windows.

@export var mode: Enums.SimulatedExecution = Enums.SimulatedExecution.GOOD
@export var display_name: String = ""
@export_group("Action commands")
@export var miss_weight: float = 0.0
@export var good_weight: float = 1.0
@export var perfect_weight: float = 0.0
@export_group("Reactions")
## False models a player who never presses reaction keys.
@export var reacts: bool = true
@export_range(0.0, 1.0, 0.01) var brace_success: float = 0.95
@export_range(0.0, 1.0, 0.01) var evade_success: float = 0.75
@export_range(0.0, 1.0, 0.01) var parry_success: float = 0.4


func success_chance(reaction: Enums.ReactionType) -> float:
	match reaction:
		Enums.ReactionType.BRACE:
			return brace_success
		Enums.ReactionType.EVADE:
			return evade_success
		Enums.ReactionType.PARRY:
			return parry_success
	return 0.0


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if miss_weight + good_weight + perfect_weight <= 0.0:
		problems.append("skill profile %s has no grade weights" % display_name)
	return problems
