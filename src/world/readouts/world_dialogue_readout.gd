class_name WorldDialogueReadout
extends RefCounted
## One short exchange: a speaker, at most two paragraphs and named actions. Presentation only;
## choosing an action asks the host to apply it, text advancing never changes state.

const MAX_PARAGRAPHS := 2

var speaker: String = ""
var paragraphs: PackedStringArray = PackedStringArray()
## [{id: StringName, label: String}] in display order; the last one closes without effect.
var actions: Array[Dictionary] = []


static func make(p_speaker: String, p_paragraphs: Array, p_actions: Array[Dictionary]) -> WorldDialogueReadout:
	var readout := WorldDialogueReadout.new()
	readout.speaker = p_speaker
	for paragraph in p_paragraphs.slice(0, MAX_PARAGRAPHS):
		readout.paragraphs.append(String(paragraph))
	readout.actions = p_actions
	return readout


static func action(id: StringName, label: String) -> Dictionary:
	return {"id": id, "label": label}
