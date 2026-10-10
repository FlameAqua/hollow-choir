class_name WorldJournalView
extends RefCounted
## Read-only route facts supplied by QuestJournalReadout. Opening never announces a quest.

static func make(journal: QuestJournalReadout) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "QuestJournal"
	column.add_theme_constant_override("separation", 18)
	for quest in journal.active + journal.completed:
		column.add_child(UITheme.label(quest.title, UITheme.ACCENT, 22, true))
		column.add_child(UITheme.label("Complete" if quest.completed else quest.objective, UITheme.BLOOM if quest.completed else UITheme.TEXT, 22, true))
		for step in quest.steps:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			column.add_child(row)
			row.add_child(JourneyUI.picture(UICraft.texture("check") if step.done else JourneyUI.icon("empty"), Vector2(22, 22)))
			var copy := UITheme.label(step.text, UITheme.TEXT if step.current else UITheme.TEXT_DIM, 22, true)
			copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(copy)
	return column
