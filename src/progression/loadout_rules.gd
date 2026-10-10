class_name LoadoutRules
extends RefCounted
## Playtest revision: the unified Loadout. Says which gear source authors each of the Hollow's
## granted actions and assembles the one readout the Loadout page presents. Attribution is truthful:
## nothing is truncated to fit a three-cell strip (the rest is listed in the Core group), no action
## is invented for an item that grants none, and the Hollow's innate magic is never assigned to a
## relic. Pure: commands stay WorldSession's (equip, arrange_action, prepare_potion, ...).

## Action cells shown beside one gear source.
const STRIP_CELLS := 3
const SOURCE_WEAPON := &"weapon"
const SOURCE_GARB := &"garb"
const SOURCE_CHARM := &"charm"
const SOURCE_RELIC := &"relic"
## The supplemental group for the stance, innate actions, Inspect and strip overflow.
const SOURCE_CORE := &"core"
const SOURCE_FAMILIAR := &"familiar"
const SOURCE_RESONANCE := &"resonance"
const ORIGIN_BASIC := &"basic"
const ORIGIN_TECHNIQUE := &"technique"
const ORIGIN_STANCE := &"stance"
const ORIGIN_INNATE := &"innate"
const ORIGIN_GRANTED := &"granted"
const ORIGIN_INSPECT := &"inspect"
const _SOURCE_OF := {Enums.EquipSlot.WEAPON: SOURCE_WEAPON, Enums.EquipSlot.GARB: SOURCE_GARB,
	Enums.EquipSlot.CHARM: SOURCE_CHARM, Enums.EquipSlot.RELIC: SOURCE_RELIC}


static func source_id(slot: Enums.EquipSlot) -> StringName:
	return _SOURCE_OF.get(slot, &"")


## Which source authors each action [param loadout]'s gear grants. Returns source id -> ordered
## [{action: ActionDefinition, origin: StringName, origin_name: String}] for the four gear sources
## and SOURCE_CORE. Every granted action (UnitFactory.granted_actions) is listed exactly once: a gear
## strip takes its source's first STRIP_CELLS authored actions, and the Core group holds the stance,
## the innate actions, Inspect and whatever a strip had no cell for.
static func sources(loadout: PartyLoadout, balance: BalanceConfig) -> Dictionary:
	var granted := UnitFactory.granted_actions(loadout, balance)
	var placed := {}
	var result := {SOURCE_WEAPON: [], SOURCE_GARB: [], SOURCE_CHARM: [], SOURCE_RELIC: [], SOURCE_CORE: []}
	var overflow: Array[Dictionary] = []
	var weapon := loadout.weapon
	var weapon_actions: Array[Dictionary] = []
	if weapon != null:
		weapon_actions.append({"action": weapon.basic_attack, "origin": ORIGIN_BASIC, "origin_name": weapon.display_name})
		for technique in weapon.techniques:
			weapon_actions.append({"action": technique, "origin": ORIGIN_TECHNIQUE, "origin_name": weapon.display_name})
	_fill(result[SOURCE_WEAPON], overflow, weapon_actions, granted, placed)
	for item in [loadout.garb, loadout.charm, loadout.relic]:
		if item == null:
			continue
		var item_actions: Array[Dictionary] = []
		for action in (item as ArmorDefinition).granted_actions:
			item_actions.append({"action": action, "origin": ORIGIN_GRANTED, "origin_name": (item as ArmorDefinition).display_name})
		_fill(result[source_id((item as ArmorDefinition).slot)], overflow, item_actions, granted, placed)
	var core: Array[Dictionary] = []
	if weapon != null and weapon.guard_action != null:
		core.append({"action": weapon.guard_action, "origin": ORIGIN_STANCE, "origin_name": weapon.display_name})
	else:
		core.append({"action": balance.default_guard_action, "origin": ORIGIN_STANCE, "origin_name": WorldCopy.COMBAT_SOURCE_COMMON})
	if loadout.protagonist != null:
		for action in loadout.protagonist.innate_actions:
			core.append({"action": action, "origin": ORIGIN_INNATE, "origin_name": loadout.protagonist.display_name})
	core.append({"action": balance.default_inspect_action, "origin": ORIGIN_INSPECT, "origin_name": WorldCopy.COMBAT_SOURCE_COMMON})
	core.append_array(overflow)
	for entry in core:
		var action: ActionDefinition = entry.action
		if action != null and granted.has(action) and not placed.has(action):
			placed[action] = true
			result[SOURCE_CORE].append(entry)
	return result


static func _fill(strip: Array, overflow: Array[Dictionary], authored: Array[Dictionary],
		granted: Array[ActionDefinition], placed: Dictionary) -> void:
	for entry in authored:
		var action: ActionDefinition = entry.action
		if action == null or not granted.has(action) or placed.has(action):
			continue
		if strip.size() < STRIP_CELLS:
			placed[action] = true
			strip.append(entry)
		else:
			overflow.append(entry)


## The source id of every granted action of [param loadout]: action id -> source id.
static func source_ids(loadout: PartyLoadout, balance: BalanceConfig) -> Dictionary:
	var result := {}
	var by_source := sources(loadout, balance)
	for source: StringName in by_source:
		for entry: Dictionary in by_source[source]:
			result[(entry.action as ActionDefinition).id] = source
	return result


## One action fact (LoadoutReadout) for [param entry] of [param source] given the current
## arrangement and the field availability [param available].
static func action_fact(entry: Dictionary, source: StringName, arranged: Array[StringName],
		available: CombatResult.Reason) -> Dictionary:
	var action: ActionDefinition = entry.action
	var position := arranged.find(action.id)
	var selectable := available == CombatResult.Reason.OK
	var reason_text := CombatResult.reason_text_for(available)
	if selectable:
		reason_text = WorldCopy.COMBAT_ARRANGED % (position + 1) if position >= 0 else WorldCopy.COMBAT_UNARRANGED
	return {"id": action.id, "name": action.display_name, "description": action.description,
		"details": action.details, "category": EnumText.category(action.category), "category_id": int(action.category),
		"focus_cost": action.focus_cost,
		"timing": EnumText.command_type(action.command.type) if action.command != null else "",
		"source_id": source, "origin": entry.origin, "origin_name": String(entry.origin_name),
		"arranged": position >= 0, "position": position, "selectable": selectable, "reason": available,
		"reason_text": reason_text}


## The action facts of gear [param slot] for [param progress] (at most STRIP_CELLS).
static func strip(progress: ProgressState, registry: DefinitionRegistry, slot: Enums.EquipSlot) -> Array[Dictionary]:
	var loadout := PartyLoadout.from_ids(registry, progress.loadout_ids())
	var arranged := CombatRules.arrangement(progress, registry)
	var available := CombatRules.availability(progress)
	var result: Array[Dictionary] = []
	for entry: Dictionary in sources(loadout, registry.balance)[source_id(slot)]:
		result.append(action_fact(entry, source_id(slot), arranged, available))
	return result


## The Loadout readout for [param progress]. [param library]: resonance definitions
## (Database.library); null lists no resonance passive.
static func readout(progress: ProgressState, registry: DefinitionRegistry, library: CombatLibrary = null) -> LoadoutReadout:
	var result := LoadoutReadout.new()
	result.reason = PreparationRules.availability(progress)
	result.reason_text = PreparationResult.reason_text(result.reason)
	var loadout := PreparationRules.campaign_loadout(progress, registry)
	var by_source := sources(loadout, registry.balance)
	var available := CombatRules.availability(progress)
	result.capacity = CombatRules.capacity(progress, registry)
	result.arranged = CombatRules.arrangement(progress, registry)
	for slot in PreparationRules.SLOTS:
		result.gear.append(PreparationRules.slot_readout(progress, registry, slot, result.reason))
	var owners := {}
	for source: StringName in by_source:
		for entry: Dictionary in by_source[source]:
			var fact := action_fact(entry, source, result.arranged, available)
			owners[fact.id] = source
			if source == SOURCE_CORE:
				result.core.append(fact)
			if not fact.arranged:
				result.unarranged.append(fact.id)
	for index in CombatRules.POSITIONS:
		var locked := index >= result.capacity
		var action_id: StringName = result.arranged[index] if index < result.arranged.size() else &""
		result.positions.append({"index": index, "locked": locked,
			"reason": CombatResult.Reason.LOCKED_POSITION if locked else CombatResult.Reason.OK,
			"reason_text": WorldCopy.COMBAT_LOCKED_POSITION if locked else "",
			"action_id": action_id, "source_id": owners.get(action_id, &"")})
	result.familiar = FamiliarRules.readout(progress, registry)
	result.supplies = SupplyRules.slot_readouts(progress, registry, CraftingRules.field_availability(progress))
	result.passives = passives(loadout, library)
	for weapon in PreparationRules.owned_items(progress, registry, Enums.EquipSlot.WEAPON):
		var icon: Texture2D = weapon.get("icon")
		result.mastery.append({"id": weapon.get("id"), "name": String(weapon.get("display_name")),
			"icon_path": icon.resource_path if icon != null else "",
			"points": int(progress.weapon_mastery.get(weapon.get("id"), 0))})
	var inventory := PreparationRules.inventory(progress, registry)
	result.ingredients = inventory.ingredients
	result.equipment_capacity = inventory.equipment_capacity
	return result


## The passives [param loadout]'s next battle applies, in the order UnitFactory adds them: weapon
## traits, the active fitting, armor traits, active resonances and the familiar's selected passive.
static func passives(loadout: PartyLoadout, library: CombatLibrary = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weapon := loadout.weapon
	if weapon != null:
		for trait_def in weapon.traits:
			_passive(result, trait_def, &"gear", SOURCE_WEAPON, weapon.display_name)
		for modification in loadout.modifications:
			if modification != null:
				_passive(result, modification.resolved_trait(), &"fitting", SOURCE_WEAPON, UnitFactory.fitting_source(weapon))
	for item in loadout.equipped_armor():
		for trait_def in item.traits:
			_passive(result, trait_def, &"gear", source_id(item.slot), item.display_name)
	if library != null:
		for resonance in UnitFactory.active_resonances(library, loadout):
			_passive(result, resonance.trait_def, &"resonance", SOURCE_RESONANCE, resonance.display_name)
	if loadout.familiar != null:
		_passive(result, loadout.familiar_trait(), &"familiar", SOURCE_FAMILIAR, loadout.familiar.display_name)
	return result


static func _passive(result: Array[Dictionary], trait_def: TraitDefinition, kind: StringName, source: StringName,
		source_name: String) -> void:
	if trait_def != null:
		result.append({"id": trait_def.id, "name": trait_def.display_name, "description": trait_def.description,
			"details": trait_def.details, "kind": kind, "source_id": source, "source_name": source_name})
