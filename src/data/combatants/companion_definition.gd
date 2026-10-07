class_name CompanionDefinition
extends CombatantDefinition
## A recruitable companion: basic action, two core techniques, a passive identity.
## Relationship upgrades and the personal story arc are later milestones.

@export var basic_action: ActionDefinition
@export var techniques: Array[ActionDefinition] = []
## Optional stance replacing the default Guard.
@export var guard_action: ActionDefinition
## For conditions such as WEAPON_FAMILY_IS (companions wield a fixed weapon).
@export var weapon_family: Enums.WeaponFamily = Enums.WeaponFamily.NONE
@export var weapon_damage_type: Enums.DamageType = Enums.DamageType.PIERCE
@export var weapon_power: float = 18.0
@export var weapon_stagger: float = 8.0
## Identity passive (owner = the companion).
@export var passive: TraitDefinition
## How this character embodies a response to the central theme (writing guide, shown in codex).
@export_multiline var theme_statement: String = ""


func validate() -> PackedStringArray:
	var problems := super.validate()
	if basic_action == null:
		problems.append("companion %s has no basic_action" % id)
	if techniques.size() != 2:
		problems.append("companion %s should have exactly 2 core techniques (GDD)" % id)
	if passive == null:
		problems.append("companion %s has no passive identity" % id)
	return problems
