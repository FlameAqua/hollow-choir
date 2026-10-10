class_name PuzzleReadout
extends RefCounted
## Public state of one rune puzzle (V0.5C) for presentation: which runes are lit, how far the
## current attempt has come and whether it is solved. It never carries the solution order.

var id: StringName = &""
var name: String = ""
var solved := false
## Runes struck so far in the current attempt, and the strikes a solution takes.
var entered: int = 0
var length: int = 0
## [{id: StringName, label: String (the landmark's public label), lit: bool (in the current
##   attempt, or every rune once solved)}], in the puzzle's authored rune order.
var runes: Array[Dictionary] = []


func rune(rune_id: StringName) -> Dictionary:
	for entry in runes:
		if entry.id == rune_id:
			return entry
	return {}
