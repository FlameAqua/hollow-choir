class_name JourneySetupReadout
extends RefCounted
## What New Journey offers (V0.5 UI): the three Tactical Difficulty tiers, the approved starter
## presets with their public facts, and every save slot with its state. Plain data from
## JourneyRules.setup(); the title never decides eligibility or picks a slot from it.

## [{id: int (Enums.TacticalDifficulty), name: String, description: String}], in tier order.
var difficulties: Array[Dictionary] = []
## [{id: StringName (the preset weapon id), name: String, description: String, icon_path: String,
##   category: String ("Sword · Slash"), facts: PackedStringArray (the weapon's actions and trait),
##   details: PackedStringArray (the rest of the starting loadout)}], in GameDefaults order.
var presets: Array[Dictionary] = []
## One SaveSlotSummary per slot, in slot order.
var slots: Array[SaveSlotSummary] = []
## Preselected values: the player's current Settings difficulty and the starter loadout's weapon.
var default_difficulty: int = Enums.TacticalDifficulty.ADVENTURER
var default_preset: StringName = &""
## The first EMPTY slot, offered first in the slot list; -1 when every slot is occupied (then only an
## explicitly confirmed replacement can start a journey).
var suggested_slot: int = -1


func all_full() -> bool:
	return suggested_slot < 0


func preset(preset_id: StringName) -> Dictionary:
	for entry in presets:
		if entry.id == preset_id:
			return entry
	return {}


func difficulty(tier: int) -> Dictionary:
	for entry in difficulties:
		if entry.id == tier:
			return entry
	return {}


func slot(index: int) -> SaveSlotSummary:
	for entry in slots:
		if entry.slot == index:
			return entry
	return null
