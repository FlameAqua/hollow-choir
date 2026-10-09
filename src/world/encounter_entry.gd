class_name EncounterEntry
extends RefCounted
## One captured world encounter attempt (V0.4 rule 2/6). Taken once when the player confirms
## Engage, saved before the battle launches and reused unchanged by Retry: same seed, loadout,
## knowledge, difficulty and assist. Getters return copies; nothing mutates an entry after capture.

var _data: Dictionary = {}


## Captures the current progress/settings for [param site] (an ENCOUNTER landmark).
static func capture(token: String, area_id: StringName, site: LandmarkDefinition, approach_anchor: StringName,
		battle_seed: int, progress: ProgressState, settings: GameSettings, research: ResearchConfig) -> EncounterEntry:
	var entry := EncounterEntry.new()
	var loadout: Dictionary = progress.to_dict().loadout
	entry._data = {
		"token": token,
		"site": String(site.id),
		"encounter": String(site.encounter.id),
		"area": String(area_id),
		"approach_anchor": String(approach_anchor),
		"seed": battle_seed,
		"loadout": loadout.duplicate(true),
		"research": _string_keys(progress.bestiary.levels(research)),
		"difficulty": int(settings.tactical_difficulty),
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
	if String(data.token).is_empty():
		return null
	var entry := EncounterEntry.new()
	entry._data = data.duplicate(true)
	entry._data.seed = int(data.seed)
	entry._data.difficulty = int(data.difficulty)
	entry._data.assist = int(data.assist)
	entry._data.auto_brace = int(data.get("auto_brace", GameSettings.Toggle.DEFAULT))
	entry._data.reaction_pause = int(data.get("reaction_pause", GameSettings.Toggle.DEFAULT))
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
