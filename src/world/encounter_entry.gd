class_name EncounterEntry
extends RefCounted
## One captured world encounter attempt (V0.4 rule 2/6). Taken once when the player confirms
## Engage, saved before the battle launches and reused unchanged by Retry: same seed, loadout,
## knowledge, difficulty and assist. Getters return copies; nothing mutates an entry after capture.
## V0.5 UI: the difficulty is the journey's (ProgressState.difficulty) and the loadout also records
## the Hollow's arranged actions in battle order, so neither a later Settings change nor a new
## arrangement in the current save can alter a retry or replay.

var _data: Dictionary = {}


## Captures the current progress/settings for [param site] (an ENCOUNTER landmark).
## [param modifications]: the V0.5B fitting ids already resolved for the equipped weapon
## (PreparationRules.battle_ids); captured with the loadout so a retry never reads live fittings.
## [param actions]: the V0.5 UI combat arrangement (PreparationRules.battle_ids), in battle order;
## empty keeps every granted action (the pre-arrangement behaviour).
## [param potion_charges]: the playtest revision's supply allowance (one whole number per saved
## potion id: min(per-encounter cap, held stock)); null captures none, so the battle uses the
## potions' authored charges and its victory settles nothing (fixtures, entries from before the
## revision). [param familiar_passive]: the familiar passive in effect (&"" = the familiar's default).
static func capture(token: String, area_id: StringName, site: LandmarkDefinition, approach_anchor: StringName,
		battle_seed: int, progress: ProgressState, settings: GameSettings, research: ResearchConfig,
		modifications: Array = [], actions: Array = [], potion_charges: Variant = null,
		familiar_passive: StringName = &"") -> EncounterEntry:
	var entry := EncounterEntry.new()
	var loadout: Dictionary = progress.to_dict().loadout
	var fitted := []
	for modification_id in modifications:
		fitted.append(String(modification_id))
	loadout["modifications"] = fitted
	if not actions.is_empty():
		var arranged := []
		for action_id in actions:
			arranged.append(String(action_id))
		loadout["actions"] = arranged
	if typeof(potion_charges) == TYPE_ARRAY:
		var allowance := []
		for count: Variant in potion_charges:
			allowance.append(maxi(0, ProgressState.number(count, 0)))
		loadout["potion_charges"] = allowance
	if familiar_passive != &"":
		loadout["familiar_passive"] = String(familiar_passive)
	entry._data = {
		"token": token,
		"site": String(site.id),
		"encounter": String(site.encounter.id),
		"area": String(area_id),
		"approach_anchor": String(approach_anchor),
		"seed": battle_seed,
		"loadout": loadout.duplicate(true),
		"research": _string_keys(progress.bestiary.levels(research)),
		"difficulty": int(progress.difficulty),
		"assist": int(settings.execution_assist),
		"auto_brace": int(settings.auto_brace),
		"reaction_pause": int(settings.reaction_pause),
	}
	return entry


## Null when the saved dictionary is not a complete entry.
static func from_dict(data: Dictionary) -> EncounterEntry:
	for key in ["token", "site", "encounter", "area", "approach_anchor", "seed", "loadout", "research",
			"difficulty", "assist"]:
		if not data.has(key):
			return null
	if typeof(data.loadout) != TYPE_DICTIONARY or typeof(data.research) != TYPE_DICTIONARY:
		return null
	for key in ["token", "site", "encounter", "area", "approach_anchor"]:
		if typeof(data[key]) != TYPE_STRING:
			return null
	if String(data.token).is_empty():
		return null
	for key in ["seed", "difficulty", "assist"]:
		if ProgressState.number(data[key], -1) != ProgressState.number(data[key], 0):
			return null
	var entry := EncounterEntry.new()
	entry._data = data.duplicate(true)
	entry._data.seed = ProgressState.number(data.seed, 0)
	entry._data.difficulty = ProgressState.number(data.difficulty, 0)
	entry._data.assist = ProgressState.number(data.assist, 0)
	entry._data.auto_brace = ProgressState.number(data.get("auto_brace"), GameSettings.Toggle.DEFAULT)
	entry._data.reaction_pause = ProgressState.number(data.get("reaction_pause"), GameSettings.Toggle.DEFAULT)
	# A save file has no integers: restore the whole numbers inside the entry too, so an entry read
	# back from disk equals the one that was captured (the supply allowance and research levels).
	var loadout: Dictionary = entry._data.loadout
	if typeof(loadout.get("potion_charges")) == TYPE_ARRAY:
		var allowance := []
		for count: Variant in loadout.potion_charges:
			allowance.append(maxi(0, ProgressState.number(count, 0)))
		loadout["potion_charges"] = allowance
	var research: Dictionary = entry._data.research
	for enemy_id: Variant in research.keys():
		var level: Variant = research[enemy_id]
		if typeof(level) == TYPE_FLOAT and is_finite(level):
			research[enemy_id] = int(level)
	return entry


func to_dict() -> Dictionary:
	return _data.duplicate(true)


func token() -> String:
	return String(_data.token)


func site_id() -> StringName:
	return StringName(_data.site)


func encounter_id() -> StringName:
	return StringName(_data.encounter)


func area_id() -> StringName:
	return StringName(_data.area)


func approach_anchor() -> StringName:
	return StringName(_data.approach_anchor)


func battle_seed() -> int:
	return int(_data.seed)


## A copy of the captured loadout ids (weapon, armor, companion, familiar and its passive, potions
## and their allowance, fittings, arranged actions).
func loadout() -> Dictionary:
	return (_data.loadout as Dictionary).duplicate(true)


## A fresh, deterministic BattleSetup for this entry. Every call builds new objects, so a retry
## starts from exactly the captured inputs. Null when the encounter no longer exists.
func build_setup(registry: DefinitionRegistry, library: CombatLibrary) -> BattleSetup:
	var encounter: EncounterDefinition = registry.encounters.get(encounter_id())
	if encounter == null:
		return null
	var settings := GameSettings.new()
	settings.auto_brace = int(_data.auto_brace) as GameSettings.Toggle
	settings.reaction_pause = int(_data.reaction_pause) as GameSettings.Toggle
	var difficulty: TacticalDifficultyProfile = registry.difficulty(int(_data.difficulty) as Enums.TacticalDifficulty)
	var preset: ExecutionAssistProfile = registry.assist(int(_data.assist) as Enums.ExecutionAssist)
	if difficulty == null or preset == null:
		return null
	var setup := BattleSetup.from_encounter(PartyLoadout.from_ids(registry, _data.loadout), encounter, library,
		difficulty, settings.resolve_assist(preset), battle_seed())
	var research: Dictionary = _data.research
	for enemy_id: String in research:
		setup.research_levels[StringName(enemy_id)] = int(research[enemy_id])
	return setup


static func _string_keys(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[String(key)] = int(source[key])
	return result
