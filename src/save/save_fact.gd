class_name SaveFact
extends RefCounted
## One successful save write (playtest revision), published by EventBus.save_completed after the
## written state was adopted. The origin is authoritative: presentation shows the compact
## confirmation for MANUAL and a quiet icon for AUTOMATIC, and never infers it from timing.

enum Origin {
	## Any write the player did not ask for by name: area arrival, interactions, equipment,
	## supplies, crafting, encounter entry and results, rewards, New Journey, Practice recording.
	AUTOMATIC = 0,
	## The paused menu's Save, Save and return to title or Save and Quit.
	MANUAL = 1,
}

var slot: int = 0
var origin: Origin = Origin.AUTOMATIC


static func make(p_slot: int, p_origin: Origin) -> SaveFact:
	var fact := SaveFact.new()
	fact.slot = p_slot
	fact.origin = p_origin
	return fact


func manual() -> bool:
	return origin == Origin.MANUAL
