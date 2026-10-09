class_name WorldEncounterView
extends RefCounted
## Arranges only the public, knowledge-filtered encounter readout. No content lookup or eligibility.


static func make(card: EncounterCardReadout) -> WorldModal:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.add_child(UITheme.heading("%d creature%s" % [card.group_count, "" if card.group_count == 1 else "s"]))
	var counts := {}
	for creature in card.creatures:
		counts[creature] = int(counts.get(creature, 0)) + 1
	var creatures := PackedStringArray()
	for creature: String in counts:
		creatures.append(creature + (" × %d" % counts[creature] if counts[creature] > 1 else ""))
	content.add_child(UITheme.label(" · ".join(creatures), UITheme.TEXT, -1, true))
	for condition in card.conditions:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UICraft.panel("inspection", 16, 10))
		content.add_child(panel)
		var facts := VBoxContainer.new()
		facts.add_theme_constant_override("separation", 8)
		panel.add_child(facts)
		facts.add_child(UITheme.label(String(condition.name), UITheme.INFO, -1, true))
		facts.add_child(UITheme.label(String(condition.summary), UITheme.TEXT, -1, true))
	content.add_child(UITheme.label(card.resource_rule, UITheme.TEXT_DIM, -1, true))
	content.add_child(UITheme.label(WorldCopy.ENCOUNTER_OPTIONAL if card.optional else WorldCopy.ENCOUNTER_GUARD,
		UITheme.TEXT_DIM, -1, true))
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(WorldRules.ACT_ENGAGE, WorldCopy.ACTION_ENGAGE),
		WorldDialogueReadout.action(WorldRules.ACT_LEAVE, WorldCopy.ACTION_LEAVE)]
	return WorldModal.make(&"encounter", card.threat, PackedStringArray(), actions, content)
