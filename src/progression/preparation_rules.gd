class_name PreparationRules
extends RefCounted
## V0.5A campaign preparation: ownership-aware choices for the weapon, garb, charm and relic slots,
## the party's action ceiling, compatibility repair of an older saved loadout and the typed
## equipment and inventory readouts. Pure: the caller passes the progress and the registry
## (WorldSession owns the writes).
##
## V0.5B: the loadout an encounter captures is the saved loadout plus the fittings resolved for the
## equipped weapon (campaign_ids / battle_ids); equipment checks also reject a duplicated fitting
## trait, and reconciliation runs CraftingRules.repair after the equipment repair.
##
## V0.5 UI: equipment is a field command (Character, outside a pending or active encounter; no
## station). battle_ids also carries the Hollow's combat arrangement (CombatRules); the action
## ceiling still applies to every action the gear grants, independent of the arrangement capacity.
##
## Playtest revision: battle_ids also carries the supply allowance (SupplyRules: min(per-encounter
## cap, held stock) per prepared position) and the familiar's selected passive; slot readouts name
## their source and the actions it authors (LoadoutRules); inventory() publishes the complete
## ingredient catalog and the drawn bag cells.
##
## Campaign only. Practice, the Lab and static fixtures keep building loadouts with
## PartyLoadout.from_ids() and may still audition unearned content.

const SLOTS: Array[Enums.EquipSlot] = [Enums.EquipSlot.WEAPON, Enums.EquipSlot.GARB, Enums.EquipSlot.CHARM,
	Enums.EquipSlot.RELIC]
const STARTING_EQUIPMENT_CAPACITY := 10
const _KEYS := {Enums.EquipSlot.WEAPON: "weapon", Enums.EquipSlot.GARB: "garb", Enums.EquipSlot.CHARM: "charm",
	Enums.EquipSlot.RELIC: "relic"}


## Would a field preparation command (equipment, prepared supplies) run now? Anywhere outside a
## pending or active encounter, whose captured entry is never rebuilt. No station context is needed
## or consulted (V0.5 UI); NO_STATION is never returned.
static func availability(progress: ProgressState) -> PreparationResult.Reason:
	if progress.world.pending_entry != null:
		return PreparationResult.Reason.ENCOUNTER_PENDING
	return PreparationResult.Reason.OK


## Item checks for putting [param item_id] in [param slot] (&"" empties the slot): approved content,
## the right slot, owned, no fitting trait carried twice (V0.5B) and the whole new loadout, fittings
## included, within PartyLoadout.MAX_ACTIONS.
static func check(progress: ProgressState, registry: DefinitionRegistry, slot: Enums.EquipSlot,
		item_id: StringName) -> PreparationResult.Reason:
	if item_id == &"":
		return PreparationResult.Reason.REQUIRED_SLOT if slot == Enums.EquipSlot.WEAPON else PreparationResult.Reason.OK
	var item := find(registry, item_id)
	if item == null:
		return PreparationResult.Reason.UNKNOWN_ITEM
	if slot_of(item) != slot:
		return PreparationResult.Reason.WRONG_SLOT
	if not progress.owned_equipment.has(item_id):
		return PreparationResult.Reason.NOT_OWNED
	var ids := campaign_ids(progress, registry, with_item(progress.loadout_ids(), slot, item_id), progress.weapon_fittings)
	if CraftingRules.duplicate_trait(ids, registry) != &"":
		return PreparationResult.Reason.DUPLICATE_TRAIT
	if not fits(ids, registry):
		return PreparationResult.Reason.ACTION_LIMIT
	return PreparationResult.Reason.OK


## Puts [param item_id] in [param slot] (already checked; &"" empties an armor slot).
static func apply(progress: ProgressState, slot: Enums.EquipSlot, item_id: StringName) -> void:
	match slot:
		Enums.EquipSlot.WEAPON:
			progress.loadout_weapon = item_id
		Enums.EquipSlot.GARB:
			progress.loadout_garb = item_id
		Enums.EquipSlot.CHARM:
			progress.loadout_charm = item_id
		Enums.EquipSlot.RELIC:
			progress.loadout_relic = item_id


static func equipped(progress: ProgressState, slot: Enums.EquipSlot) -> StringName:
	match slot:
		Enums.EquipSlot.GARB:
			return progress.loadout_garb
		Enums.EquipSlot.CHARM:
			return progress.loadout_charm
		Enums.EquipSlot.RELIC:
			return progress.loadout_relic
	return progress.loadout_weapon


## The approved weapon or armor definition for [param item_id], or null.
static func find(registry: DefinitionRegistry, item_id: StringName) -> Resource:
	if registry.weapons.has(item_id):
		return registry.weapons[item_id]
	return registry.armor.get(item_id)


## The slot an approved item fits (-1 for anything else).
static func slot_of(item: Resource) -> int:
	if item is WeaponDefinition:
		return Enums.EquipSlot.WEAPON
	if item is ArmorDefinition:
		return (item as ArmorDefinition).slot
	return -1


## Owned, approved items fitting [param slot] in a stable order: weapons by family, rarity and id
## (so the three starters keep their V0.4 bench order), armor by rarity and id.
static func owned_items(progress: ProgressState, registry: DefinitionRegistry, slot: Enums.EquipSlot) -> Array[Resource]:
	var result: Array[Resource] = []
	for item_id in progress.owned_equipment:
		var item := find(registry, item_id)
		if item != null and slot_of(item) == slot and not result.has(item):
			result.append(item)
	result.sort_custom(_before)
	return result


static func _before(a: Resource, b: Resource) -> bool:
	if a is WeaponDefinition and b is WeaponDefinition:
		var first := a as WeaponDefinition
		var second := b as WeaponDefinition
		if first.family != second.family:
			return first.family < second.family
		if first.rarity != second.rarity:
			return first.rarity < second.rarity
		return String(first.id) < String(second.id)
	if int(a.get("rarity")) != int(b.get("rarity")):
		return int(a.get("rarity")) < int(b.get("rarity"))
	return String(a.get("id")) < String(b.get("id"))


## A copy of the loadout ids [param ids] with [param slot] set to [param item_id].
static func with_item(ids: Dictionary, slot: Enums.EquipSlot, item_id: StringName) -> Dictionary:
	var result := ids.duplicate(true)
	result[_KEYS[slot]] = String(item_id)
	return result


## Saved-shape loadout ids [param ids] plus "modifications": the fitting ids that take effect on
## its weapon under [param fittings] (weapon id -> fitting id), resolved by CraftingRules. This is
## the campaign loadout every check, readout and encounter capture uses.
static func campaign_ids(progress: ProgressState, registry: DefinitionRegistry, ids: Dictionary,
		fittings: Dictionary) -> Dictionary:
	var result := ids.duplicate(true)
	var modifications := []
	for modification in CraftingRules.active_modifications(progress, registry, StringName(result.get("weapon", "")),
			fittings):
		modifications.append(String(modification.id))
	result["modifications"] = modifications
	return result


## The ids the next EncounterEntry captures for [param progress]: the saved loadout (the familiar's
## selected passive included), the active fittings, (V0.5 UI) "actions", the Hollow's combat
## arrangement in battle order, and (playtest revision) "potion_charges", the supply allowance:
## one whole number per saved potion id, min(per-encounter cap, held stock).
static func battle_ids(progress: ProgressState, registry: DefinitionRegistry) -> Dictionary:
	var ids := campaign_ids(progress, registry, progress.loadout_ids(), progress.weapon_fittings)
	var actions := []
	for action_id in CombatRules.arrangement(progress, registry):
		actions.append(String(action_id))
	ids["actions"] = actions
	ids["potion_charges"] = Array(SupplyRules.allowance(progress, registry))
	ids["familiar_passive"] = String(FamiliarRules.passive_id(progress, registry))
	return ids


## The campaign PartyLoadout of [param progress], built exactly as its next encounter builds it.
static func campaign_loadout(progress: ProgressState, registry: DefinitionRegistry) -> PartyLoadout:
	return PartyLoadout.from_ids(registry, battle_ids(progress, registry))


## {"protagonist": int, "companion": int}: the actions each party member would have in battle with
## the loadout ids [param ids], resolved exactly as an EncounterEntry resolves them (with "actions",
## the arranged ones; without, every granted action).
static func action_counts(ids: Dictionary, registry: DefinitionRegistry) -> Dictionary:
	var loadout := PartyLoadout.from_ids(registry, ids)
	var counts := {"protagonist": UnitFactory.protagonist_actions(loadout, registry.balance).size(), "companion": 0}
	if loadout.companion != null:
		counts.companion = UnitFactory.companion_actions(loadout.companion, registry.balance).size()
	return counts


## The engine ceiling: every action the gear in [param ids] grants a party member (arranged or not)
## fits PartyLoadout.MAX_ACTIONS. Independent of the combat arrangement's capacity.
static func fits(ids: Dictionary, registry: DefinitionRegistry) -> bool:
	var loadout := PartyLoadout.from_ids(registry, ids)
	if UnitFactory.granted_actions(loadout, registry.balance).size() > PartyLoadout.MAX_ACTIONS:
		return false
	if loadout.companion == null:
		return true
	return UnitFactory.companion_actions(loadout.companion, registry.balance).size() <= PartyLoadout.MAX_ACTIONS


## Compatibility repair of the saved equipment loadout (run by WorldSession.reconcile, never by a
## deserializer). Approved gear in its own slot that the save does not list as owned becomes owned:
## older tooling did not always fill ownership, and a player's loadout is never stripped for that.
## An unknown or wrong-slot armor id is unequipped. An unknown or wrong-slot weapon id is replaced by
## the starter loadout's weapon when owned, else the first owned weapon. Unknown ids are never
## grandfathered. V0.5B: then CraftingRules.repair (potion slots, a duplicated fitting trait).
## Playtest revision: then FamiliarRules.repair (the travelling familiar and its passive). The
## one-time supply migration is separate (SupplyRules.migrate; WorldSession.reconcile runs both).
## Returns one line per repair in slot order; empty when nothing changed.
static func repair_loadout(progress: ProgressState, registry: DefinitionRegistry) -> PackedStringArray:
	var repairs := PackedStringArray()
	for slot in SLOTS:
		var item_id := equipped(progress, slot)
		if item_id == &"" and slot != Enums.EquipSlot.WEAPON:
			continue
		var label := EnumText.equip_slot(slot).to_lower()
		var item := find(registry, item_id)
		if item != null and slot_of(item) == slot:
			if not progress.owned_equipment.has(item_id):
				progress.owned_equipment.append(item_id)
				repairs.append("equipped %s %s was not listed as owned; it is owned now" % [label, item_id])
			continue
		if slot == Enums.EquipSlot.WEAPON:
			var replacement := _safe_weapon(progress, registry)
			apply(progress, slot, replacement)
			if not progress.owned_equipment.has(replacement):
				progress.owned_equipment.append(replacement)
			repairs.append("weapon '%s' is not approved weapon content; %s is equipped instead" % [item_id, replacement])
		else:
			apply(progress, slot, &"")
			repairs.append("%s '%s' is not approved %s content; the slot is empty now" % [label, item_id, label])
	repairs.append_array(CraftingRules.repair(progress, registry))
	repairs.append_array(CombatRules.repair(progress, registry))
	repairs.append_array(FamiliarRules.repair(progress, registry))
	return repairs


## The starter loadout's weapon when owned, else the first owned weapon, else the starter weapon.
static func _safe_weapon(progress: ProgressState, registry: DefinitionRegistry) -> StringName:
	var starter := registry.defaults.starter_loadout.weapon.id
	if progress.owned_equipment.has(starter):
		return starter
	var owned := owned_items(progress, registry, Enums.EquipSlot.WEAPON)
	return (owned[0] as WeaponDefinition).id if not owned.is_empty() else starter


# --- Readouts ------------------------------------------------------------------------------------

## The equipment readout for the live save: field availability (V0.5 UI: no station), the action
## counts and one slot readout per equipment slot.
static func readout(progress: ProgressState, registry: DefinitionRegistry) -> PreparationReadout:
	var result := PreparationReadout.new()
	result.reason = availability(progress)
	result.reason_text = PreparationResult.reason_text(result.reason)
	var counts := action_counts(battle_ids(progress, registry), registry)
	result.protagonist_actions = counts.protagonist
	result.companion_actions = counts.companion
	result.granted_actions = granted_count(progress.loadout_ids(), registry)
	result.combat_capacity = CombatRules.capacity(progress, registry)
	for slot in SLOTS:
		result.slots.append(slot_readout(progress, registry, slot, result.reason))
	return result


## Every action the gear in [param ids] grants the Hollow (the count held to the engine ceiling).
static func granted_count(ids: Dictionary, registry: DefinitionRegistry) -> int:
	return UnitFactory.granted_actions(PartyLoadout.from_ids(registry, ids), registry.balance).size()


## One slot: what is equipped and every owned item that fits, with the reason a command would
## return now ([param available] is the field availability).
static func slot_readout(progress: ProgressState, registry: DefinitionRegistry, slot: Enums.EquipSlot,
		available: PreparationResult.Reason) -> EquipmentSlotReadout:
	var result := EquipmentSlotReadout.new()
	result.slot = slot
	result.label = EnumText.equip_slot(slot)
	result.source_id = LoadoutRules.source_id(slot)
	result.optional = slot != Enums.EquipSlot.WEAPON
	result.equipped_id = equipped(progress, slot)
	var current := find(registry, result.equipped_id)
	if current != null and slot_of(current) == slot:
		result.equipped_name = String(current.get("display_name"))
		var icon: Texture2D = current.get("icon")
		result.icon_path = icon.resource_path if icon != null else ""
	result.actions = LoadoutRules.strip(progress, registry, slot)
	result.can_remove = result.optional and result.equipped_id != &"" and available == PreparationResult.Reason.OK
	for item in owned_items(progress, registry, slot):
		var reason := available
		if reason == PreparationResult.Reason.OK:
			reason = check(progress, registry, slot, item.get("id"))
		result.options.append(_option(progress, registry, slot, item, reason))
	return result


static func _option(progress: ProgressState, registry: DefinitionRegistry, slot: Enums.EquipSlot, item: Resource,
		reason: PreparationResult.Reason) -> Dictionary:
	var id: StringName = item.get("id")
	var entry := {
		"id": id,
		"name": String(item.get("display_name")),
		"icon_path": (item.get("icon") as Texture2D).resource_path if item.get("icon") != null else "",
		"description": String(item.get("description")),
		"details": String(item.get("details")),
		"category": EnumText.equip_slot(slot),
		"rarity": EnumText.rarity(int(item.get("rarity"))),
		"equipped": equipped(progress, slot) == id,
		"selectable": reason == PreparationResult.Reason.OK,
		"reason": reason,
		"reason_text": PreparationResult.reason_text(reason),
		"actions": granted_count(with_item(progress.loadout_ids(), slot, id), registry),
		"combat": arrangement_preview(progress, registry, slot, id),
		"traits": [],
		"grants": [],
		"resonance": PackedStringArray(),
	}
	for trait_def: TraitDefinition in item.get("traits"):
		if trait_def != null:
			entry.traits.append({"name": trait_def.display_name, "description": trait_def.description})
	var grants: Array[ActionDefinition] = []
	if item is WeaponDefinition:
		var weapon := item as WeaponDefinition
		entry.category = "%s · %s" % [EnumText.family(weapon.family), EnumText.damage_type(weapon.damage_type)]
		grants.append(weapon.basic_attack)
		grants.append_array(weapon.techniques)
		grants.append(weapon.guard_action)
	else:
		grants.append_array((item as ArmorDefinition).granted_actions)
	for action in grants:
		if action != null:
			entry.grants.append({"name": action.display_name, "description": action.description})
	for tag: int in item.get("resonance_tags"):
		entry.resonance.append(EnumText.resonance(tag))
	return entry


## How equipping [param item_id] in [param slot] would change the combat arrangement (the same
## reconciliation the command writes): {"removed": [{id, name, position}], "added": [...],
## "kept": [...]}; removed and added are empty when the arrangement keeps every action.
static func arrangement_preview(progress: ProgressState, registry: DefinitionRegistry, slot: Enums.EquipSlot,
		item_id: StringName) -> Dictionary:
	var before := CombatRules.arrangement(progress, registry)
	var probe := ProgressState.from_dict(progress.to_dict())
	apply(probe, slot, item_id)
	var after := CombatRules.resolve(before, CombatRules.ids_of(CombatRules.candidates(probe, registry)),
		CombatRules.capacity(probe, registry))
	return CombatRules.changes(before, after, CombatRules.names(progress, registry), CombatRules.names(probe, registry))


## Held materials (approved, positive counts, by id), the public ingredient catalog (zero counts
## included) and owned approved equipment.
static func inventory(progress: ProgressState, registry: DefinitionRegistry) -> InventoryReadout:
	var result := InventoryReadout.new()
	result.equipment_capacity = STARTING_EQUIPMENT_CAPACITY
	for claim_id in registry.sorted_ids(registry.rewards):
		if progress.has_claim(claim_id):
			result.equipment_capacity += registry.rewards[claim_id].equipment_slots
	result.cells_locked_text = WorldCopy.BAG_LOCKED_CELL
	result.materials = held_materials(progress, registry)
	result.ingredients = ingredient_catalog(progress, registry)
	for slot in SLOTS:
		for item in owned_items(progress, registry, slot):
			var id: StringName = item.get("id")
			var reason := availability(progress)
			if reason == PreparationResult.Reason.OK:
				reason = check(progress, registry, slot, id)
			var entry := _option(progress, registry, slot, item, reason)
			entry.slot = slot
			entry.slot_label = EnumText.equip_slot(slot)
			entry.mastery = progress.weapon_mastery.get(id, 0)
			result.equipment.append(entry)
	return result


## The public ingredient catalog (playtest revision): every listed approved material in a stable
## order (sort_order, then id), with the save's count, zero included: [{id, name, description,
## icon_path, count, held}]. Catalog visibility is authored (MaterialDefinition.listed); holding is
## the save's. Unknown saved ids never appear, and nothing here is spent or derived by a widget.
static func ingredient_catalog(progress: ProgressState, registry: DefinitionRegistry) -> Array[Dictionary]:
	var listed: Array[MaterialDefinition] = []
	for id in registry.sorted_ids(registry.materials):
		var material: MaterialDefinition = registry.materials[id]
		if material.listed:
			listed.append(material)
	listed.sort_custom(func(a: MaterialDefinition, b: MaterialDefinition) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return String(a.id) < String(b.id))
	var result: Array[Dictionary] = []
	for material in listed:
		var count := progress.material_count(material.id)
		result.append({"id": material.id, "name": material.display_name, "description": material.description,
			"icon_path": material.icon.resource_path if material.icon != null else "", "count": count,
			"held": count > 0})
	return result


## Held approved materials with a positive count, by id: [{id, name, description, icon_path, count}].
static func held_materials(progress: ProgressState, registry: DefinitionRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in registry.sorted_ids(registry.materials):
		var count := progress.material_count(id)
		if count <= 0:
			continue
		var material: MaterialDefinition = registry.materials[id]
		result.append({"id": id, "name": material.display_name, "description": material.description,
			"icon_path": material.icon.resource_path if material.icon != null else "", "count": count})
	return result
