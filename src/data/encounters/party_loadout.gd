class_name PartyLoadout
extends Resource
## What the party brings into battle: chosen at home (GDD core loop) or in the CombatSandbox.

const MAX_POTION_SLOTS := 2

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


## Resolves a saved loadout dictionary ({weapon, garb, charm, relic, companion, familiar, potions}).
## Unknown ids fall back to the starter weapon/protagonist or an empty slot. Shared by the saved
## loadout and captured world encounter entries.
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
	for potion_id in ids.get("potions", []):
		var potion: PotionDefinition = registry.potions.get(StringName(potion_id))
		if potion != null and loadout.potions.size() < MAX_POTION_SLOTS:
			loadout.potions.append(potion)
	return loadout


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
	_check_slot(garb, Enums.EquipSlot.GARB, problems)
	_check_slot(charm, Enums.EquipSlot.CHARM, problems)
	_check_slot(relic, Enums.EquipSlot.RELIC, problems)
	return problems


func _check_slot(item: ArmorDefinition, expected: Enums.EquipSlot, problems: PackedStringArray) -> void:
	if item != null and item.slot != expected:
		problems.append("loadout %s has %s in the wrong slot" % [id, item.id])
