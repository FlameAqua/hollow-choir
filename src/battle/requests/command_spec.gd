class_name CommandSpec
extends RefCounted
## Final action-command parameters after equipment modifiers and Execution Assist.
## Command widgets and the simulator read only this.

var type: Enums.ActionCommandType = Enums.ActionCommandType.NONE
var duration_ms: float = 1000.0
var target_position: float = 0.75
var good_window_ms: float = 300.0
var perfect_window_ms: float = 100.0
var beat_count: int = 3
var beat_interval_ms: float = 420.0
var lead_in_ms: float = 450.0


## TIMING / OPTIONAL_AIM: moment of the sweet spot measured from the start of the sequence.
## HOLD_RELEASE: hold duration that hits the sweet spot.
func target_time_ms() -> float:
	if type == Enums.ActionCommandType.HOLD_RELEASE:
		return duration_ms * target_position
	return lead_in_ms + duration_ms * target_position


## RHYTHM: moment of beat [param index] from the start of the sequence.
func beat_time_ms(index: int) -> float:
	return lead_in_ms + float(index) * beat_interval_ms


## When the sequence is over and an absent input counts as MISS.
func end_time_ms() -> float:
	match type:
		Enums.ActionCommandType.RHYTHM:
			return beat_time_ms(beat_count - 1) + good_window_ms * 0.5
		Enums.ActionCommandType.HOLD_RELEASE:
			return duration_ms
	return lead_in_ms + duration_ms
