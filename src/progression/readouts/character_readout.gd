class_name CharacterReadout
extends RefCounted
## Saved character facts, sourced from the same loadout/action factory used by combat.
## V0.5 UI: actions and magic list every action the campaign gear grants (CombatRules decides which
## of them hold a combat position); skills add the authored passives the battle also applies:
## active resonance synergies and the familiar's trait. Nothing here is inferred or invented.
var name := ""
var actions: Array[Dictionary] = []
var magic: Array[Dictionary] = []
var skills: Array[Dictionary] = []


## [param library]: resonance definitions (Database.library); null lists no resonance passives.
static func build(progress: ProgressState, registry: DefinitionRegistry, library: CombatLibrary = null) -> CharacterReadout:
	var result := CharacterReadout.new()
	var loadout := PreparationRules.campaign_loadout(progress, registry)
	result.name = loadout.protagonist.display_name
	for action in UnitFactory.granted_actions(loadout, registry.balance):
		var entry := {"id": action.id, "name": action.display_name, "description": action.description,
			"category": EnumText.category(action.category), "category_id": int(action.category),
			"details": action.details, "action_id": action.id, "focus_cost": action.focus_cost,
			"timing": EnumText.command_type(action.command.type) if action.command != null else "",
			"source": source_of(action, loadout, registry.balance),
			"facts": PackedStringArray(["Focus cost  %d" % action.focus_cost]),
			"extra": PackedStringArray(["Timing  " + EnumText.command_type(action.command.type) if action.command != null else "No timing command"])}
		if action.category == Enums.ActionCategory.MAGIC:
			result.magic.append(entry)
		else:
			result.actions.append(entry)
	for weapon in PreparationRules.owned_items(progress, registry, Enums.EquipSlot.WEAPON):
		var icon: Texture2D = weapon.get("icon")
		result.skills.append({"id": weapon.get("id"), "name": String(weapon.get("display_name")),
			"description": "Weapon mastery grows when you use this weapon in battle. Perfect actions count double.",
			"category": "Weapon mastery", "icon_path": icon.resource_path if icon != null else "",
			"facts": PackedStringArray(["Mastery points  %d" % progress.weapon_mastery.get(weapon.get("id"), 0)]),
			"extra": PackedStringArray(["Mastery stays with this weapon when you change equipment."])})
	var gear: Array[Resource] = [loadout.weapon]
	gear.append_array(loadout.equipped_armor())
	for item in gear:
		for trait_def: TraitDefinition in item.get("traits"):
			result.skills.append(_passive(trait_def, "Passive · " + String(item.get("display_name")),
				"Active while this item is equipped."))
	# V0.5B: an active weapon fitting's reused trait (the same list the next encounter builds).
	for modification in loadout.modifications:
		var fitted := modification.resolved_trait()
		if fitted != null:
			result.skills.append(_passive(fitted, "Passive · " + UnitFactory.fitting_source(loadout.weapon),
				"Active while this fitting is installed and its weapon is equipped."))
	# V0.5 UI: the authored two-item synergies and the familiar's trait UnitFactory also applies.
	if library != null:
		for resonance in UnitFactory.active_resonances(library, loadout):
			result.skills.append(_passive(resonance.trait_def, "Resonance · " + resonance.display_name,
				"Active while two equipped items share this resonance."))
	# Playtest revision: the familiar's selected passive (its only one for today's familiars).
	if loadout.familiar != null and loadout.familiar_trait() != null:
		result.skills.append(_passive(loadout.familiar_trait(), "Familiar · " + loadout.familiar.display_name,
			"Active while this familiar travels with the party."))
	return result


static func _passive(trait_def: TraitDefinition, category: String, rule: String) -> Dictionary:
	return {"id": trait_def.id, "name": trait_def.display_name, "description": trait_def.description,
		"category": category, "icon_id": "action_empower", "passive": true,
		"extra": PackedStringArray([rule, trait_def.details])}


## What grants [param action] in [param loadout]: the weapon, the protagonist, an armor item, or
## "Every party member" for the shared default Guard and Inspect.
static func source_of(action: ActionDefinition, loadout: PartyLoadout, balance: BalanceConfig) -> String:
	var weapon := loadout.weapon
	if weapon != null and (action == weapon.basic_attack or weapon.techniques.has(action) or action == weapon.guard_action):
		return weapon.display_name
	if loadout.protagonist != null and loadout.protagonist.innate_actions.has(action):
		return loadout.protagonist.display_name
	for item in loadout.equipped_armor():
		if item.granted_actions.has(action):
			return item.display_name
	if action == balance.default_guard_action or action == balance.default_inspect_action:
		return WorldCopy.COMBAT_SOURCE_COMMON
	return ""
