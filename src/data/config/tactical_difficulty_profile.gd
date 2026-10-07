class_name TacticalDifficultyProfile
extends Resource
## Tactical Difficulty changes decision QUALITY, not numbers: which AI considerations are active
## (each consideration has a min_difficulty), how noisy choices are, and Story-mode courtesy rules.
## There is deliberately no enemy stat multiplier here (GDD: no inflated health bars).

@export var difficulty: Enums.TacticalDifficulty = Enums.TacticalDifficulty.ADVENTURER
@export var display_name: String = ""
@export_multiline var description: String = ""
## Multiplicative noise on utility scores (+/-). Story is noisy, Tactician is sharp.
@export_range(0.0, 1.0, 0.01) var score_variance: float = 0.2
## Story: avoid stacking several likely-lethal attacks on one target in the same round.
@export var avoid_lethal_combinations: bool = false
@export var lethal_combination_weight: float = 0.25
## Story: dangerous channels take extra turns, giving more time to answer (same damage).
@export var channel_extra_turns: int = 0


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("difficulty profile without display_name")
	return problems
