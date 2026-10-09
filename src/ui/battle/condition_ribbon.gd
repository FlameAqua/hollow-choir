class_name ConditionRibbon
extends HBoxContainer
## Global conditions use focusable header icons with immediate rule details.
## Shows the conditions announced so far (PresentationLedger), never ones still to be played.
var engine: BattleEngine
var ledger: PresentationLedger

func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var conditions := shown_conditions()
	visible = not conditions.is_empty()
	for definition in conditions:
		var button := Button.new()
		button.icon = CombatIcons.texture(CombatIcons.mapping("conditions", definition.id, "intent_battlefield"))
		button.expand_icon = true
		button.custom_minimum_size = Vector2(40, 40)
		UICraft.style_icon_button(button)
		button.tooltip_text = "%s\n%s\n%s" % [definition.display_name, RuleNotes.condition_summary(definition), definition.description]
		# Conditions can be inspected on hover, but never selected or activated.
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.button_mask = 0
		button.set_meta(&"condition_id", definition.id)
		add_child(button)

func icon_for(id: StringName) -> Button:
	for child in get_children():
		if child.get_meta(&"condition_id", &"") == id:
			return child as Button
	return null

func highlight(id: StringName, active: bool) -> void:
	var button := icon_for(id)
	if button == null:
		return
	if active:
		button.add_theme_stylebox_override("normal", UICraft.icon_frame(Color(1.35, 1.2, .85)))
	else:
		button.add_theme_stylebox_override("normal", UICraft.icon_frame())

func shown_conditions() -> Array[BattlefieldConditionDefinition]:
	if ledger != null:
		return ledger.conditions
	var live: Array[BattlefieldConditionDefinition] = []
	if engine != null:
		for active in engine.get_state().conditions:
			live.append(active.definition)
	return live

func plain_text() -> String:
	var parts := PackedStringArray()
	for child in get_children():
		if not child.is_queued_for_deletion():
			parts.append(child.tooltip_text)
	return " ".join(parts)
