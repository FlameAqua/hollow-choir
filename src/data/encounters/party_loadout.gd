class_name PartyLoadout
extends Resource
## What the party brings into battle: chosen at home (GDD core loop) or in the CombatSandbox.

const MAX_POTION_SLOTS := 2
## Most actions one party member may offer: the eight-slot grid (Adrian, 9 October 2026). A
## campaign loadout that would exceed it is rejected whole; nothing is truncated or hidden.
## UnitFactory.protagonist_actions() / companion_actions() list what is counted.
const MAX_ACTIONS := 8

@export var id: StringName = &""
@export var display_name: String = ""
@export var protagonist: ProtagonistDefinition
@export var weapon: WeaponDefinition
@export var garb: ArmorDefinition
@export var charm: ArmorDefinition
@export var relic: ArmorDefinition
## Null = protagonist fights alone (combat toy).
@export var companion: CompanionDefinition
@export var familiar: FamiliarDefinition
@export var potions: Array[PotionDefinition] = []
## V0.5B weapon fittings resolved for the equipped weapon (UnitFactory adds each one's reused trait
## to the wielder). Campaign entries capture them; Practice and the Lab leave this empty.
@export var modifications: Array[ModificationDefinition] = []
## V0.5 UI: the Hollow's arranged action ids in battle order (CombatRules resolves them for the
## campaign; encounter entries capture them). Empty = every granted action in grid order, as
## Practice, the Lab, static loadouts and entries captured before the arrangement existed use.
@export var action_ids: Array[StringName] = []
## Playtest revision (finite supplies): the doses each entry of [member potions] starts the battle
## with, by index. Campaign entries capture min(per-encounter cap, held stock). Empty (or a missing
## index) = the potion's authored charges, as Practice, the Lab and static loadouts use.
@export var potion_charges: Array[int] = []
## Playtest revision: the selected passive of [member familiar] (one of its passive_choices()).
## Null = the familiar's default passive.
@export var familiar_passive: TraitDefinition


## Resolves a saved loadout dictionary ({weapon, garb, charm, relic, companion, familiar, potions,
## optional modifications, actions, potion_charges and familiar_passive}). Unknown ids fall back to the starter weapon/protagonist
## or an empty slot; unknown fittings are skipped. Shared by the saved loadout and captured world
## encounter entries (an entry's "modifications" are the fitting ids already resolved when it was
## captured, and its "actions" the arrangement in effect then; UnitFactory keeps only granted ones).
static func from_ids(registry: DefinitionRegistry, ids: Dictionary) -> PartyLoadout:
	var fallback := registry.defaults.starter_loadout
	var loadout := PartyLoadout.new()
	loadout.id = &"saved"
	loadout.display_name = "Current loadout"
	loadout.protagonist = fallback.protagonist
	loadout.weapon = registry.weapons.get(StringName(ids.get("weapon", "")), fallback.weapon)
	loadout.garb = registry.armor.get(StringName(ids.get("garb", "")))
	loadout.charm = registry.armor.get(StringName(ids.get("charm", "")))
	loadout.relic = registry.armor.get(StringName(ids.get("relic", "")))
	loadout.companion = registry.companions.get(StringName(ids.get("companion", "")))
	loadout.familiar = registry.familiars.get(StringName(ids.get("familiar", "")))
	if loadout.familiar != null:
		var passive_id: Variant = ids.get("familiar_passive", "")
		if typeof(passive_id) in [TYPE_STRING, TYPE_STRING_NAME] and String(passive_id) != "":
			loadout.familiar_passive = loadout.familiar.passive(StringName(passive_id))
	# A captured allowance lists one whole number per saved potion id, in the same order.
	var allowance: Variant = ids.get("potion_charges")
	var potion_ids: Array = ids.get("potions", []) if typeof(ids.get("potions")) == TYPE_ARRAY else []
	var has_allowance := typeof(allowance) == TYPE_ARRAY and (allowance as Array).size() == potion_ids.size()
	for index in potion_ids.size():
		var potion: PotionDefinition = registry.potions.get(StringName(potion_ids[index]))
		if potion != null and loadout.potions.size() < MAX_POTION_SLOTS:
			loadout.potions.append(potion)
			if has_allowance:
				loadout.potion_charges.append(clampi(ProgressState.number(allowance[index], 0), 0, potion.charges))
	var modification_ids: Variant = ids.get("modifications", [])
	if typeof(modification_ids) == TYPE_ARRAY:
		for modification_id in modification_ids:
			if typeof(modification_id) != TYPE_STRING and typeof(modification_id) != TYPE_STRING_NAME:
				continue
			var modification: ModificationDefinition = registry.modifications.get(StringName(modification_id))
			if modification != null and modification.resolved_trait() != null and not loadout.modifications.has(modification):
				loadout.modifications.append(modification)
	var arranged_ids: Variant = ids.get("actions", [])
	if typeof(arranged_ids) == TYPE_ARRAY:
		for action_id in arranged_ids:
			if typeof(action_id) != TYPE_STRING and typeof(action_id) != TYPE_STRING_NAME:
				continue
			if String(action_id) != "" and not loadout.action_ids.has(StringName(action_id)):
				loadout.action_ids.append(StringName(action_id))
	return loadout


## Doses potion slot [param index] starts a battle with: the captured allowance when this loadout
## carries one, else the potion's authored charges.
func charges_for(index: int) -> int:
	if index < 0 or index >= potions.size() or potions[index] == null:
		return 0
	if index < potion_charges.size():
		return clampi(potion_charges[index], 0, potions[index].charges)
	return potions[index].charges


## The familiar passive a battle applies: the selected one, else the familiar's default (null
## without a familiar).
func familiar_trait() -> TraitDefinition:
	if familiar == null:
		return null
	if familiar_passive != null and familiar.passive_choices().has(familiar_passive):
		return familiar_passive
	return familiar.default_passive()


func equipped_armor() -> Array[ArmorDefinition]:
	var result: Array[ArmorDefinition] = []
	for item in [garb, charm, relic]:
		if item != null:
			result.append(item)
	return result


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if protagonist == null:
		problems.append("loadout %s has no protagonist" % id)
	if weapon == null:
		problems.append("loadout %s has no weapon" % id)
	if potions.size() > MAX_POTION_SLOTS:
		problems.append("loadout %s exceeds %d potion slots" % [id, MAX_POTION_SLOTS])
	if modifications.has(null):
		problems.append("loadout %s has a null fitting" % id)
	if potion_charges.size() > potions.size():
		problems.append("loadout %s lists more potion allowances than potions" % id)
	_check_slot(garb, Enums.EquipSlot.GARB, problems)
	_check_slot(charm, Enums.EquipSlot.CHARM, problems)
	_check_slot(relic, Enums.EquipSlot.RELIC, problems)
	return problems


func _check_slot(item: ArmorDefinition, expected: Enums.EquipSlot, problems: PackedStringArray) -> void:
	if item != null and item.slot != expected:
		problems.append("loadout %s has %s in the wrong slot" % [id, item.id])
