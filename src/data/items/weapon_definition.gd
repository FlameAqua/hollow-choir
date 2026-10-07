class_name WeaponDefinition
extends Resource
## A horizontal choice, not a stat tier. The family defines the action-command language; the
## individual weapon modifies it through traits (timing windows, statuses, Focus, Stagger,
## reactions, environment). Rarity means mechanical complexity, never large raw-stat jumps.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_multiline var details: String = ""
@export var family: Enums.WeaponFamily = Enums.WeaponFamily.SWORD
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var damage_type: Enums.DamageType = Enums.DamageType.SLASH

@export_group("Numbers")
@export var base_power: float = 20.0
@export var base_stagger: float = 8.0
## Added to the wielder's Tempo (hammers are slow).
@export var tempo_modifier: int = 0

@export_group("Actions")
@export var basic_attack: ActionDefinition
@export var techniques: Array[ActionDefinition] = []
## Optional stance replacing the default Guard.
@export var guard_action: ActionDefinition

@export_group("Identity")
## COMMON: one identity mechanic. UNCOMMON: + socket. RARE: + socket or alternative action.
## RELIC: a unique rule-changing effect.
@export var traits: Array[TraitDefinition] = []
@export var resonance_tags: Array[Enums.ResonanceTag] = []
## Modification sockets (Forge milestone; stored now so saves stay compatible).
@export var socket_count: int = 0

## GDD: rarity must not imply gigantic raw-stat scaling. Validation fails above this spread.
const MAX_POWER_SPREAD_WITHIN_FAMILY := 0.25


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("weapon needs id and display_name")
	if basic_attack == null:
		problems.append("weapon %s has no basic_attack" % id)
	if traits.is_empty():
		problems.append("weapon %s has no identity trait (every weapon needs one mechanic)" % id)
	for trait_def in traits:
		if trait_def == null:
			problems.append("weapon %s has a null trait" % id)
		else:
			problems.append_array(trait_def.validate())
	for technique in techniques:
		if technique == null:
			problems.append("weapon %s has a null technique" % id)
	return problems
