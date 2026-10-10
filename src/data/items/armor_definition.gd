class_name ArmorDefinition
extends Resource
## Garb, Charm or Relic. Mostly supplies rules ("Brace generates Focus"), not stat padding.

@export var id: StringName = &""
@export var display_name: String = ""
## Optional inventory art; never participates in combat rules.
@export var icon: Texture2D
@export_multiline var description: String = ""
@export_multiline var details: String = ""
@export var slot: Enums.EquipSlot = Enums.EquipSlot.GARB
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var traits: Array[TraitDefinition] = []
## Actions this item teaches while equipped (e.g. a charm granting a spell).
@export var granted_actions: Array[ActionDefinition] = []
@export var resonance_tags: Array[Enums.ResonanceTag] = []


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("armor needs id and display_name")
	if slot == Enums.EquipSlot.WEAPON:
		problems.append("armor %s cannot use the WEAPON slot" % id)
	if traits.is_empty() and granted_actions.is_empty():
		problems.append("armor %s does nothing (needs a trait or granted action)" % id)
	for trait_def in traits:
		if trait_def == null:
			problems.append("armor %s has a null trait" % id)
		else:
			problems.append_array(trait_def.validate())
	return problems
