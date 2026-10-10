class_name PotionDefinition
extends Resource
## A brewed combat consumable carried in one of the supply positions. Using it is an ITEM action.
##
## Playtest revision (finite supplies): a campaign save holds a stock of doses per potion
## (ProgressState.consumables). Brewing a Stillroom recipe adds its yield; a won encounter removes
## the doses it actually used. [member charges] is no longer a free refill: it is the most doses one
## prepared position may carry into a single encounter, and the battle starts with
## min(charges, held stock). Practice, the Lab and static loadouts never read the stock and keep
## the authored charges.

## Most doses a save may hold of one potion. A brew that would pass it is rejected whole.
const MAX_STOCK := 99

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Optional supply icon (presentation). Readouts expose its resource path; null = none yet.
@export var icon: Texture2D
## Category must be ITEM. Targets and effects live here.
@export var action: ActionDefinition
## Most doses one prepared position carries into an encounter (the per-encounter cap).
@export var charges: int = 1
## Doses a new journey starts with (and an older save receives once; SupplyRules.migrate). 0 for a
## potion that must be brewed first.
@export var starter_stock: int = 0


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
	if starter_stock < 0 or starter_stock > MAX_STOCK:
		problems.append("potion %s: starter_stock %d is outside 0-%d" % [id, starter_stock, MAX_STOCK])
	return problems
