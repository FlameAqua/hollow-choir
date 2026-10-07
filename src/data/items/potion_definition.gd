class_name PotionDefinition
extends Resource
## A brewed combat consumable carried in one of the potion slots. Using it is an ITEM action.
## Recipe data (Base + Reagent + optional Catalyst) arrives with the Stillroom milestone.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Category must be ITEM. Targets and effects live here.
@export var action: ActionDefinition
## Doses per expedition in one slot.
@export var charges: int = 1


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("potion needs id and display_name")
	if action == null:
		problems.append("potion %s has no action" % id)
	elif action.category != Enums.ActionCategory.ITEM:
		problems.append("potion %s action must use category ITEM" % id)
	if charges < 1:
		problems.append("potion %s needs charges >= 1" % id)
	return problems
