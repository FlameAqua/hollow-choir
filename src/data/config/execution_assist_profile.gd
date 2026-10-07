class_name ExecutionAssistProfile
extends Resource
## Execution Assist modifies timing windows, input-sequence speed, optional automatic Brace and an
## optional pause before reactions. It never changes enemy intelligence (that is Tactical
## Difficulty), and the two settings are independent and changeable at any time.

@export var assist: Enums.ExecutionAssist = Enums.ExecutionAssist.STANDARD
@export var display_name: String = ""
@export_multiline var description: String = ""
## Multiplies every command and reaction window width.
@export var window_scale: float = 1.0
## Multiplies indicator travel / beat intervals / wind-ups (> 1 = slower, easier to read).
@export var time_scale: float = 1.0
## When the player gives no reaction input, a Brace succeeds automatically.
@export var auto_brace: bool = false
## Show the incoming attack and wait for a key press before the real-time reaction sequence.
@export var pause_before_reaction: bool = false
## Command results are raised to at least this grade.
@export var minimum_grade: Enums.ExecutionGrade = Enums.ExecutionGrade.MISS


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if window_scale <= 0.0 or time_scale <= 0.0:
		problems.append("assist scales must be positive")
	return problems
