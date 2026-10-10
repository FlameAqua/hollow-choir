class_name WorldEquipmentDetails
extends VBoxContainer
## Public item facts from the preparation readout. Never resolves gear or validates a loadout.

var text := ""


func present(option: Dictionary, limit: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)
	text = ""
	_line(String(option.name), UITheme.ACCENT, 33)
	_line("%s · %s%s" % [option.category, option.rarity, " · Equipped" if option.equipped else ""], UITheme.INFO)
	if not String(option.reason_text).is_empty():
		_line(String(option.reason_text), UITheme.DANGER)
	for trait_info: Dictionary in option.traits:
		_fact(String(trait_info.name), String(trait_info.description), UITheme.BLOOM)
	_line(String(option.description), UITheme.TEXT_DIM)
	_line("Hollow actions with this item: %d / %d" % [option.actions, limit], UITheme.TEXT_DIM)
	if not option.resonance.is_empty():
		_line("Resonance: " + " · ".join(option.resonance), UITheme.INFO)
	if not option.grants.is_empty():
		add_child(HSeparator.new())
		_line("Actions & stance", UITheme.ACCENT)
		for action: Dictionary in option.grants:
			_fact(String(action.name), String(action.description), UITheme.ACCENT)
	if not String(option.details).is_empty():
		_line(String(option.details), UITheme.TEXT_DIM)


func _line(value: String, color: Color, font_size: int = 22) -> void:
	add_child(UITheme.label(value, color, font_size, true))
	text += value + "\n"


func _fact(title: String, description: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UICraft.panel("inspection", 12, 10))
	add_child(panel)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 6)
	panel.add_child(copy)
	copy.add_child(UITheme.label(title, color, 22, true))
	copy.add_child(UITheme.label(description, UITheme.TEXT, 22, true))
	text += title + "\n" + description + "\n"
