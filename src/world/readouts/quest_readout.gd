class_name QuestReadout
extends RefCounted
## One journal entry for the live save (playtest revision): the bell journey and its existing
## objective stages. Plain data from QuestRules; public text only (no enemy or species facts).

## Stable quest id (QuestRules.BELL).
var id: StringName = &""
var title: String = ""
## The current step's text; for a completed quest, its closing line.
var objective: String = ""
## Current stage and how many stages the quest has (the last one is completion).
var stage: int = 0
var stage_count: int = 0
var completed := false
## Every step in order: [{stage: int, text: String, done: bool, current: bool}]. The completion
## stage is not a step; a completed quest has every step done and none current.
var steps: Array[Dictionary] = []


func plain_text() -> String:
	var lines := PackedStringArray([title, objective])
	for step in steps:
		lines.append("%s %s" % ["[x]" if step.done else ("[>]" if step.current else "[ ]"), step.text])
	return "\n".join(lines)
