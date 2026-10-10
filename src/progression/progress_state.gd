class_name ProgressState
extends RefCounted
## Everything a save slot persists (GDD "Save system": progression, inventory, mastery, companions,
## familiars, quests, regional Pressure, regional events, world-state choices, bestiary, home
## upgrades). Settings are stored separately (DECISION_LOG D-009).
##
## M1 uses bestiary, mastery, loadout and stats for real; V0.4 adds the optional `world` section;
## V0.5A uses owned equipment and materials and adds the optional `rewards` claim section; V0.5B
## adds the optional `crafting` section (recipe unlocks and installed fittings); the V0.5 UI pass
## adds the optional `campaign` (journey difficulty and starter preset) and `combat` (the Hollow's
## arranged actions) sections. The playtest revision uses `inventory.consumables` (finite supply
## stock) and `quests` (the bell journey's journal stage) for real and adds the optional
## `migrations` list and `loadout.familiar_passive`. The remaining sections are versioned
## placeholders so later milestones extend the format instead of breaking it.
##
## from_dict() never trusts types: a wrong-typed section or value becomes the default (a damaged
## but valid-JSON save loads instead of crashing), and it never writes, grants or repairs anything.
## Content checks and repairs belong to WorldSession.reconcile().

## Loadout as content ids (resolved through the Database).
var loadout_weapon: StringName = &"pilgrims_edge"
var loadout_garb: StringName = &"pilgrims_coat"
var loadout_charm: StringName = &""
var loadout_relic: StringName = &""
var loadout_companion: StringName = &"mara"
var loadout_familiar: StringName = &"bell_crow"
## Playtest revision: the selected passive (trait id) of the travelling familiar. &"" or an id the
## familiar does not offer = its default passive (FamiliarDefinition.resolved_passive).
var loadout_familiar_passive: StringName = &""
var loadout_potions: Array[StringName] = [&"mending_draught", &"fen_water_flask"]

var bestiary := BestiaryState.new()
## weapon id -> mastery points (Perfect actions count double).
var weapon_mastery: Dictionary[StringName, int] = {}
## Owned equipment ids, material id -> count, consumable id -> count, quest item ids.
var owned_equipment: Array[StringName] = [&"pilgrims_edge", &"mire_maul", &"reedbow", &"pilgrims_coat"]
## Positive counts only, at most MaterialDefinition.MAX_COUNT (V0.5A salvage).
var materials: Dictionary[StringName, int] = {}
## Playtest revision (finite supplies): potion id -> held doses, 1..PotionDefinition.MAX_STOCK.
## Brewing adds a recipe's yield; a saved victory removes the doses that battle used. Unknown ids
## stay inert. Absent in older saves: SupplyRules.migrate grants the bounded starting stock once.
var consumables: Dictionary[StringName, int] = {}
var quest_items: Array[StringName] = []
## companion id -> {"recruited": bool, "relationship": int}
var companions: Dictionary[StringName, Dictionary] = {&"mara": {"recruited": true, "relationship": 0}}
var familiars: Array[StringName] = [&"bell_crow", &"cinder_pup"]
## quest id -> stage (playtest revision: the bell journey's journal stage, re-derived from the
## world by QuestRules inside every world write; never trusted on its own).
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
## V0.4 exploration (optional `world` section; absent in older saves -> default square on entry).
var world := WorldState.new()
## V0.5A claimed campaign reward ids, sorted and unique (optional `rewards` section, outside
## `world` so Reset journey keeps it; absent in older saves = nothing claimed yet).
var reward_claims: Array[StringName] = []
## V0.5B owned RecipeDefinition ids, sorted and unique (optional `crafting` section, outside
## `world` so Reset journey keeps it; absent = none). Ownership, never a count; unknown ids stay
## inert. Playtest revision: the ids are crafted fittings (Kind.FITTING) and an older save's fitting
## kit; potion recipes are brewed into `consumables` and are no longer recorded here.
var crafting_recipes: Array[StringName] = []
## V0.5B weapon id -> installed ModificationDefinition id. Inert unless the weapon offers that
## fitting and the save owns it (CraftingRules.fitting_owned: crafted, or through an older kit).
var weapon_fittings: Dictionary[StringName, StringName] = {}
## V0.5 UI: this journey's Tactical Difficulty (Enums.TacticalDifficulty), chosen at New Journey and
## captured by every encounter entry (optional `campaign` section; absent or invalid = ADVENTURER,
## the Settings default). Settings shows and changes it at any time during the journey (D-009).
var difficulty: int = Enums.TacticalDifficulty.ADVENTURER
## V0.5 UI: the approved starter preset (a weapon id) the journey began with; &"" for older saves.
## A record only: the saved loadout is the truth.
var starter_preset: StringName = &""
## V0.5 UI: the Hollow's arranged action ids in combat-position order (optional `combat` section).
## Empty = never arranged: CombatRules derives the default from the equipped gear. Ids are not
## checked here; CombatRules keeps only granted actions within the unlocked capacity.
var combat_actions: Array[StringName] = []
## Playtest revision: one-time content migrations already applied to this save (optional
## `migrations` section, outside `world` so Reset journey keeps it). A listed migration never runs
## again, whatever the state it left has become since (e.g. a supply stock used down to zero).
var migrations: Array[StringName] = []


func has_migration(migration_id: StringName) -> bool:
	return migrations.has(migration_id)


## Records [param migration_id] once, keeping the list sorted. False when it was already applied.
func add_migration(migration_id: StringName) -> bool:
	if migration_id == &"" or migrations.has(migration_id):
		return false
	migrations.append(migration_id)
	migrations.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return true


## Held doses of [param potion_id] (0 when none).
func supply_count(potion_id: StringName) -> int:
	return maxi(0, consumables.get(potion_id, 0))


## Sets the held doses of [param potion_id]; zero or less removes the entry.
func set_supply(potion_id: StringName, count: int) -> void:
	if count > 0:
		consumables[potion_id] = mini(count, PotionDefinition.MAX_STOCK)
	else:
		consumables.erase(potion_id)


func has_claim(claim_id: StringName) -> bool:
	return reward_claims.has(claim_id)


func has_recipe(recipe_id: StringName) -> bool:
	return crafting_recipes.has(recipe_id)


## Records [param recipe_id] once, keeping the list sorted. False when it was already unlocked.
func add_recipe(recipe_id: StringName) -> bool:
	if recipe_id == &"" or crafting_recipes.has(recipe_id):
		return false
	crafting_recipes.append(recipe_id)
	crafting_recipes.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return true


func remove_recipe(recipe_id: StringName) -> bool:
	if not crafting_recipes.has(recipe_id):
		return false
	crafting_recipes.erase(recipe_id)
	return true


## Records [param claim_id] once, keeping the list sorted. False when it was already claimed.
func add_claim(claim_id: StringName) -> bool:
	if claim_id == &"" or reward_claims.has(claim_id):
		return false
	reward_claims.append(claim_id)
	reward_claims.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return true


func material_count(material_id: StringName) -> int:
	return materials.get(material_id, 0)


## The loadout section as saved: content ids by slot (EncounterEntry captures the same shape).
func loadout_ids() -> Dictionary:
	return {
		"weapon": String(loadout_weapon), "garb": String(loadout_garb), "charm": String(loadout_charm),
		"relic": String(loadout_relic), "companion": String(loadout_companion),
		"familiar": String(loadout_familiar), "familiar_passive": String(loadout_familiar_passive),
		"potions": _ids_to_strings(loadout_potions),
	}


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
		"loadout": loadout_ids(),
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
		"world": world.to_dict(),
		"rewards": {"claims": _ids_to_strings(reward_claims)},
		"crafting": {"recipes": _ids_to_strings(crafting_recipes), "fittings": _fitting_strings()},
		"campaign": {"difficulty": difficulty, "starter": String(starter_preset)},
		"combat": {"actions": _ids_to_strings(combat_actions)},
		"migrations": _ids_to_strings(migrations),
	}


func _fitting_strings() -> Dictionary:
	var result := {}
	for weapon_id: StringName in weapon_fittings:
		result[String(weapon_id)] = String(weapon_fittings[weapon_id])
	return result


static func from_dict(data: Dictionary) -> ProgressState:
	var state := ProgressState.new()
	var loadout := _section(data, "loadout")
	state.loadout_weapon = _id(loadout.get("weapon"), state.loadout_weapon)
	state.loadout_garb = _id(loadout.get("garb"), state.loadout_garb)
	state.loadout_charm = _id(loadout.get("charm"), &"")
	state.loadout_relic = _id(loadout.get("relic"), &"")
	state.loadout_companion = _id(loadout.get("companion"), state.loadout_companion)
	state.loadout_familiar = _id(loadout.get("familiar"), state.loadout_familiar)
	state.loadout_familiar_passive = _id(loadout.get("familiar_passive"), &"")
	if typeof(loadout.get("potions")) == TYPE_ARRAY:
		state.loadout_potions = _id_list(loadout.potions, false)
	state.bestiary = BestiaryState.from_dict(_section(data, "bestiary"))
	state.weapon_mastery = _ints_from(_section(data, "weapon_mastery"))
	var inventory := _section(data, "inventory")
	if typeof(inventory.get("equipment")) == TYPE_ARRAY:
		state.owned_equipment = _id_list(inventory.equipment, true)
	state.materials = _counts(inventory.get("materials"))
	state.consumables = _counts(inventory.get("consumables"), PotionDefinition.MAX_STOCK)
	state.quest_items = _id_list(inventory.get("quest_items", []), false)
	if typeof(data.get("companions")) == TYPE_DICTIONARY:
		state.companions.clear()
		var companion_data: Dictionary = data.companions
		for key: Variant in companion_data:
			if typeof(key) == TYPE_STRING and typeof(companion_data[key]) == TYPE_DICTIONARY:
				state.companions[StringName(key)] = companion_data[key]
	if typeof(data.get("familiars")) == TYPE_ARRAY:
		state.familiars = _id_list(data.familiars, false)
	state.quests = _ints_from(_section(data, "quests"))
	var regions := _section(data, "regions")
	if typeof(regions.get("pressure")) == TYPE_DICTIONARY:
		state.region_pressure = _ints_from(regions.pressure)
	var events := _section(regions, "events")
	for key: Variant in events:
		if typeof(key) == TYPE_STRING and typeof(events[key]) == TYPE_ARRAY:
			state.region_events[StringName(key)] = Array(events[key])
	var choices := _section(data, "world_choices")
	for key: Variant in choices:
		if typeof(key) == TYPE_STRING and typeof(choices[key]) == TYPE_STRING:
			state.world_choices[StringName(key)] = String(choices[key])
	if typeof(data.get("home_upgrades")) == TYPE_DICTIONARY:
		state.home_upgrades = _ints_from(data.home_upgrades)
	var stats := _section(data, "stats")
	state.battles_won = maxi(0, number(stats.get("battles_won"), 0))
	state.battles_lost = maxi(0, number(stats.get("battles_lost"), 0))
	state.world = WorldState.from_dict(data.get("world"))
	state.reward_claims = _claims(_section(data, "rewards").get("claims"))
	var crafting := _section(data, "crafting")
	state.crafting_recipes = _claims(crafting.get("recipes"))
	state.weapon_fittings = _fittings(crafting.get("fittings"))
	var campaign := _section(data, "campaign")
	state.difficulty = _difficulty(campaign.get("difficulty"))
	state.starter_preset = _id(campaign.get("starter"), &"")
	state.combat_actions = _id_list(_section(data, "combat").get("actions"), true)
	state.migrations = _claims(data.get("migrations"))
	return state


## A whole number from a saved value: ints and integral, finite floats; anything else is
## [param fallback] (shared by the other save readers, so a damaged field never crashes a load).
static func number(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value) and absf(value) < 9.0e15:
		return int(value)
	return fallback


## A saved campaign difficulty: an Enums.TacticalDifficulty value, else ADVENTURER (the default).
static func _difficulty(value: Variant) -> int:
	var tier := number(value, Enums.TacticalDifficulty.ADVENTURER)
	return tier if Enums.TacticalDifficulty.values().has(tier) else Enums.TacticalDifficulty.ADVENTURER


## A nested section, or {} when it is absent or not a dictionary.
static func _section(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key)
	return value if typeof(value) == TYPE_DICTIONARY else {}


## A saved content id: strings only; anything else keeps [param fallback].
static func _id(value: Variant, fallback: StringName) -> StringName:
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return StringName(value)
	return fallback


## The string entries of a saved id list, in order (others dropped; optionally de-duplicated).
static func _id_list(values: Variant, unique: bool) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
			continue
		var id := StringName(value)
		if id != &"" and not (unique and result.has(id)):
			result.append(id)
	return result


## Saved counts (materials, supply doses): whole numbers of at least 1, capped at [param cap].
## Zero, negative, fractional, non-numeric and NaN entries are dropped; ids are not checked here.
static func _counts(value: Variant, cap: int = MaterialDefinition.MAX_COUNT) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key: Variant in value:
		var count: Variant = value[key]
		if (typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME) or String(key).is_empty():
			continue
		if typeof(count) != TYPE_INT and typeof(count) != TYPE_FLOAT:
			continue
		var amount := float(count)
		if is_nan(amount) or amount < 1.0 or amount != floorf(amount):
			continue
		result[StringName(key)] = int(minf(amount, cap))
	return result


## Saved claim ids: unique non-empty strings, sorted. Unknown ids are kept (they can only block a
## grant that does not exist); other types are dropped.
static func _claims(values: Variant) -> Array[StringName]:
	var result := _id_list(values, true)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


## Saved fittings: non-empty string weapon ids to non-empty string fitting ids; anything else is
## dropped. Ids are not checked here (unknown ones stay inert).
static func _fittings(value: Variant) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key: Variant in value:
		var fitting: Variant = value[key]
		if (typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME) or String(key).is_empty():
			continue
		if (typeof(fitting) != TYPE_STRING and typeof(fitting) != TYPE_STRING_NAME) or String(fitting).is_empty():
			continue
		result[StringName(key)] = StringName(fitting)
	return result


static func _ids_to_strings(ids: Array[StringName]) -> Array:
	var result := []
	for id in ids:
		result.append(String(id))
	return result


static func _dict_to_strings(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[String(key)] = source[key]
	return result


## Whole-number values by string key; other keys and values are dropped.
static func _ints_from(source: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for key: Variant in source:
		var value: Variant = source[key]
		if typeof(key) == TYPE_STRING and number(value, -1) == number(value, 0):
			result[StringName(key)] = number(value, 0)
	return result
