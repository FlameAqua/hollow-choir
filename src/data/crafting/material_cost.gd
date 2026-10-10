class_name MaterialCost
extends Resource
## One material line of a RecipeDefinition's price (V0.5B). The purchase write spends it whole; a
## refundable recipe returns exactly these counts. Never a reward, a drop or a hidden cost.

## Largest count a single cost line may ask for.
const MAX_COUNT := 99

@export var material: MaterialDefinition
@export var count: int = 1


## The material's id, or &"" when the reference is missing.
func material_id() -> StringName:
	return material.id if material != null else &""


func validate(recipe_id: StringName) -> PackedStringArray:
	var problems := PackedStringArray()
	if material == null:
		problems.append("recipe %s: a cost needs a material" % recipe_id)
	if count < 1 or count > MAX_COUNT:
		problems.append("recipe %s: cost count %d is outside 1-%d" % [recipe_id, count, MAX_COUNT])
	return problems
