class_name BattleState
extends RefCounted
## The complete mutable state of one battle.

var units: Array[BattleUnit] = []
var round: int = 0
var phase: Enums.BattlePhase = Enums.BattlePhase.BATTLE_START
var outcome: Enums.BattleOutcome = Enums.BattleOutcome.NONE
## Unit ids in activation order for the current round.
var turn_order: Array[int] = []
var turn_index: int = -1
var conditions: Array[ActiveCondition] = []
var potion_slots: Array[PotionSlotState] = []
var familiar: FamiliarDefinition
var advantage: Enums.Advantage = Enums.Advantage.NONE


func unit(uid: int) -> BattleUnit:
	if uid < 0 or uid >= units.size():
		return null
	return units[uid]


func current_unit() -> BattleUnit:
	if turn_index < 0 or turn_index >= turn_order.size():
		return null
	return unit(turn_order[turn_index])


func side_units(side: Enums.Side, living_only: bool = true) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for candidate in units:
		if candidate.side == side and (not living_only or candidate.is_alive()):
			result.append(candidate)
	return result


func party(living_only: bool = true) -> Array[BattleUnit]:
	return side_units(Enums.Side.PLAYER, living_only)


func enemies(living_only: bool = true) -> Array[BattleUnit]:
	return side_units(Enums.Side.ENEMY, living_only)


func living_units() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for candidate in units:
		if candidate.is_alive():
			result.append(candidate)
	return result


func protagonist() -> BattleUnit:
	for candidate in units:
		if candidate.is_protagonist:
			return candidate
	return null


func has_condition(definition: BattlefieldConditionDefinition) -> bool:
	return find_condition(definition) != null


func find_condition(definition: BattlefieldConditionDefinition) -> ActiveCondition:
	if definition == null:
		return null
	for active in conditions:
		if active.definition == definition or (definition.id != &"" and active.definition.id == definition.id):
			return active
	return null


## True once the unit has had (or skipped) its activation this round.
func has_acted_this_round(uid: int) -> bool:
	var position := turn_order.find(uid)
	return position != -1 and position < turn_index


func is_finished() -> bool:
	return phase == Enums.BattlePhase.VICTORY or phase == Enums.BattlePhase.DEFEAT
