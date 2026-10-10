class_name WorldCraftingView
extends VBoxContainer
## Icon-led Forge/Stillroom. Eligibility and commands remain supplied by CraftingReadout.
signal command_requested(command: StringName, id: StringName, slot: int)
var service: StringName = &"forge"
var selection: StringName = &""
var first_choice: Button
var _readout: CraftingReadout
var _inventory: InventoryReadout
var _choices: GridContainer
var _scroll: ScrollContainer
var _actions: HBoxContainer
var _entries: Dictionary = {}
var _body: HBoxContainer
var _weapon_id: StringName = &"pilgrims_edge"
var _recipe_text: RichTextLabel
var _revision_status: Label
var _socket_index := 0
var _popup: OwnedChoicePopup
var _forge_content: VBoxContainer

## Shows [param section] (&"forge" or &"stillroom") from [param readout]; [param selected] is the
## entry to reopen on and [param notice] a short status line.
func present(readout: CraftingReadout, section: StringName, selected: StringName = &"", notice: String = "", inventory: InventoryReadout = null) -> void:
	_present_revision(readout, section, selected, notice, inventory)

func _weapon_payload(id: StringName) -> ItemInspectionReadout:
	if _inventory != null:
		for item in _inventory.equipment:
			if item.id == id: return ItemInspectionReadout.from_item(item)
	return JourneyUI.facts("Pilgrim's Edge", "", "Weapon", preload("res://assets/art/global/ui/items/pilgrims_edge_v01.svg"))

func select(id: StringName) -> void:
	_revision_select(id)

func _action(title: String, node_name: String, allowed: bool, command: StringName, id: StringName, slot: int = -1) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.custom_minimum_size = Vector2(150, 44)
	button.disabled = not allowed
	JourneyUI.source(button, _entries[selection].payload)
	_actions.add_child(button)
	button.pressed.connect(func() -> void: command_requested.emit(command, id, slot))

func focus_selection() -> void:
	WorldModal.focus_later(_choices.get_node_or_null("Choice_" + String(selection).replace(":", "_").replace(".", "_")) as Button)

func _relink() -> void:
	var parent := get_parent()
	while parent != null and not parent is WorldModal: parent = parent.get_parent()
	if parent is WorldModal: parent._link_focus()


func _present_revision(readout: CraftingReadout, section: StringName, selected: StringName, notice: String, inventory: InventoryReadout) -> void:
	_readout = readout
	_inventory = inventory
	service = section
	add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	add_child(header)
	header.add_child(JourneyUI.help(self, "Forge: choose a socket and a compatible fitting. Craft pays the displayed ingredients once; Fit and Remove use crafted fittings.\n\nStillroom: Brew pays ingredients for the displayed doses. Prepared positions carry at most their cap into battle, limited by held stock. Only a saved victory spends the doses used.\n\nAll changes save before taking effect. Locked positions remain locked."))
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 24)
	add_child(_body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 430
	left.add_theme_constant_override("separation", 8)
	_body.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	_body.add_child(right)
	if service == &"stillroom": _revision_supplies(left)
	else: _revision_forge(left)
	right.add_child(UITheme.label("Brew catalog" if service == &"stillroom" else "Compatible fittings", UITheme.ACCENT, 22))
	var choice_scroll := WorldInventoryView._scroll("CraftingChoicesScroll")
	choice_scroll.custom_minimum_size.y = 48
	choice_scroll.size_flags_vertical = Control.SIZE_FILL
	right.add_child(choice_scroll)
	_choices = GridContainer.new()
	_choices.columns = 7
	choice_scroll.add_child(_choices)
	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UICraft.panel("inspection", 12, 12))
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_panel)
	_scroll = WorldInventoryView._scroll("CraftingDetailsScroll")
	_scroll.custom_minimum_size.y = 184
	detail_panel.add_child(_scroll)
	_recipe_text = UITheme.rich_text(22)
	_recipe_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_recipe_text)
	_revision_status = UITheme.label("", UITheme.INFO, 22, true)
	_revision_status.name = "CraftingState"
	_revision_status.custom_minimum_size.y = 26
	_revision_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_revision_status.clip_text = true
	_revision_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(_revision_status)
	_actions = HBoxContainer.new()
	_actions.custom_minimum_size.y = 44
	right.add_child(_actions)
	var ingredients := VBoxContainer.new()
	ingredients.add_child(UITheme.label("Ingredients", UITheme.ACCENT, 22))
	ingredients.add_child(IngredientStrip.make(JourneyUI.ingredients(readout)))
	var ingredient_space := Control.new()
	ingredient_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(ingredient_space)
	left.add_child(ingredients)
	_revision_choices()
	_revision_select(selected if _entries.has(selected) else (StringName(_entries.keys()[0]) if not _entries.is_empty() else &""))
	if not notice.is_empty():
		_revision_status.text = notice
		_revision_status.tooltip_text = notice
	TooltipPolicy.install.call_deferred(self)
	_relink.call_deferred()

func _revision_supplies(left: VBoxContainer) -> void:
	left.add_child(UITheme.label("Prepared", UITheme.ACCENT, 22))
	var row := HBoxContainer.new()
	row.name = "PotionSlots"
	row.add_theme_constant_override("separation", 12)
	left.add_child(row)
	for slot in _readout.supplies:
		var slot_payload := JourneyUI.supply_inspection(slot)
		var button := JourneyUI.button(slot_payload)
		button.name = "PotionSlot_%d" % slot.index
		row.add_child(button)
		if slot.locked:
			button.modulate = Color(.6, .6, .55)
		else:
			if slot.state == PotionSlotReadout.State.DEPLETED: button.modulate = Color(.65, .65, .65)
			button.pressed.connect(func() -> void:
				var choices: Array[Dictionary] = []
				for entry in slot.choices:
					var payload := JourneyUI.facts(entry.name, entry.description, "Supply", JourneyUI.potion_icon(entry.id, entry.icon_path))
					payload.facts.append("Held %d · next battle %d / %d" % [entry.held, entry.usable, entry.cap])
					choices.append({"id": entry.id, "payload": payload, "selectable": entry.selectable})
				if is_instance_valid(_popup): _popup.queue_free()
				_popup = OwnedChoicePopup.make(button, "Supply %d" % (slot.index + 1), choices)
				_popup.chosen.connect(func(id: StringName) -> void: command_requested.emit(&"potion", id, slot.index))
				add_child(_popup))
	left.add_child(UITheme.label("Unprepared stock", UITheme.ACCENT, 22))
	var stock := GridContainer.new()
	stock.name = "UnpreparedStock"
	stock.columns = 6
	left.add_child(stock)
	for entry in _readout.stock:
		if entry.prepared_slot >= 0: continue
		var payload := JourneyUI.facts(entry.name, entry.description, "Unprepared", JourneyUI.potion_icon(entry.id, entry.icon_path))
		payload.facts.append("Held  %d doses" % entry.held)
		var column := VBoxContainer.new()
		stock.add_child(column)
		column.add_child(JourneyUI.button(payload))
		column.add_child(UITheme.label("×%d" % entry.held, UITheme.TEXT, 22))
	if stock.get_child_count() == 0:
		stock.add_child(_empty_cell("EmptyStock", "No unprepared stock", "Brew supplies here, then choose a prepared position."))
	left.add_child(JourneyUI.picture(load(JourneyUI.ROOT + "stillroom_station_v01.png"), Vector2(240, 90)))

func _revision_forge(left: VBoxContainer) -> void:
	var weapons := HBoxContainer.new()
	weapons.name = "OwnedWeapons"
	left.add_child(weapons)
	if _inventory != null:
		for item in _inventory.equipment:
			if item.slot != Enums.EquipSlot.WEAPON: continue
			var button := JourneyUI.button(ItemInspectionReadout.from_item(item), Vector2(36, 36))
			button.name = "ForgeWeapon_" + String(item.id)
			weapons.add_child(button)
			button.pressed.connect(func() -> void:
				_weapon_id = item.id
				_revision_weapon()
				_revision_choices()
				if not _entries.is_empty(): _revision_select(StringName(_entries.keys()[0])))
			UIFeedback.navigation(button)
	_forge_content = VBoxContainer.new()
	_forge_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_forge_content)
	_revision_weapon()

func _revision_weapon() -> void:
	JourneyUI.clear_children(_forge_content)
	var graph := Control.new()
	graph.name = "WeaponSockets"
	graph.custom_minimum_size = Vector2(430, 246)
	_forge_content.add_child(graph)
	var ring := JourneyUI.picture(UICraft.texture("ring"), Vector2(188, 188))
	ring.position = Vector2(121, 29)
	ring.size = Vector2(188, 188)
	ring.modulate = Color(.7, .7, .6, .8)
	graph.add_child(ring)
	var weapon := JourneyUI.button(_weapon_payload(_weapon_id), Vector2(72, 72))
	weapon.name = "ForgeWeapon"
	weapon.position = Vector2(179, 87)
	graph.add_child(weapon)
	var fitting = _readout.fitting(_weapon_id)
	if fitting == null:
		var empty := _empty_cell("EmptyFittingSocket", "No compatible fittings", "This weapon has no fitting positions.")
		empty.position = Vector2(191, 5)
		graph.add_child(empty)
		_forge_content.add_child(UITheme.label("No compatible fittings", UITheme.TEXT_DIM, 22))
		return
	var socket_points := [Vector2(191, 5), Vector2(89, 165), Vector2(293, 165)]
	for socket in fitting.sockets:
		var payload := JourneyUI.facts(socket.fitting_name if socket.fitting_id != &"" else "Empty socket", socket.reason_text, "Socket %d" % (socket.index + 1), JourneyUI.icon("lock" if socket.locked else String(socket.fitting_id) if socket.fitting_id != &"" else "empty"))
		var button := JourneyUI.button(payload)
		button.name = "FittingSocket_%d" % socket.index
		button.toggle_mode = not socket.locked
		button.set_pressed_no_signal(socket.index == _socket_index and not socket.locked)
		button.position = socket_points[clampi(socket.index, 0, 2)]
		graph.add_child(button)
		if not socket.locked:
			button.pressed.connect(func() -> void:
				_socket_index = socket.index
				_revision_weapon()
				_revision_choices()
				_revision_select(StringName(_entries.keys()[0]) if not _entries.is_empty() else &""))
	_forge_content.add_child(UITheme.label(fitting.weapon_name, UITheme.TEXT_DIM, 22, true))
	if not fitting.legacy_kit.is_empty() and fitting.legacy_kit.owned:
		var legacy: Dictionary = fitting.legacy_kit
		var refund := Button.new()
		refund.name = "RefundLegacyKit"
		refund.text = "Reclaim old kit"
		refund.custom_minimum_size.y = 40
		refund.disabled = not legacy.can_refund
		var payload := JourneyUI.facts(legacy.name, "Reclaim the old kit. Its granted fittings and installed fitting are removed; separately crafted fittings are kept.", "Legacy kit", JourneyUI.icon("kit"))
		for cost in legacy.refund: payload.facts.append("Returns %d %s" % [cost.count, cost.name])
		if not legacy.can_refund: payload.facts.append(legacy.refund_reason_text)
		JourneyUI.source(refund, payload)
		refund.pressed.connect(func() -> void: command_requested.emit(&"refund", legacy.id, -1))
		_forge_content.add_child(refund)

func _revision_choices() -> void:
	JourneyUI.clear_children(_choices)
	_entries.clear()
	first_choice = null
	if _recipe_text != null: _recipe_text.text = ""
	if _actions != null: JourneyUI.clear_children(_actions)
	if _revision_status != null: _revision_status.text = ""
	if service == &"stillroom":
		for recipe in _readout.recipes:
			if recipe.station != RecipeDefinition.Station.STILLROOM or recipe.retired: continue
			var payload := JourneyUI.facts(recipe.potion_name, recipe.potion_description, "Brew · %d doses" % recipe.yield_count, JourneyUI.potion_icon(recipe.potion_id, recipe.potion_icon_path))
			payload.facts.append("Held  %d · after Brew  %d" % [recipe.potion_held, recipe.potion_total_after])
			_revision_costs(payload, recipe.costs)
			_revision_choice(recipe.id, payload, {"kind": &"brew", "value": recipe})
	else:
		var fitting = _readout.fitting(_weapon_id)
		if fitting == null:
			_choices.add_child(_empty_cell("EmptyFittingChoice", "No compatible fittings", "Choose another owned weapon to inspect its fitting choices."))
			return
		for option in fitting.options:
			var payload := JourneyUI.facts(option.name, option.trait.description, "Crafted" if option.owned else "Uncrafted", JourneyUI.icon(String(option.id)))
			payload.details.append(option.trait.details)
			if not option.owned: _revision_costs(payload, option.costs)
			if not option.mastery_met: payload.facts.append("Mastery  %d / %d" % [option.mastery_current, option.mastery_required])
			if not option.owned and not option.can_craft: payload.details.append(option.craft_reason_text)
			_revision_choice(StringName("fitting:" + String(option.id)), payload, {"kind": &"fitting", "value": fitting, "option": option})
	if _choices.get_child_count() == 0:
		_choices.add_child(_empty_cell("EmptyCatalog", "No choices available", "There are no relevant recipes or fittings."))

func _empty_cell(node_name: String, title: String, copy: String) -> Button:
	var cell := JourneyUI.button(JourneyUI.facts(title, copy, "Empty", JourneyUI.icon("empty")))
	cell.name = node_name
	cell.focus_mode = Control.FOCUS_NONE
	return cell

func _revision_costs(payload: ItemInspectionReadout, costs: Array) -> void:
	for cost in costs:
		var image := "[img=22x22]%s[/img] " % cost.icon_path if not String(cost.icon_path).is_empty() else ""
		payload.facts.append("%s%s · %d required / %d held" % [image, cost.name, cost.count, cost.held])

func _revision_choice(id: StringName, payload: ItemInspectionReadout, entry: Dictionary) -> void:
	entry.payload = payload
	_entries[id] = entry
	var button := JourneyUI.button(payload)
	button.name = "Choice_" + String(id).replace(":", "_").replace(".", "_")
	button.toggle_mode = true
	_choices.add_child(button)
	button.pressed.connect(func() -> void: _revision_select(id))
	button.focus_entered.connect(func() -> void: _revision_select(id))
	UIFeedback.navigation(button)
	if first_choice == null: first_choice = button

func _revision_select(id: StringName) -> void:
	if not _entries.has(id): return
	selection = id
	JourneyUI.clear_children(_actions)
	var entry: Dictionary = _entries[id]
	# Compact spacing keeps effects and costs together; the action/state retain their own fixed rows.
	_recipe_text.text = entry.payload.describe(true).replace("\n\n", "\n")
	_scroll.scroll_vertical = 0
	for button in _choices.get_children():
		button.set_pressed_no_signal(button.name == "Choice_" + String(id).replace(":", "_").replace(".", "_"))
	if entry.kind == &"brew":
		var recipe = entry.value
		_revision_status.text = "Ready · produces %d doses" % recipe.yield_count if recipe.can_brew else recipe.brew_reason_text
		_revision_status.add_theme_color_override("font_color", UITheme.BLOOM if recipe.can_brew else UITheme.DANGER)
		_action("Brew", "BrewRecipe", recipe.can_brew, &"brew", recipe.id)
	else:
		var option: Dictionary = entry.option
		_revision_status.text = "Installed" if option.installed else "Crafted" if option.owned else option.craft_reason_text if not option.can_craft else "Ready to craft"
		_revision_status.add_theme_color_override("font_color", UITheme.BLOOM if option.owned else UITheme.INFO)
		if option.action == &"craft": _action("Craft", "CraftFitting", option.can_craft, &"craft", option.id, _socket_index)
		elif option.action == &"remove": _action("Remove", "RemoveFitting", option.can_remove, &"remove", entry.value.weapon_id, _socket_index)
		elif option.action == &"fit": _action("Fit", "FitWeapon", option.can_fit, &"fit", option.id, _socket_index)
		else: _action("Unavailable", "UnavailableFitting", false, &"none", option.id, _socket_index)
	_revision_status.tooltip_text = _revision_status.text
	_relink.call_deferred()

## The host passes only the result of an adopted station operation.
func present_operation(result: CraftingResult) -> void:
	if _revision_status == null or result == null: return
	if not result.changed: return
	var produced := PackedStringArray()
	for item in result.produced: produced.append("%s ×%d" % [item.name, item.count])
	_revision_status.text = "Brewed · " + ", ".join(produced) if not produced.is_empty() else "Saved"
	_revision_status.add_theme_color_override("font_color", UITheme.BLOOM)
