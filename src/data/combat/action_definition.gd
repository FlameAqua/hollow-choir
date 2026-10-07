class_name ActionDefinition
extends Resource
## Anything a unit can do on its activation: attacks, techniques, magic, stances, items, inspect.
##
## Resolved by ActionResolver for players and enemies alike. Damage happens when [member power] > 0
## or [member uses_weapon_power] is set; effects then resolve top to bottom.

@export var id: StringName = &""
@export var display_name: String = ""
## Immediate-layer tooltip text.
@export_multiline var description: String = ""
## Extra analysis-layer text (formulas are generated automatically; this is for nuance).
@export_multiline var details: String = ""
@export var category: Enums.ActionCategory = Enums.ActionCategory.ATTACK
@export var target_rule: Enums.TargetRule = Enums.TargetRule.SINGLE_ENEMY
@export var focus_cost: int = 0
## Activations of the user before it can be used again (0 = none).
@export var cooldown: int = 0

@export_group("Damage")
## NONE with uses_weapon_power = use the wielded weapon's damage type.
@export var damage_type: Enums.DamageType = Enums.DamageType.NONE
@export var power: float = 0.0
## Scale off the wielded weapon instead of [member power] (weapon techniques).
@export var uses_weapon_power: bool = false
@export var weapon_power_multiplier: float = 1.0
@export var stagger: float = 0.0
@export var uses_weapon_stagger: bool = false
@export var weapon_stagger_multiplier: float = 1.0

@export_group("Rules")
## Basic attacks: GOOD grants Focus, PERFECT grants more (BalanceConfig).
@export var generates_focus: bool = false
@export var tags: Array[Enums.ActionTag] = []
@export var effects: Array[EffectDefinition] = []
## Null = no action command (always resolves at GOOD).
@export var command: ActionCommandDefinition

@export_group("Presentation")
## Short label for menus and the timeline (color-independent).
@export var glyph: String = ""
@export var color: Color = Color(0.85, 0.85, 0.9)


func deals_damage() -> bool:
	return power > 0.0 or uses_weapon_power


func has_tag(tag: Enums.ActionTag) -> bool:
	return tags.has(tag)


func command_type() -> Enums.ActionCommandType:
	return command.type if command != null else Enums.ActionCommandType.NONE


func targets_enemies() -> bool:
	return target_rule in [Enums.TargetRule.SINGLE_ENEMY, Enums.TargetRule.ALL_ENEMIES]


func is_area() -> bool:
	return target_rule in [Enums.TargetRule.ALL_ENEMIES, Enums.TargetRule.ALL_ALLIES]


func needs_target_choice() -> bool:
	return target_rule in [Enums.TargetRule.SINGLE_ENEMY, Enums.TargetRule.SINGLE_ALLY,
		Enums.TargetRule.OTHER_ALLY]


## Statuses this action can apply (for previews, AI and tooltips).
func applied_statuses() -> Array[Enums.StatusId]:
	var result: Array[Enums.StatusId] = []
	for effect in effects:
		if effect != null and effect.type == Enums.EffectType.APPLY_STATUS and not result.has(effect.status):
			result.append(effect.status)
	return result


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("action without id")
	if display_name.is_empty():
		problems.append("action %s has no display_name" % id)
	if focus_cost < 0:
		problems.append("action %s has negative focus_cost" % id)
	if power > 0.0 and damage_type == Enums.DamageType.NONE:
		problems.append("action %s deals damage but has no damage_type" % id)
	if command != null:
		for problem in command.validate():
			problems.append("action %s: %s" % [id, problem])
	for effect in effects:
		if effect == null:
			problems.append("action %s has a null effect" % id)
			continue
		for problem in effect.validate():
			problems.append("action %s: %s" % [id, problem])
	return problems
