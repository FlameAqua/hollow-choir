class_name IngredientStrip
extends HBoxContainer
## Receives the public catalog in backend order, including supplied zeros. Never discovers content.

static func make(materials: Array[Dictionary]) -> IngredientStrip:
	var strip := IngredientStrip.new()
	strip.name = "IngredientStrip"
	strip.add_theme_constant_override("separation", 12)
	for item in materials:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		strip.add_child(column)
		var button := WorldInventoryView.item_button(ItemInspectionReadout.from_item(item, true), Vector2.ONE * UITheme.SLOT_SIZE)
		button.name = "Ingredient_" + String(item.id)
		UICraft.compact_slot(button)
		column.add_child(button)
		var amount := UITheme.label("×%d" % item.count, UITheme.TEXT_DIM if int(item.count) == 0 else UITheme.TEXT, 22)
		amount.name = "Quantity"
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(amount)
	return strip
