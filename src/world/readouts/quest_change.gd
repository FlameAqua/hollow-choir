class_name QuestChange
extends RefCounted
## One adopted change of a journal entry (playtest revision), published by EventBus.quest_changed
## after the write that caused it succeeded. Presentation shows a brief line and draws attention to
## the journal; it never infers a change from a readout.

enum Kind {
	## The quest entered the journal (a journey created this session, at its first world entry).
	ACQUIRED = 0,
	## The quest moved to a later step.
	ADVANCED = 1,
	## The quest reached its completion stage.
	COMPLETED = 2,
	## Reset journey returned the quest to its first step.
	RESET = 3,
}

var kind: Kind = Kind.ADVANCED
var quest_id: StringName = &""
var title: String = ""
## The objective now in effect (the closing line when completed).
var objective: String = ""
## The stage before the change (-1 when the quest was not in the journal) and after it.
var previous_stage: int = -1
var stage: int = 0


func plain_text() -> String:
	return "%s: %s · %s" % [Kind.keys()[kind], title, objective]
