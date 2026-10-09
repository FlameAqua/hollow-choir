class_name EncounterCardReadout
extends RefCounted
## Filtered facts for the Engage / Leave card: public threat category, group size, authored
## battlefield conditions and only those species the saved bestiary already knows.

var threat: String = ""
var group_count: int = 0
## [{name, summary}] from the encounter's authored conditions.
var conditions: Array[Dictionary] = []
## One line per creature: its name when known (Observed or better), otherwise "Unknown creature".
var creatures: PackedStringArray = PackedStringArray()
var resource_rule: String = ""
var optional: bool = false


func plain_text() -> String:
	var lines := PackedStringArray([threat, "%d creature%s" % [group_count, "" if group_count == 1 else "s"]])
	lines.append_array(creatures)
	for condition in conditions:
		lines.append("%s: %s" % [condition.name, condition.summary])
	lines.append(resource_rule)
	return "\n".join(lines)
