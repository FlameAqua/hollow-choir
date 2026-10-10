class_name WorldInventoryView
extends HBoxContainer
## Ingredients and equipment are inspection sources, never equip commands.

var first_item: Button
var grid: GridContainer


static func make(inventory: InventoryReadout) -> WorldInventoryView:
	var view := WorldInventoryView.new()
	view.name = "Inventory"
	view.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 410
	left.add_theme_constant_override("separation", 14)
	view.add_child(left)
	var bag := VBoxContainer.new()
	bag.size_flags_vertical = Control.SIZE_FILL
	bag.custom_minimum_size.x = 410
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag.add_theme_constant_override("separation", 12)
	left.add_child(bag)
	bag.add_child(UITheme.label("Equipment", UITheme.ACCENT, 22))
	var bag_scroll := _scroll("BagScroll")
	bag.add_child(bag_scroll)
	view.grid = GridContainer.new()
	view.grid.name = "EquipmentSlots"
	view.grid.columns = 5
	view.grid.add_theme_constant_override("h_separation", 8)
	view.grid.add_theme_constant_override("v_separation", 8)
	bag_scroll.add_child(view.grid)
	bag_scroll.custom_minimum_size.y = 216
	bag_scroll.size_flags_vertical = Control.SIZE_FILL
	# Compatibility saves must never conceal owned equipment beyond today's authored capacity.
	for index in maxi(20, inventory.equipment.size()):
		if index < inventory.equipment.size():
			var item := inventory.equipment[index]
			var button := item_button(ItemInspectionReadout.from_item(item), Vector2.ONE * UITheme.SLOT_SIZE)
			UICraft.compact_slot(button)
			button.name = "Equipment_" + String(item.id)
			view.grid.add_child(button)
			if item.equipped:
				var equipped := WorldRewardView.item_icon("res://assets/art/global/ui/world/equipped.svg", 16)
				equipped.position = Vector2(30, 3)
				button.add_child(equipped)
			if view.first_item == null:
				view.first_item = button
		elif index >= inventory.equipment_capacity:
			var reason := String(inventory.get("cells_locked_text")) if JourneyUI.has_fact(inventory, &"cells_locked_text") else "Reserved equipment pocket."
			var locked := JourneyUI.button(JourneyUI.facts("Locked equipment pocket", reason, "Locked", JourneyUI.icon("lock")))
			locked.name = "LockedSlot_%d" % index
			view.grid.add_child(locked)
		else:
			var empty := Panel.new()
			empty.name = "EmptySlot_%d" % index
			empty.custom_minimum_size = Vector2.ONE * UITheme.SLOT_SIZE
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty.add_theme_stylebox_override("panel", UICraft.inventory_slot(false, Color(.65, .65, .6)))
			view.grid.add_child(empty)
	var materials := VBoxContainer.new()
	materials.name = "Ingredients"
	materials.add_theme_constant_override("separation", 8)
	materials.add_child(UITheme.label("Ingredients", UITheme.ACCENT, 22))
	materials.add_child(IngredientStrip.make(JourneyUI.ingredients(inventory)))
	left.add_child(materials)
	return view


static func item_button(readout: ItemInspectionReadout, extent: Vector2, label: String = "") -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = extent
	button.icon = load(readout.icon_path) as Texture2D if not readout.icon_path.is_empty() else preload("res://assets/art/global/ui/materials/parcel_v01.svg")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 48 if label.is_empty() else 32)
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_font_size_override("font_size", 22)
	button.tooltip_text = readout.title + "\n" + readout.description
	button.set_meta(&"inspection_readout", func(_point: Vector2) -> ItemInspectionReadout: return readout)
	button.add_theme_stylebox_override("normal", _frame(UITheme.BORDER))
	button.add_theme_stylebox_override("hover", _frame(UITheme.ACCENT))
	button.add_theme_stylebox_override("focus", _frame(UITheme.FOCUS))
	button.add_theme_stylebox_override("pressed", _frame(UITheme.ACCENT, UITheme.PANEL_LIGHT))
	return button


static func _frame(border: Color, fill: Color = Color(.05, .08, .07, .7)) -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = fill
	frame.border_color = border
	frame.set_border_width_all(1)
	frame.set_content_margin_all(6)
	return frame


static func _scroll(id: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = id
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	return scroll
