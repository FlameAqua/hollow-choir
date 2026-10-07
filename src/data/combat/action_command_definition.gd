@tool
class_name ActionCommandDefinition
extends Resource
## Parameters for one of the four reusable action-command components.
##
## Never write a bespoke minigame: every weapon/ability parameterises one of these.
## Final values seen by the player are produced by CommandRules (equipment modifiers + Execution
## Assist), so these are the STANDARD-assist baseline numbers.
##
## Window widths are the TOTAL width of the zone in milliseconds, centred on the target moment
## (GDD tooltip example: "Good: 420 ms, Perfect: 115 ms").

const T := Enums.ActionCommandType

const FIELDS_BY_TYPE := {
	T.NONE: [],
	T.TIMING: ["duration_ms", "target_position", "good_window_ms", "perfect_window_ms", "lead_in_ms"],
	T.HOLD_RELEASE: ["duration_ms", "target_position", "good_window_ms", "perfect_window_ms", "lead_in_ms"],
	T.RHYTHM: ["good_window_ms", "perfect_window_ms", "beat_count", "beat_interval_ms", "lead_in_ms"],
	T.OPTIONAL_AIM: ["duration_ms", "target_position", "good_window_ms", "perfect_window_ms", "lead_in_ms"],
}

@export var type: Enums.ActionCommandType = Enums.ActionCommandType.TIMING:
	set(value):
		type = value
		notify_property_list_changed()
## TIMING: indicator travel time. HOLD_RELEASE: gauge fill time. OPTIONAL_AIM: reticle sweep time.
@export var duration_ms: float = 1000.0
## Where the sweet spot sits along the travel (0..1).
@export_range(0.05, 0.95, 0.01) var target_position: float = 0.75
@export var good_window_ms: float = 320.0
@export var perfect_window_ms: float = 100.0
## RHYTHM: 2–4 beats (GDD maximum is four).
@export_range(2, 4) var beat_count: int = 3
@export var beat_interval_ms: float = 420.0
## Pause before the indicator / first beat starts moving, so the player can read it.
@export var lead_in_ms: float = 450.0


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	if prop_name == "type":
		return
	var all_fields := ["duration_ms", "target_position", "good_window_ms", "perfect_window_ms",
		"beat_count", "beat_interval_ms", "lead_in_ms"]
	if prop_name in all_fields and not (prop_name in FIELDS_BY_TYPE.get(type, [])):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if type == T.NONE:
		return problems
	if perfect_window_ms <= 0.0 or good_window_ms <= 0.0:
		problems.append("command windows must be positive")
	if perfect_window_ms > good_window_ms:
		problems.append("perfect window wider than good window")
	if type == T.RHYTHM:
		if beat_count < 2 or beat_count > 4:
			problems.append("rhythm beat_count must be 2..4")
		if good_window_ms >= beat_interval_ms:
			problems.append("rhythm good window overlaps neighbouring beats")
	elif duration_ms <= 0.0:
		problems.append("command duration must be positive")
	return problems
