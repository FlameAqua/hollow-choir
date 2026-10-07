class_name SidePanel
extends PanelContainer
## Bottom-right panel: familiar (with this round's trigger state), potion slots, and the active
## battlefield conditions with their full explanation (GDD: "The condition panel must always
## explain its effect").

var engine: BattleEngine
var familiar_fired_round := -1
var _text: RichTextLabel


func _ready() -> void:
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.add_theme_font_size_override("normal_font_size", UITheme.font_size(0.76))
	_text.add_theme_font_size_override("bold_font_size", UITheme.font_size(0.8))
	add_child(_text)


func refresh() -> void:
	if engine == null:
		return
	var state := engine.get_state()
	var lines := PackedStringArray()
	if state.familiar != null:
		var ready := familiar_fired_round != state.round
		lines.append("[b]%s[/b] [color=%s]%s[/color]" % [state.familiar.display_name,
			"#7fbf6a" if ready else "#9b978b", "ready" if ready else "rang this round"])
		lines.append("[color=#9b978b]%s[/color]" % state.familiar.description)
	if not state.potion_slots.is_empty():
		var potions := PackedStringArray()
		for slot in state.potion_slots:
			potions.append("%s x%d" % [slot.potion.display_name, slot.charges])
		lines.append("[b]Potions[/b]  " + "  ·  ".join(potions))
	if state.conditions.is_empty():
		lines.append("[color=#5f5c55]No battlefield condition.[/color]")
	for active in state.conditions:
		var definition := active.definition
		var severity := "MAJOR" if definition.severity == Enums.ConditionSeverity.MAJOR else "minor"
		lines.append("[b][color=#e9d58c]%s[/color][/b] [color=#9b978b](%s)[/color]" % [definition.display_name, severity])
		lines.append(definition.description)
	_text.text = "\n".join(lines)
