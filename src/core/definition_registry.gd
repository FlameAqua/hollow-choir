class_name DefinitionRegistry
extends RefCounted
## Loads every definition under a folder (default res://data) and indexes it by type and id
## (DECISION_LOG D-012). Designers add content by dropping a .tres file into data/.
## Used by the Database autoload, the test suite and the simulation CLI.

const DATA_ROOT := "res://data"

var weapons: Dictionary[StringName, WeaponDefinition] = {}
var armor: Dictionary[StringName, ArmorDefinition] = {}
var enemies: Dictionary[StringName, EnemyDefinition] = {}
var companions: Dictionary[StringName, CompanionDefinition] = {}
var protagonists: Dictionary[StringName, ProtagonistDefinition] = {}
var familiars: Dictionary[StringName, FamiliarDefinition] = {}
var potions: Dictionary[StringName, PotionDefinition] = {}
var encounters: Dictionary[StringName, EncounterDefinition] = {}
var loadouts: Dictionary[StringName, PartyLoadout] = {}
var conditions: Dictionary[StringName, BattlefieldConditionDefinition] = {}
var actions: Dictionary[StringName, ActionDefinition] = {}
var buffs: Dictionary[StringName, BuffDefinition] = {}
var traits: Dictionary[StringName, TraitDefinition] = {}
var statuses: Dictionary[int, StatusDefinition] = {}
var roles: Dictionary[int, EnemyRoleDefinition] = {}
var resonances: Dictionary[int, ResonanceDefinition] = {}
var difficulty_profiles: Dictionary[int, TacticalDifficultyProfile] = {}
var assist_profiles: Dictionary[int, ExecutionAssistProfile] = {}
var skill_profiles: Dictionary[int, ExecutionSkillProfile] = {}
var balance: BalanceConfig
var research: ResearchConfig
## Problems found while loading (unknown files, duplicate ids). See also validate().
var load_problems: PackedStringArray = PackedStringArray()
var _paths: Dictionary[String, String] = {}


static func load_default() -> DefinitionRegistry:
	var registry := DefinitionRegistry.new()
	registry.load_from(DATA_ROOT)
	return registry


func load_from(root: String) -> void:
	for path in _list_resources(root):
		var resource := load(path)
		if resource == null:
			load_problems.append("could not load %s" % path)
			continue
		_register(resource, path)


func make_library() -> CombatLibrary:
	var library := CombatLibrary.new()
	library.balance = balance
	library.research = research
	for status: StatusDefinition in statuses.values():
		library.add_status(status)
	for role: EnemyRoleDefinition in roles.values():
		library.add_role(role)
	for resonance: ResonanceDefinition in resonances.values():
		library.add_resonance(resonance)
	return library


func difficulty(tier: Enums.TacticalDifficulty) -> TacticalDifficultyProfile:
	return difficulty_profiles.get(tier)


func assist(kind: Enums.ExecutionAssist) -> ExecutionAssistProfile:
	return assist_profiles.get(kind)


func skill(mode: Enums.SimulatedExecution) -> ExecutionSkillProfile:
	return skill_profiles.get(mode)


func sorted_ids(dictionary: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in dictionary.keys():
		ids.append(key)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Runs every definition's own validate() plus cross-definition checks.
func validate() -> PackedStringArray:
	var problems := load_problems.duplicate()
	if balance == null:
		problems.append("no BalanceConfig in %s" % DATA_ROOT)
	else:
		problems.append_array(balance.validate())
	if research == null:
		problems.append("no ResearchConfig in %s" % DATA_ROOT)
	for collection: Dictionary in [weapons, armor, enemies, companions, protagonists, familiars, potions,
			encounters, loadouts, conditions, actions, buffs, traits, statuses, roles, resonances,
			difficulty_profiles, assist_profiles, skill_profiles]:
		for key in collection:
			var definition: Resource = collection[key]
			for problem: String in definition.call("validate"):
				problems.append("%s: %s" % [_paths.get(definition.resource_path, definition.resource_path), problem])
	for tier in Enums.TacticalDifficulty.values():
		if not difficulty_profiles.has(tier):
			problems.append("missing TacticalDifficultyProfile %s" % Enums.TacticalDifficulty.keys()[tier])
	for kind in Enums.ExecutionAssist.values():
		if not assist_profiles.has(kind):
			problems.append("missing ExecutionAssistProfile %s" % Enums.ExecutionAssist.keys()[kind])
	for status in [Enums.StatusId.BURN, Enums.StatusId.WET, Enums.StatusId.SHOCK, Enums.StatusId.BLEED]:
		if not statuses.has(status):
			problems.append("missing vertical-slice status %s" % EnumText.status(status))
	problems.append_array(_check_weapon_power_spread())
	return problems


## GDD: rarity must not imply gigantic raw-stat scaling. Flags families whose base power spread
## exceeds WeaponDefinition.MAX_POWER_SPREAD_WITHIN_FAMILY.
func _check_weapon_power_spread() -> PackedStringArray:
	var problems := PackedStringArray()
	var by_family: Dictionary[int, Array] = {}
	for weapon: WeaponDefinition in weapons.values():
		if not by_family.has(weapon.family):
			by_family[weapon.family] = []
		by_family[weapon.family].append(weapon.base_power)
	for family: int in by_family:
		var powers: Array = by_family[family]
		var low: float = powers.min()
		var high: float = powers.max()
		if low > 0.0 and (high - low) / low > WeaponDefinition.MAX_POWER_SPREAD_WITHIN_FAMILY:
			problems.append("%s power spread %.0f-%.0f exceeds the horizontal-weapon limit" % [
				EnumText.family(family), low, high])
	return problems


func _register(resource: Resource, path: String) -> void:
	_paths[path] = path
	if resource is BalanceConfig:
		if balance != null:
			load_problems.append("multiple BalanceConfig files (%s)" % path)
		balance = resource
	elif resource is ResearchConfig:
		research = resource
	elif resource is WeaponDefinition:
		_put(weapons, resource.id, resource, path)
	elif resource is ArmorDefinition:
		_put(armor, resource.id, resource, path)
	elif resource is EnemyDefinition:
		_put(enemies, resource.id, resource, path)
	elif resource is CompanionDefinition:
		_put(companions, resource.id, resource, path)
	elif resource is ProtagonistDefinition:
		_put(protagonists, resource.id, resource, path)
	elif resource is FamiliarDefinition:
		_put(familiars, resource.id, resource, path)
	elif resource is PotionDefinition:
		_put(potions, resource.id, resource, path)
	elif resource is EncounterDefinition:
		_put(encounters, resource.id, resource, path)
	elif resource is PartyLoadout:
		_put(loadouts, resource.id, resource, path)
	elif resource is BattlefieldConditionDefinition:
		_put(conditions, resource.id, resource, path)
	elif resource is ActionDefinition:
		_put(actions, resource.id, resource, path)
	elif resource is BuffDefinition:
		_put(buffs, resource.id, resource, path)
	elif resource is TraitDefinition:
		_put(traits, resource.id, resource, path)
	elif resource is StatusDefinition:
		_put_enum(statuses, resource.status, resource, path)
	elif resource is EnemyRoleDefinition:
		_put_enum(roles, resource.role, resource, path)
	elif resource is ResonanceDefinition:
		_put_enum(resonances, resource.tag, resource, path)
	elif resource is TacticalDifficultyProfile:
		_put_enum(difficulty_profiles, resource.difficulty, resource, path)
	elif resource is ExecutionAssistProfile:
		_put_enum(assist_profiles, resource.assist, resource, path)
	elif resource is ExecutionSkillProfile:
		_put_enum(skill_profiles, resource.mode, resource, path)
	else:
		load_problems.append("unrecognised resource type in %s" % path)


func _put(collection: Dictionary, id: StringName, resource: Resource, path: String) -> void:
	if id == &"":
		load_problems.append("%s has no id" % path)
		return
	if collection.has(id):
		load_problems.append("duplicate id '%s' in %s and %s" % [id, collection[id].resource_path, path])
		return
	collection[id] = resource


func _put_enum(collection: Dictionary, key: int, resource: Resource, path: String) -> void:
	if collection.has(key):
		load_problems.append("duplicate definition for key %d in %s and %s" % [key, collection[key].resource_path, path])
		return
	collection[key] = resource


static func _list_resources(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				result.append_array(_list_resources(path))
		else:
			# Exported builds list "file.tres.remap"; load the original path instead.
			var clean := path.trim_suffix(".remap")
			if (clean.ends_with(".tres") or clean.ends_with(".res")) and not result.has(clean):
				result.append(clean)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
