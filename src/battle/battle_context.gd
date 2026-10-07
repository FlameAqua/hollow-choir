class_name BattleContext
extends RefCounted
## The hub every rule function receives: state, configuration, the seeded RNG and the event queue.
## Rules are static functions taking a BattleContext, so nothing holds a reference back to it.

var state: BattleState
var setup: BattleSetup
var library: CombatLibrary
var balance: BalanceConfig
var difficulty: TacticalDifficultyProfile
var assist: ExecutionAssistProfile
## The only source of battle randomness (damage variance, chances, AI noise).
var rng: RandomNumberGenerator
var events: Array[BattleEvent] = []
## Ids of (enemy species, research source) pairs already awarded this battle.
var research_awarded: Dictionary[String, bool] = {}


func _init(p_setup: BattleSetup) -> void:
	setup = p_setup
	library = setup.library
	balance = library.balance
	difficulty = setup.difficulty
	assist = setup.assist
	rng = RandomNumberGenerator.new()
	rng.seed = setup.seed
	state = BattleState.new()
	state.advantage = setup.advantage


func emit(event: BattleEvent) -> BattleEvent:
	event.round = state.round
	events.append(event)
	return event


## True once one side has no living units (the engine formally ends the battle right after).
## Rules stop resolving further effects and triggers at that point.
func is_decided() -> bool:
	if state.is_finished():
		return true
	var party_alive := false
	var enemies_alive := false
	for candidate in state.units:
		if candidate.hp > 0:
			if candidate.side == Enums.Side.PLAYER:
				party_alive = true
			else:
				enemies_alive = true
	return not (party_alive and enemies_alive)


func note(text: String) -> void:
	var event := BattleEvent.new(BattleEvent.Type.NOTE)
	event.text = text
	emit(event)


func unit(uid: int) -> BattleUnit:
	return state.unit(uid)


func uid_of(battle_unit: BattleUnit) -> int:
	return battle_unit.uid if battle_unit != null else -1


func allies_of(battle_unit: BattleUnit, include_self: bool = true) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for candidate in state.side_units(battle_unit.side):
		if include_self or candidate != battle_unit:
			result.append(candidate)
	return result


func opponents_of(battle_unit: BattleUnit) -> Array[BattleUnit]:
	var other_side := Enums.Side.ENEMY if battle_unit.side == Enums.Side.PLAYER else Enums.Side.PLAYER
	return state.side_units(other_side)


## Multiplicative damage variance roll in [1 - v, 1 + v].
func roll_variance() -> float:
	var variance := balance.damage_variance
	if variance <= 0.0:
		return 1.0
	return 1.0 + rng.randf_range(-variance, variance)


## Deterministic chance check. Consumes RNG only when the outcome is uncertain.
func roll_chance(probability: float) -> bool:
	if probability >= 1.0:
		return true
	if probability <= 0.0:
		return false
	return rng.randf() < probability
