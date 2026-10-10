class_name FamiliarDefinition
extends Resource
## A familiar never takes a turn: it reacts to triggers (GDD: on_perfect_parry, on_potion_used,
## on_status_applied, on_enemy_staggered, on_weakpoint_exposed…). Its trait is owned by the
## protagonist, so trigger relations are relative to the protagonist's side.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## The play style this familiar is meant to encourage (shown at the Menagerie and in tooltips).
@export_multiline var playstyle: String = ""
@export var trait_def: TraitDefinition
## Playtest revision: the passives this familiar offers, of which the player selects exactly one
## (at most MAX_PASSIVES). Empty = the single legacy choice [member trait_def]. Each needs an id.
@export var passives: Array[TraitDefinition] = []
@export var shape: Enums.VisualShape = Enums.VisualShape.FLYER
@export var color: Color = Color(0.6, 0.6, 0.7)
## Optional art for the battle's familiar card (e.g. an AtlasTexture crop). The familiar is never
## drawn as a unit on the stage: it takes no turn and cannot be targeted.
@export var portrait: Texture2D
## Presentation only: scales the familiar's slot, preserving proportions and floor anchoring.
@export_range(0.5, 2.0, 0.05) var display_scale: float = 1.0


## Most passives one familiar may offer (the Loadout shows three cells).
const MAX_PASSIVES := 3


## The passives the player chooses from, in authored order: [member passives], or the one legacy
## [member trait_def] when none is authored. Never invented.
func passive_choices() -> Array[TraitDefinition]:
	var result: Array[TraitDefinition] = []
	for entry in passives:
		if entry != null and not result.has(entry) and result.size() < MAX_PASSIVES:
			result.append(entry)
	if result.is_empty() and trait_def != null:
		result.append(trait_def)
	return result


## The passive in effect when the save selects none (the first choice), or null.
func default_passive() -> TraitDefinition:
	var choices := passive_choices()
	return choices[0] if not choices.is_empty() else null


## The choice with [param passive_id], or null when this familiar does not offer it.
func passive(passive_id: StringName) -> TraitDefinition:
	for entry in passive_choices():
		if entry.id == passive_id:
			return entry
	return null


## The passive a battle applies for a saved selection: that choice, else the default.
func resolved_passive(passive_id: StringName) -> TraitDefinition:
	var chosen := passive(passive_id) if passive_id != &"" else null
	return chosen if chosen != null else default_passive()


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("familiar needs id and display_name")
	if display_scale <= 0:
		problems.append("familiar %s needs a positive display_scale" % id)
	if trait_def == null or trait_def.triggers.is_empty():
		problems.append("familiar %s needs a trait with at least one trigger" % id)
	elif trait_def != null:
		problems.append_array(trait_def.validate())
	if passives.size() > MAX_PASSIVES:
		problems.append("familiar %s offers more than %d passives" % [id, MAX_PASSIVES])
	var seen := {}
	for entry in passives:
		if entry == null:
			problems.append("familiar %s has a null passive" % id)
			continue
		if entry.id == &"" or seen.has(entry.id):
			problems.append("familiar %s: each passive needs its own id" % id)
		seen[entry.id] = true
		if entry.triggers.is_empty() and entry.modifiers.is_empty():
			problems.append("familiar %s: passive %s does nothing" % [id, entry.id])
		problems.append_array(entry.validate())
	return problems
