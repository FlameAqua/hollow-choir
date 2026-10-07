class_name ResonanceDefinition
extends Resource
## A two-item synergy. Active when at least two equipped items (weapon, garb, charm, relic) share
## [member tag]. The GDD forbids benefits that require more than two items or full sets.

const REQUIRED_COUNT := 2

@export var tag: Enums.ResonanceTag = Enums.ResonanceTag.NONE
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var trait_def: TraitDefinition


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if tag == Enums.ResonanceTag.NONE:
		problems.append("resonance without tag")
	if trait_def == null:
		problems.append("resonance %s has no trait" % display_name)
	else:
		problems.append_array(trait_def.validate())
	return problems
