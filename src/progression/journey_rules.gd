class_name JourneyRules
extends RefCounted
## V0.5 UI New Journey: the approved starter presets (GameDefaults.journey_presets), the journey's
## Tactical Difficulty and an explicitly chosen save slot. A preset only names the equipped weapon;
## everything else is the complete fresh campaign (ProgressState defaults), so a preset never grants
## gear, recipes or potions a journey has to earn. Pure: the caller passes the registry, the world,
## the slot summaries and a writer; GameState.start_journey() adopts a successful result.

## Request keys sent by MainMenu.new_journey_requested(options).
const DIFFICULTY := "difficulty"
const PRESET := "preset_id"
const SLOT := "slot"
const REPLACE := "replace"


## The approved starter presets (weapons), in authored order.
static func presets(registry: DefinitionRegistry) -> Array[WeaponDefinition]:
	var result: Array[WeaponDefinition] = []
	if registry.defaults != null:
		for weapon in registry.defaults.journey_presets:
			if weapon != null and not result.has(weapon):
				result.append(weapon)
	return result


static func preset(registry: DefinitionRegistry, preset_id: StringName) -> WeaponDefinition:
	for weapon in presets(registry):
		if weapon.id == preset_id:
			return weapon
	return null


## The fresh journey for [param preset_id] on [param difficulty]: ProgressState defaults with the
## preset's weapon equipped and the world at its start anchor. Nothing is earned, claimed or owned
## beyond a fresh campaign. Playtest revision: with [param registry] the journey also starts with
## its finite starter supplies, the supply migration already marked (SupplyRules.migrate) and the
## bell journey recorded at its first step, so world entry writes and grants nothing more.
static func fresh_progress(definition: WorldDefinition, preset_id: StringName, difficulty: int,
		registry: DefinitionRegistry = null) -> ProgressState:
	var progress := ProgressState.new()
	progress.loadout_weapon = preset_id
	progress.difficulty = difficulty
	progress.starter_preset = preset_id
	progress.world = WorldState.fresh(definition)
	if registry != null:
		SupplyRules.migrate(progress, registry)
		QuestRules.sync(progress, definition)
	return progress


## The typed request in [param options] (the UI's {difficulty, preset_id, slot, replace}). A missing
## or wrong-typed value becomes one that check() rejects; nothing is guessed for the player.
static func request(options: Dictionary) -> Dictionary:
	var preset_value: Variant = options.get(PRESET)
	return {
		DIFFICULTY: ProgressState.number(options.get(DIFFICULTY), -1),
		PRESET: StringName(preset_value) if typeof(preset_value) in [TYPE_STRING, TYPE_STRING_NAME] else &"",
		SLOT: ProgressState.number(options.get(SLOT), -1) if options.has(SLOT) else -1,
		REPLACE: typeof(options.get(REPLACE)) == TYPE_BOOL and options.get(REPLACE),
	}


## Would [param typed] (from request()) start a journey now? [param summaries]: every slot's state.
static func check(registry: DefinitionRegistry, typed: Dictionary,
		summaries: Array[SaveSlotSummary]) -> JourneyResult.Reason:
	var tier: int = typed[DIFFICULTY]
	if not Enums.TacticalDifficulty.values().has(tier) or registry.difficulty(tier as Enums.TacticalDifficulty) == null:
		return JourneyResult.Reason.UNKNOWN_DIFFICULTY
	if preset(registry, typed[PRESET]) == null:
		return JourneyResult.Reason.UNKNOWN_PRESET
	var slot: int = typed[SLOT]
	if slot == -1:
		return JourneyResult.Reason.NO_SLOT
	if slot < 0 or slot >= SaveSlotSummary.SLOT_COUNT:
		return JourneyResult.Reason.INVALID_SLOT
	for entry in summaries:
		if entry.slot == slot and entry.occupied() and not typed[REPLACE]:
			return JourneyResult.Reason.SLOT_OCCUPIED
	return JourneyResult.Reason.OK


## Checks [param options], builds the fresh journey and writes it with [param writer]
## (func(slot: int, progress: ProgressState) -> Error). Nothing is adopted here; on a rejection or a
## failed write no file is touched beyond the writer's own atomic replace.
static func create(options: Dictionary, registry: DefinitionRegistry, definition: WorldDefinition,
		summaries: Array[SaveSlotSummary], writer: Callable) -> JourneyResult:
	var typed := request(options)
	var result := JourneyResult.new()
	result.difficulty = typed[DIFFICULTY]
	result.preset_id = typed[PRESET]
	result.slot = typed[SLOT]
	result.replace = typed[REPLACE]
	result.reason = check(registry, typed, summaries)
	if result.reason != JourneyResult.Reason.OK:
		result.error = JourneyResult.error_for(result.reason)
		return result
	var candidate := fresh_progress(definition, result.preset_id, result.difficulty, registry)
	result.error = writer.call(result.slot, candidate)
	if result.error != OK:
		result.reason = JourneyResult.Reason.WRITE_FAILED
		return result
	for entry in summaries:
		if entry.slot == result.slot and entry.occupied():
			result.replaced = true
	result.progress = candidate
	result.changed = true
	return result


## The New Journey readout. [param default_difficulty]: the player's current Settings tier.
static func setup(registry: DefinitionRegistry, summaries: Array[SaveSlotSummary],
		default_difficulty: int) -> JourneySetupReadout:
	var result := JourneySetupReadout.new()
	for tier in Enums.TacticalDifficulty.values():
		var profile := registry.difficulty(tier)
		if profile != null:
			result.difficulties.append({"id": int(tier), "name": profile.display_name, "description": profile.description})
	result.default_difficulty = default_difficulty if not result.difficulty(default_difficulty).is_empty() \
		else Enums.TacticalDifficulty.ADVENTURER
	var fresh := ProgressState.new()
	for weapon in presets(registry):
		result.presets.append(_preset_entry(registry, weapon, fresh))
	var starter := registry.defaults.starter_loadout.weapon if registry.defaults != null else null
	result.default_preset = starter.id if starter != null and preset(registry, starter.id) != null \
		else (result.presets[0].id if not result.presets.is_empty() else &"")
	result.slots.assign(summaries)
	for entry in summaries:
		if not entry.occupied():
			result.suggested_slot = entry.slot
			break
	return result


static func _preset_entry(registry: DefinitionRegistry, weapon: WeaponDefinition, fresh: ProgressState) -> Dictionary:
	var facts := PackedStringArray()
	for action in [weapon.basic_attack] + weapon.techniques + [weapon.guard_action]:
		if action != null:
			facts.append("%s · %s" % [action.display_name, EnumText.category(action.category)])
	for trait_def in weapon.traits:
		if trait_def != null:
			facts.append("%s\n%s" % [trait_def.display_name, trait_def.description])
	var details := PackedStringArray()
	var garb: ArmorDefinition = registry.armor.get(fresh.loadout_garb)
	var companion: CompanionDefinition = registry.companions.get(fresh.loadout_companion)
	var familiar: FamiliarDefinition = registry.familiars.get(fresh.loadout_familiar)
	var potions := PackedStringArray()
	for potion_id in fresh.loadout_potions:
		var potion: PotionDefinition = registry.potions.get(potion_id)
		if potion != null:
			potions.append(potion.display_name)
	if garb != null:
		details.append(WorldCopy.JOURNEY_PRESET_GARB % garb.display_name)
	if companion != null and familiar != null:
		details.append(WorldCopy.JOURNEY_PRESET_PARTY % [companion.display_name, familiar.display_name])
	if not potions.is_empty():
		details.append(WorldCopy.JOURNEY_PRESET_SUPPLIES % ", ".join(potions))
	details.append(WorldCopy.JOURNEY_PRESET_OWNED)
	return {"id": weapon.id, "name": weapon.display_name, "description": weapon.description,
		"icon_path": weapon.icon.resource_path if weapon.icon != null else "",
		"category": "%s · %s" % [EnumText.family(weapon.family), EnumText.damage_type(weapon.damage_type)],
		"facts": facts, "details": details}


## Catalog checks for DefinitionRegistry.validate(): at least one preset; every preset is a registered
## weapon that a fresh campaign owns, and the fresh journey it starts is a complete, valid loadout
## (equipping it passes the preparation checks and needs no compatibility repair).
static func validate_catalog(registry: DefinitionRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if registry.defaults == null:
		return problems
	if presets(registry).is_empty():
		problems.append("GameDefaults needs at least one journey preset")
	for weapon in presets(registry):
		if registry.weapons.get(weapon.id) != weapon:
			problems.append("journey preset %s is not a registered data/ weapon" % weapon.id)
			continue
		var fresh := ProgressState.new()
		if not fresh.owned_equipment.has(weapon.id):
			problems.append("journey preset %s is not owned by a fresh campaign" % weapon.id)
			continue
		if PreparationRules.check(fresh, registry, Enums.EquipSlot.WEAPON, weapon.id) != PreparationResult.Reason.OK:
			problems.append("journey preset %s does not pass the equipment checks" % weapon.id)
		fresh.loadout_weapon = weapon.id
		var repairs := PreparationRules.repair_loadout(fresh, registry)
		if not repairs.is_empty():
			problems.append("journey preset %s needs repairs: %s" % [weapon.id, "; ".join(repairs)])
	return problems
