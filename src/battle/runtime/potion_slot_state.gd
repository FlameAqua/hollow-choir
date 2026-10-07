class_name PotionSlotState
extends RefCounted
## One of the party's potion slots during battle.

var potion: PotionDefinition
var charges: int = 0


func _init(p_potion: PotionDefinition = null, p_charges: int = 0) -> void:
	potion = p_potion
	charges = p_charges
