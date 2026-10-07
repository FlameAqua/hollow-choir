class_name StatusDefinition
extends Resource
## Behaviour of one of the six statuses. Core mechanics are typed fields interpreted by
## StatusRules; anything unusual is expressed with [member traits] (active while present).

@export var status: Enums.StatusId = Enums.StatusId.NONE
@export var display_name: String = ""
## Immediate-layer text (always available in tooltips).
@export_multiline var description: String = ""
@export_multiline var details: String = ""
## Color-independent label (GDD: "color-independent status icons").
@export var glyph: String = ""
@export var color: Color = Color.WHITE
@export var is_negative: bool = true

@export_group("Duration")
@export var duration_mode: Enums.DurationMode = Enums.DurationMode.TURNS
## Turns (TURNS) or charges (CHARGES) when an application does not specify one.
@export var default_duration: int = 3
@export var max_duration: int = 6
@export var max_stacks: int = 3
## CHARGES mode: also expires after this many bearer turns (0 = never), so it cannot sit forever.
@export var expiry_turns: int = 0

@export_group("Damage")
@export var tick_timing: Enums.TickTiming = Enums.TickTiming.NONE
## PURE damage per stack when it ticks (Burn).
@export var tick_damage_per_stack: float = 0.0
## PURE damage per stack each time the bearer performs a STRENUOUS action (Bleed).
@export var strenuous_damage_per_stack: float = 0.0

@export_group("Interactions")
## Applying this status removes these from the bearer (Wet removes Burn).
@export var removes_on_apply: Array[Enums.StatusId] = []
## If the bearer has one of these, this application fails and that status is consumed
## (Burn on a Wet target is doused).
@export var blocked_by: Array[Enums.StatusId] = []
## Rules active on the bearer while the status is present (owner = bearer).
@export var traits: Array[TraitDefinition] = []


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if status == Enums.StatusId.NONE:
		problems.append("status definition with NONE id")
	if display_name.is_empty() or glyph.is_empty():
		problems.append("status %s needs display_name and glyph" % Enums.StatusId.keys()[status])
	if default_duration < 1 or max_stacks < 1:
		problems.append("status %s needs default_duration and max_stacks >= 1" % Enums.StatusId.keys()[status])
	for trait_def in traits:
		if trait_def == null:
			problems.append("null trait in status")
		else:
			problems.append_array(trait_def.validate())
	return problems
