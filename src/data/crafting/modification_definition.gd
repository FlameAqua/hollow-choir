class_name ModificationDefinition
extends Resource
## One weapon fitting (V0.5B Forge). Its [member id] is what a save stores as the installed fitting
## and what an EncounterEntry captures. It reuses one complete authored trait by reference from an
## approved item: the item is never copied, edited, granted or equipped, and the fitting adds no
## action, number or combat hook of its own. The fitting kit (RecipeDefinition.Kind.FITTING_KIT)
## names the weapon that may hold it; UnitFactory adds the resolved trait to the wielder like any
## other equipment trait.

@export var id: StringName = &""
## Public name (in V0.5B the reused trait's own name, e.g. "Merciful Grip").
@export var display_name: String = ""
@export_multiline var description: String = ""
## The registered weapon or armor definition that authors the reused trait.
@export var trait_source: Resource
## The id of the reused trait inside [member trait_source]'s traits.
@export var trait_id: StringName = &""


## The reused trait (the authored resource itself, shared and read-only), or null when the source
## or the id does not resolve.
func resolved_trait() -> TraitDefinition:
	if not (trait_source is WeaponDefinition or trait_source is ArmorDefinition):
		return null
	for trait_def: TraitDefinition in trait_source.get("traits"):
		if trait_def != null and trait_def.id == trait_id:
			return trait_def
	return null


## The source item's public name ("" when the source is missing).
func source_name() -> String:
	return String(trait_source.get("display_name")) if trait_source != null else ""


## Self-contained checks. Registry membership of the source: CraftingRules.validate_catalog().
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not RewardDefinition.is_valid_id(id):
		problems.append("fitting id '%s' must be lowercase dotted words (a-z, 0-9, _), at most %d characters" % [
			id, RewardDefinition.MAX_ID_LENGTH])
	if display_name.is_empty() or description.is_empty():
		problems.append("fitting %s needs a public display_name and description" % id)
	if not (trait_source is WeaponDefinition or trait_source is ArmorDefinition):
		problems.append("fitting %s: trait_source must be a weapon or armor definition" % id)
	elif resolved_trait() == null:
		problems.append("fitting %s: %s has no trait '%s'" % [id, source_name(), trait_id])
	return problems
