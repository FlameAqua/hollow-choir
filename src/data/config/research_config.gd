class_name ResearchConfig
extends Resource
## Bestiary research: points per source and level thresholds. Research is earned by understanding
## (inspecting, exploiting, parrying signature moves), not only by kills.

@export_group("Points")
@export var encounter_points: int = 1
@export var inspect_points: int = 3
@export var defeat_points: int = 2
@export var weakness_points: int = 1
@export var signature_parry_points: int = 3
@export var rare_ability_points: int = 2
@export var lore_points: int = 3
@export var quest_points: int = 4

@export_group("Thresholds")
@export var observed_threshold: int = 1
@export var studied_threshold: int = 5
@export var understood_threshold: int = 10
@export var mastered_threshold: int = 18

@export_group("Battle")
## Inspecting an enemy reveals information at this level for the rest of the battle.
@export var inspect_reveal_level: Enums.ResearchLevel = Enums.ResearchLevel.UNDERSTOOD


func points_for(source: Enums.ResearchSource) -> int:
	match source:
		Enums.ResearchSource.ENCOUNTER:
			return encounter_points
		Enums.ResearchSource.INSPECT:
			return inspect_points
		Enums.ResearchSource.DEFEAT:
			return defeat_points
		Enums.ResearchSource.WEAKNESS:
			return weakness_points
		Enums.ResearchSource.SIGNATURE_PARRY:
			return signature_parry_points
		Enums.ResearchSource.RARE_ABILITY:
			return rare_ability_points
		Enums.ResearchSource.LORE:
			return lore_points
		Enums.ResearchSource.QUEST:
			return quest_points
	return 0


func level_for_points(points: int) -> Enums.ResearchLevel:
	if points >= mastered_threshold:
		return Enums.ResearchLevel.MASTERED
	if points >= understood_threshold:
		return Enums.ResearchLevel.UNDERSTOOD
	if points >= studied_threshold:
		return Enums.ResearchLevel.STUDIED
	if points >= observed_threshold:
		return Enums.ResearchLevel.OBSERVED
	return Enums.ResearchLevel.UNKNOWN


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not (observed_threshold <= studied_threshold and studied_threshold <= understood_threshold
			and understood_threshold <= mastered_threshold):
		problems.append("research thresholds must be ascending")
	return problems
