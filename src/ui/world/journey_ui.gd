class_name JourneyUI
extends RefCounted
## Shared presentation assets and inspection sources. Never determines command eligibility.
const ROOT := "res://assets/art/global/ui/journey_v05/"
const ICONS := {"forge.first_fitting": "kit", "fitting.merciful_grip": "merciful_grip",
	"fitting.hollow_echo": "hollow_echo", "stillroom.clotting_salve": "clotting_salve",
	"stillroom.focus_tincture": "focus_tincture"}

static func icon(id: String) -> Texture2D:
	var path := ROOT + "icons/" + String(ICONS.get(id, id)) + ".svg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else UICraft.texture("hollow_head")

static func facts(title: String, description: String = "", category: String = "", image: Texture2D = null) -> ItemInspectionReadout:
	var result := ItemInspectionReadout.new()
	result.title = title
	result.description = description
	result.category = category
	if image != null:
		result.icon_path = image.resource_path
	return result

static func inspection(entry: Dictionary) -> ItemInspectionReadout:
	var payload := facts(entry.get("title", entry.get("name", "")), entry.get("description", ""), entry.get("category", ""))
	payload.icon_path = entry.get("icon_path", "")
	payload.facts = entry.get("facts", PackedStringArray())
	payload.details = entry.get("details", PackedStringArray())
	return payload

static func potion_icon(id: StringName, path: String = "") -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() else CombatIcons.texture(CombatIcons.mapping("potions", id))

static func supply_inspection(slot) -> ItemInspectionReadout:
	var payload := inspection(slot.inspection)
	if slot.locked or slot.potion_id == &"":
		payload.icon_path = icon("lock" if slot.locked else "empty").resource_path
	elif payload.icon_path.is_empty():
		payload.icon_path = potion_icon(slot.potion_id).resource_path
	return payload

static func action_fact(entry: Dictionary) -> ItemInspectionReadout:
	var payload := facts(entry.name, entry.description, entry.category,
		CombatIcons.texture(CombatIcons.mapping("player_actions", entry.id, "action_inspect")))
	payload.facts = PackedStringArray(["Focus  %d" % entry.focus_cost, "Source  " + String(entry.origin_name)])
	if not String(entry.timing).is_empty(): payload.facts.append("Timing  " + String(entry.timing))
	if not entry.selectable: payload.facts.append(String(entry.reason_text))
	payload.details = PackedStringArray([String(entry.details)])
	return payload

## The additive catalog can land independently; retain the valid held-only baseline until then.
static func ingredients(readout: RefCounted) -> Array[Dictionary]:
	for property in readout.get_property_list():
		if property.name == "ingredients": return readout.get("ingredients")
	return readout.get("materials")

static func has_fact(readout: Object, field: StringName) -> bool:
	for property in readout.get_property_list():
		if property.name == field: return true
	return false

static func button(payload: ItemInspectionReadout, extent := Vector2(48, 48)) -> Button:
	var result := WorldInventoryView.item_button(payload, extent)
	UICraft.compact_slot(result)
	result.custom_minimum_size = extent
	result.add_theme_constant_override("icon_max_width", int(extent.x - 12))
	return result

static func source(control: Control, payload: ItemInspectionReadout) -> void:
	control.tooltip_text = payload.title + "\n" + payload.description
	control.set_meta(&"inspection_readout", func(_point: Vector2) -> ItemInspectionReadout: return payload)

static func picture(texture: Texture2D, extent: Vector2) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = extent
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func inspector(owner: Control, dock: Control, node_name: String) -> HoverInspector:
	var result := HoverInspector.new()
	result.name = node_name
	result.docked = true
	result.manages_detail_input = true
	result.empty_text = "Select an icon to inspect."
	result.bounds_provider = func() -> Rect2:
		return Rect2(owner.get_global_transform().affine_inverse() * dock.global_position, dock.size)
	owner.add_child(result)
	return result

static func help(owner: Control, copy: String) -> Button:
	var control := Button.new()
	control.name = "Help"
	control.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.icon = icon("help")
	control.expand_icon = true
	control.custom_minimum_size = Vector2(44, 44)
	control.tooltip_text = "Help · toggle to close; arrows or Page Up/Down to scroll"
	UICraft.style_icon_button(control, 24)
	UIFeedback.navigation(control)
	var card := PanelContainer.new()
	card.name = "HelpCard"
	card.add_theme_stylebox_override("panel", UICraft.panel("inspection", 18, 18))
	card.z_index = 110
	card.hide()
	owner.add_child(card)
	card.set_as_top_level(true)
	var scroll := WorldInventoryView._scroll("HelpScroll")
	scroll.focus_mode = Control.FOCUS_ALL
	card.add_child(scroll)
	var help_text := UITheme.label(copy, UITheme.TEXT, 22, true)
	help_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_text.custom_minimum_size.x = 400
	scroll.add_child(help_text)
	control.pressed.connect(func() -> void:
		card.position = owner.global_position + Vector2(maxf(0, owner.size.x - 480), 50)
		card.size = Vector2(480, minf(330, owner.size.y - 60))
		card.visible = not card.visible)
	control.gui_input.connect(func(event: InputEvent) -> void:
		if not card.visible: return
		if event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"ui_page_down", true):
			scroll.scroll_vertical += 64 if event.is_action_pressed(&"ui_down", true) else 220
			control.accept_event()
		elif event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"ui_page_up", true):
			scroll.scroll_vertical -= 64 if event.is_action_pressed(&"ui_up", true) else 220
			control.accept_event())
	return control

static func locked(title: String) -> Button:
	var result := button(facts(title, "Reserved for future progression.", "Locked", icon("lock")))
	result.name = title.replace(" ", "")
	result.modulate = Color(.6, .6, .55)
	# Inspectable by keyboard; never emits a gameplay command.
	return result

static func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
