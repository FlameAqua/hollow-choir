class_name ProgressState
extends RefCounted
## Everything a save slot persists (GDD "Save system": progression, inventory, mastery, companions,
## familiars, quests, regional Pressure, regional events, world-state choices, bestiary, home
## upgrades). Settings are stored separately (DECISION_LOG D-009).
##
## M1 uses bestiary, mastery, loadout and stats for real. The remaining sections are versioned
## placeholders so later milestones extend the format instead of breaking it.

## Loadout as content ids (resolved through the Database).
var loadout_weapon: StringName = &"pilgrims_edge"
var loadout_garb: StringName = &"pilgrims_coat"
var loadout_charm: StringName = &""
var loadout_relic: StringName = &""
var loadout_companion: StringName = &"mara"
var loadout_familiar: StringName = &"bell_crow"
var loadout_potions: Array[StringName] = [&"mending_draught", &"fen_water_flask"]

var bestiary := BestiaryState.new()
## weapon id -> mastery points (Perfect actions count double).
var weapon_mastery: Dictionary[StringName, int] = {}
## Owned equipment ids, material id -> count, consumable id -> count, quest item ids.
var owned_equipment: Array[StringName] = [&"pilgrims_edge", &"mire_maul", &"reedbow", &"pilgrims_coat"]
var materials: Dictionary[StringName, int] = {}
var consumables: Dictionary[StringName, int] = {}
var quest_items: Array[StringName] = []
## companion id -> {"recruited": bool, "relationship": int}
var companions: Dictionary[StringName, Dictionary] = {&"mara": {"recruited": true, "relationship": 0}}
var familiars: Array[StringName] = [&"bell_crow", &"cinder_pup"]
## quest id -> stage
var quests: Dictionary[StringName, int] = {}
## region id -> pressure 0..3
var region_pressure: Dictionary[StringName, int] = {&"briarfen": 0}
## region id -> resolved event ids
var region_events: Dictionary[StringName, Array] = {}
## choice id -> CLEANSE / CULTIVATE / STABILIZE (stored as strings for readability)
var world_choices: Dictionary[StringName, String] = {}
## station id -> level
var home_upgrades: Dictionary[StringName, int] = {&"forge": 0, &"stillroom": 0, &"observatory": 0}
var battles_won: int = 0
var battles_lost: int = 0


func apply_battle_result(result: BattleResult, research: ResearchConfig) -> void:
	for enemy_id: StringName in result.research:
		for source in result.research[enemy_id]:
			bestiary.add(enemy_id, source, research.points_for(source))
	for weapon_id: StringName in result.weapon_uses:
		var gained: int = result.weapon_uses[weapon_id] + result.weapon_perfects.get(weapon_id, 0)
		weapon_mastery[weapon_id] = weapon_mastery.get(weapon_id, 0) + gained
	if result.is_victory():
		battles_won += 1
	elif result.outcome != Enums.BattleOutcome.NONE:
		battles_lost += 1


func to_dict() -> Dictionary:
	return {
		"loadout": {
			"weapon": String(loadout_weapon), "garb": String(loadout_garb), "charm": String(loadout_charm),
			"relic": String(loadout_relic), "companion": String(loadout_companion),
			"familiar": String(loadout_familiar), "potions": _ids_to_strings(loadout_potions),
		},
		"bestiary": bestiary.to_dict(),
		"weapon_mastery": _dict_to_strings(weapon_mastery),
		"inventory": {
			"equipment": _ids_to_strings(owned_equipment),
			"materials": _dict_to_strings(materials),
			"consumables": _dict_to_strings(consumables),
			"quest_items": _ids_to_strings(quest_items),
		},
		"companions": _dict_to_strings(companions),
		"familiars": _ids_to_strings(familiars),
		"quests": _dict_to_strings(quests),
		"regions": {"pressure": _dict_to_strings(region_pressure), "events": _dict_to_strings(region_events)},
		"world_choices": _dict_to_strings(world_choices),
		"home_upgrades": _dict_to_strings(home_upgrades),
		"stats": {"battles_won": battles_won, "battles_lost": battles_lost},
	}


static func from_dict(data: Dictionary) -> ProgressState:
	var state := ProgressState.new()
	var loadout: Dictionary = data.get("loadout", {})
	state.loadout_weapon = StringName(loadout.get("weapon", state.loadout_weapon))
	state.loadout_garb = StringName(loadout.get("garb", state.loadout_garb))
	state.loadout_charm = StringName(loadout.get("charm", ""))
	state.loadout_relic = StringName(loadout.get("relic", ""))
	state.loadout_companion = StringName(loadout.get("companion", state.loadout_companion))
	state.loadout_familiar = StringName(loadout.get("familiar", state.loadout_familiar))
	if loadout.has("potions"):
		state.loadout_potions = _strings_to_ids(loadout.potions)
	state.bestiary = BestiaryState.from_dict(data.get("bestiary", {}))
	state.weapon_mastery = _ints_from(data.get("weapon_mastery", {}))
	var inventory: Dictionary = data.get("inventory", {})
	if inventory.has("equipment"):
		state.owned_equipment = _strings_to_ids(inventory.equipment)
	state.materials = _ints_from(inventory.get("materials", {}))
	state.consumables = _ints_from(inventory.get("consumables", {}))
	state.quest_items = _strings_to_ids(inventory.get("quest_items", []))
	if data.has("companions"):
		state.companions.clear()
		var companion_data: Dictionary = data.companions
		for key: String in companion_data:
			state.companions[StringName(key)] = companion_data[key]
	if data.has("familiars"):
		state.familiars = _strings_to_ids(data.familiars)
	state.quests = _ints_from(data.get("quests", {}))
	var regions: Dictionary = data.get("regions", {})
	if regions.has("pressure"):
		state.region_pressure = _ints_from(regions.pressure)
	var events: Dictionary = regions.get("events", {})
	for key: String in events:
		state.region_events[StringName(key)] = Array(events[key])
	var choices: Dictionary = data.get("world_choices", {})
	for key: String in choices:
		state.world_choices[StringName(key)] = String(choices[key])
	if data.has("home_upgrades"):
		state.home_upgrades = _ints_from(data.home_upgrades)
	var stats: Dictionary = data.get("stats", {})
	state.battles_won = int(stats.get("battles_won", 0))
	state.battles_lost = int(stats.get("battles_lost", 0))
	return state


static func _ids_to_strings(ids: Array[StringName]) -> Array:
	var result := []
	for id in ids:
		result.append(String(id))
	return result


static func _strings_to_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


static func _dict_to_strings(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[String(key)] = source[key]
	return result


static func _ints_from(source: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for key: String in source:
		result[StringName(key)] = int(source[key])
	return result
