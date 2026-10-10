class_name MaterialDefinition
extends Resource
## A salvage material (V0.5A). Saves count it per id in ProgressState.materials; later station
## recipes spend it. Public item facts only: a material never describes an enemy or species.

## Saved stacks saturate at this count. DefinitionRegistry keeps the authored rewards' total for
## each material below it, so a completed slice can never reach the cap.
const MAX_COUNT := 999

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Optional inventory icon (presentation). Readouts expose its resource path; null = none yet.
@export var icon: Texture2D
## Playtest revision: shown in the public ingredient catalog (Inventory, Stillroom, Forge) even at a
## count of zero. False keeps a material out of the catalog; it is still counted and spent.
@export var listed: bool = true
## Catalog order: lower first, then by id. Stable across saves.
@export var sort_order: int = 0


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("material needs id and display_name")
	if description.is_empty():
		problems.append("material %s needs a public description" % id)
	return problems
