class_name TraitInstance
extends RefCounted
## A TraitDefinition active in a battle, with its owner and trigger usage counters.

var trait_def: TraitDefinition
## Unit id of the owner; -1 for battlefield traits.
var owner_uid: int = -1
## Name shown when a trigger fires ("Bell Crow", "Flooded Ground", "Pilgrim's Edge"…).
var source_name: String = ""
## False once the status/buff that carried it is gone (guards against stale snapshots).
var active: bool = true
var _round_counts: Dictionary[int, int] = {}
var _battle_counts: Dictionary[int, int] = {}


func _init(p_trait: TraitDefinition = null, p_owner_uid: int = -1, p_source_name: String = "") -> void:
	trait_def = p_trait
	owner_uid = p_owner_uid
	source_name = p_source_name if not p_source_name.is_empty() else (p_trait.display_name if p_trait else "")


func can_fire(trigger_index: int, trigger: TriggeredEffectDefinition) -> bool:
	if trigger.max_per_round > 0 and _round_counts.get(trigger_index, 0) >= trigger.max_per_round:
		return false
	if trigger.max_per_battle > 0 and _battle_counts.get(trigger_index, 0) >= trigger.max_per_battle:
		return false
	return true


func record_fire(trigger_index: int) -> void:
	_round_counts[trigger_index] = _round_counts.get(trigger_index, 0) + 1
	_battle_counts[trigger_index] = _battle_counts.get(trigger_index, 0) + 1


func reset_round() -> void:
	_round_counts.clear()


func fired_this_round(trigger_index: int) -> int:
	return _round_counts.get(trigger_index, 0)
