class_name RecipeDefinition
extends Resource
## One home-station recipe (V0.5B). Spending, mastery, ownership and what each kind produces are
## pure rules in CraftingRules and SupplyRules; prices, yields and thresholds are Director data
## here, and no code names them.
##
## Playtest revision: a POTION recipe is brewed any number of times (each brew spends [member costs]
## and adds [member yield_count] doses to the saved stock), and each fitting is crafted on its own
## through a FITTING recipe. The FITTING_KIT kind remains only so that a save that bought a kit
## keeps what it paid for; it can no longer be bought.

enum Station { FORGE = 0, STILLROOM = 1 }

enum Kind {
	## Legacy (before the playtest revision): gave [member weapon] a choice of [member fittings].
	## A save that owns one keeps every listed fitting and may still reclaim it for [member costs]
	## (clearing the installed fitting in the same write). Never purchasable again.
	FITTING_KIT = 0,
	## Brews [member potion]: spends [member costs] and adds [member yield_count] doses to the
	## save's stock. Repeatable and permanent (no refund). Preparing a position is a separate choice.
	POTION = 1,
	## Crafts the one fitting in [member fittings] for [member weapon]: owned permanently by
	## [member id] in ProgressState.crafting_recipes, then fitted and removed for free at the Forge.
	FITTING = 2,
}

## Most doses a single brew may yield.
const MAX_YIELD := 20

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var station: Station = Station.FORGE
@export var kind: Kind = Kind.FITTING_KIT
## The whole price, spent in the write that brews or crafts. For a POTION recipe this is its Reagent.
@export var costs: Array[MaterialCost] = []
## Reclaiming returns exactly [member costs] (legacy FITTING_KIT only).
@export var refundable: bool = false

@export_group("Mastery")
## Needs at least this many saved mastery points on any one owned weapon listed in
## [member mastery_weapons] (0 = no requirement). Reads ProgressState.weapon_mastery as saved.
@export var mastery_points: int = 0
@export var mastery_weapons: Array[WeaponDefinition] = []

@export_group("Fitting")
## FITTING / FITTING_KIT: the weapon that takes the fitting, and the fitting (FITTING: exactly one;
## FITTING_KIT: every choice the kit offered).
@export var weapon: WeaponDefinition
@export var fittings: Array[ModificationDefinition] = []

@export_group("Potion recipe")
## POTION only: the existing potion this recipe brews (its effects and per-encounter cap are
## unchanged).
@export var potion: PotionDefinition
## POTION only: doses one brew adds to the stock.
@export var yield_count: int = 1
## POTION only: the public Base, a reusable home supply ("Prepared salve"). Never a saved material
## stack or a hidden cost. The Reagent is [member costs]; V0.5B recipes have no Catalyst.
@export var base_name: String = ""
@export_multiline var base_description: String = ""


## Self-contained checks. Registry references and the route budget: CraftingRules.validate_catalog().
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not RewardDefinition.is_valid_id(id):
		problems.append("recipe id '%s' must be lowercase dotted words (a-z, 0-9, _), at most %d characters" % [
			id, RewardDefinition.MAX_ID_LENGTH])
	if display_name.is_empty() or description.is_empty():
		problems.append("recipe %s needs a public display_name and description" % id)
	if not Station.values().has(station):
		problems.append("recipe %s has an unknown station %d" % [id, station])
	if costs.is_empty():
		problems.append("recipe %s costs nothing (every recipe has a price)" % id)
	var seen := {}
	for cost in costs:
		if cost == null:
			problems.append("recipe %s has a null cost" % id)
			continue
		problems.append_array(cost.validate(id))
		if cost.material_id() != &"" and seen.has(cost.material_id()):
			problems.append("recipe %s lists %s twice" % [id, cost.material_id()])
		seen[cost.material_id()] = true
	if mastery_points < 0:
		problems.append("recipe %s: mastery_points cannot be negative" % id)
	if mastery_points > 0 and (mastery_weapons.is_empty() or mastery_weapons.has(null)):
		problems.append("recipe %s: a mastery requirement needs its weapons" % id)
	match kind:
		Kind.FITTING_KIT:
			if weapon == null:
				problems.append("fitting kit %s needs a weapon" % id)
			if fittings.is_empty() or fittings.has(null):
				problems.append("fitting kit %s needs its fitting choices" % id)
			if potion != null or not base_name.is_empty():
				problems.append("fitting kit %s cannot name a potion or a Base" % id)
			var ids := {}
			for fitting in fittings:
				if fitting != null:
					if ids.has(fitting.id):
						problems.append("fitting kit %s lists %s twice" % [id, fitting.id])
					ids[fitting.id] = true
		Kind.FITTING:
			if station != Station.FORGE:
				problems.append("fitting recipe %s belongs to the Forge" % id)
			if weapon == null:
				problems.append("fitting recipe %s needs a weapon" % id)
			if fittings.size() != 1 or fittings.has(null):
				problems.append("fitting recipe %s crafts exactly one fitting" % id)
			if refundable:
				problems.append("fitting recipe %s is permanent and cannot be refundable" % id)
			if potion != null or not base_name.is_empty():
				problems.append("fitting recipe %s cannot name a potion or a Base" % id)
		Kind.POTION:
			if potion == null:
				problems.append("potion recipe %s needs a potion" % id)
			if base_name.is_empty():
				problems.append("potion recipe %s needs a public Base" % id)
			if refundable:
				problems.append("potion recipe %s is a repeatable brew and cannot be refundable" % id)
			if weapon != null or not fittings.is_empty():
				problems.append("potion recipe %s cannot name a weapon or fittings" % id)
			if yield_count < 1 or yield_count > MAX_YIELD:
				problems.append("potion recipe %s: yield_count %d is outside 1-%d" % [id, yield_count, MAX_YIELD])
		_:
			problems.append("recipe %s has an unknown kind %d" % [id, kind])
	return problems
