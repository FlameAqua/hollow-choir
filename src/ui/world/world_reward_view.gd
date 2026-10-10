class_name WorldRewardView
extends VBoxContainer
## Shared saved receipts and first-clear previews; no reward lookup, grant or eligibility logic.


static func make(receipts: Array[RewardReadout], preview: bool = false) -> WorldRewardView:
	var column := WorldRewardView.new()
	column.name = "Rewards"
	column.add_theme_constant_override("separation", 12)
	if not preview and receipts.any(func(receipt: RewardReadout) -> bool: return not receipt.summary().is_empty()):
		column.add_child(UITheme.label("Salvage", UITheme.ACCENT, 22))
	for receipt in receipts:
		if not preview and receipt.summary().is_empty():
			continue
		var panel := PanelContainer.new()
		panel.name = "Reward_" + String(receipt.claim_id).replace(".", "_")
		panel.add_theme_stylebox_override("panel", UICraft.panel("bag", 16, 16) if preview else UITheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 8, 4))
		column.add_child(panel)
		var copy := VBoxContainer.new()
		copy.add_theme_constant_override("separation", 8)
		panel.add_child(copy)
		if preview:
			copy.add_child(UITheme.label("First-clear salvage", UITheme.ACCENT, 22, true))
			copy.add_child(UITheme.label(receipt.status_text(), UITheme.TEXT_DIM, 22, true))
		for item: Dictionary in receipt.items:
			var amount: int = item.count if preview else item.added
			if amount <= 0:
				continue
			var row := HBoxContainer.new()
			row.name = "RewardItem_" + String(item.id)
			row.add_theme_constant_override("separation", 12)
			copy.add_child(row)
			var readout := ItemInspectionReadout.new()
			readout.title = item.name
			readout.description = item.description
			readout.icon_path = item.icon_path
			readout.category = "Ingredient" if int(item.kind) == RewardItem.Kind.MATERIAL else "Equipment"
			readout.facts.append("Quantity  ×%d" % amount)
			if int(item.kind) == RewardItem.Kind.MATERIAL:
				readout.details.append(WorldCopy.MATERIALS_NOTE)
			var button := WorldInventoryView.item_button(readout, Vector2(0, 48), "%s ×%d" % [item.name, amount])
			button.name = "InspectReward_" + String(item.id)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_style_reward_row(button)
			row.add_child(button)
		if receipt.equipment_slots > 0:
			var expansion := ItemInspectionReadout.new()
			expansion.title = "Equipment slots"
			expansion.category = "Permanent progression reward"
			expansion.description = "Adds another row to your equipment bag. Kept when you reset the journey. Ingredients use no equipment slots."
			expansion.icon_path = "res://assets/art/global/ui/items/satchel_v01.svg"
			var button := WorldInventoryView.item_button(expansion, Vector2(0, 48), "Equipment slots +%d" % receipt.equipment_slots)
			button.name = "InspectCapacityReward"
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_style_reward_row(button)
			copy.add_child(button)
	return column


func present_learnings(learnings: Array[LearningReadout]) -> void:
	var previous := get_node_or_null("BestiaryLearnings")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	if learnings.is_empty(): return
	var section := VBoxContainer.new()
	section.name = "BestiaryLearnings"
	section.add_theme_constant_override("separation", 8)
	section.add_child(UITheme.label("Bestiary Learnings", UITheme.ACCENT, 22))
	for learning in learnings:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		section.add_child(row)
		row.add_child(JourneyUI.picture(learning.icon, Vector2(36, 36)) if learning.icon != null else item_icon(learning.icon_path, 36))
		var enemy_name := UITheme.label(learning.name, UITheme.TEXT, 22, true)
		enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(enemy_name)
		row.add_child(UITheme.label("%s → %s" % [learning.previous_tier_name, learning.new_tier_name], UITheme.INFO, 22))
	add_child(section)
	move_child(section, 0)


static func _style_reward_row(button: Button) -> void:
	button.flat = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill := Color(UITheme.PANEL_LIGHT, .65) if state in ["hover", "focus"] else Color.TRANSPARENT
		button.add_theme_stylebox_override(state, UITheme.box(fill, Color.TRANSPARENT, 0, 0, 8, 6))


static func item_icon(path: String, extent: int = 44) -> Control:
	var icon := TextureRect.new()
	icon.texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else preload("res://assets/art/global/ui/materials/parcel_v01.svg")
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
