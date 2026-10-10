class_name QuestJournalReadout
extends RefCounted
## The quest journal for the live save (playtest revision): active entries first, completed ones
## apart. Opening or rebuilding it reads the saved stage and announces nothing.

var active: Array[QuestReadout] = []
var completed: Array[QuestReadout] = []


## The entry for [param quest_id] (active or completed), or null.
func quest(quest_id: StringName) -> QuestReadout:
	for entry in active + completed:
		if entry.id == quest_id:
			return entry
	return null


func is_empty() -> bool:
	return active.is_empty() and completed.is_empty()
