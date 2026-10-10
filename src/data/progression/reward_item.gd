class_name RewardItem
extends Resource
## One grant inside a RewardDefinition (V0.5A). MATERIAL adds [member count] to that material's
## saved stack. EQUIPMENT adds a weapon or armor definition to owned equipment once (count 1); an
## item that is already owned is never duplicated. Potions and other consumables are not reward
## kinds: persistent potion inventory is not part of the slice.

enum Kind { MATERIAL = 0, EQUIPMENT = 1 }

## Largest count a single item may grant.
const MAX_COUNT := 99

@export var kind: Kind = Kind.MATERIAL
## MATERIAL only.
@export var material: MaterialDefinition
## EQUIPMENT only: a WeaponDefinition or ArmorDefinition.
@export var equipment: Resource
@export var count: int = 1


## The granted definition's id, or &"" when the reference is missing or of the wrong type.
func item_id() -> StringName:
	match kind:
		Kind.MATERIAL:
			return material.id if material != null else &""
		Kind.EQUIPMENT:
			if equipment is WeaponDefinition:
				return (equipment as WeaponDefinition).id
			if equipment is ArmorDefinition:
				return (equipment as ArmorDefinition).id
	return &""


func validate(reward_id: StringName) -> PackedStringArray:
	var problems := PackedStringArray()
	match kind:
		Kind.MATERIAL:
			if material == null:
				problems.append("reward %s: a material item needs a material" % reward_id)
			if equipment != null:
				problems.append("reward %s: a material item cannot also name equipment" % reward_id)
			if count < 1 or count > MAX_COUNT:
				problems.append("reward %s: material count %d is outside 1-%d" % [reward_id, count, MAX_COUNT])
		Kind.EQUIPMENT:
			if not (equipment is WeaponDefinition or equipment is ArmorDefinition):
				problems.append("reward %s: an equipment item must be a weapon or armor definition" % reward_id)
			if material != null:
				problems.append("reward %s: an equipment item cannot also name a material" % reward_id)
			if count != 1:
				problems.append("reward %s: equipment is granted once (count must be 1, not %d)" % [reward_id, count])
		_:
			problems.append("reward %s: unknown item kind %d" % [reward_id, kind])
	return problems
