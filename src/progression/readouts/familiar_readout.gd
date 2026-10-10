class_name FamiliarReadout
extends RefCounted
## The travelling familiar for the live save (playtest revision): which owned familiar travels, its
## authored passive choices and the one selected, each with the result its command would return now.
## Plain data from FamiliarRules. A familiar never takes a turn, is never targeted and has no HP;
## nothing here is a combat unit.

## OK when familiar commands would run now (ENCOUNTER_PENDING otherwise).
var reason: FamiliarResult.Reason = FamiliarResult.Reason.OK
var reason_text: String = ""
## The travelling familiar (&"" / "" when none) and its public facts.
var familiar_id: StringName = &""
var name: String = ""
var description: String = ""
var playstyle: String = ""
var portrait_path: String = ""
## The passive in effect (the selected one, else the familiar's default); &"" without a familiar.
var passive_id: StringName = &""
## Passive cells shown for a familiar. A familiar may author fewer; none is invented.
var passive_cells: int = FamiliarDefinition.MAX_PASSIVES
## Owned approved familiars, in the save's order: [{id: StringName, name: String,
##   description: String, playstyle: String, portrait_path: String, selected: bool,
##   selectable: bool (choose_familiar would be accepted now; re-choosing is a no-op),
##   reason: FamiliarResult.Reason, reason_text: String}]
var choices: Array[Dictionary] = []
## The travelling familiar's passive choices, in authored order: [{id: StringName, name: String,
##   description: String, details: String, selected: bool, selectable: bool,
##   reason: FamiliarResult.Reason, reason_text: String}]. Exactly one is selected.
var passives: Array[Dictionary] = []


func available() -> bool:
	return reason == FamiliarResult.Reason.OK


func choice(chosen: StringName) -> Dictionary:
	for entry in choices:
		if entry.id == chosen:
			return entry
	return {}


func passive(chosen: StringName) -> Dictionary:
	for entry in passives:
		if entry.id == chosen:
			return entry
	return {}
