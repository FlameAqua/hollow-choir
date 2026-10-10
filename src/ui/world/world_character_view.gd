class_name WorldCharacterView
extends VBoxContainer
## Icon-led Character: the unified Loadout (gear and its action sources, pet, supplies and the saved
## combat arrangement) and the read-only Inventory. Every change is a typed request; eligibility,
## positions, stock and locks come from the backend readouts (V0.5 playtest revision).
signal equip_requested(slot: Enums.EquipSlot, item: StringName)
signal unequip_requested(slot: Enums.EquipSlot)
signal potion_requested(slot: int, potion: StringName)
## &"put" (action_id into position), &"swap" (position with other) or &"move" (action_id to position).
signal combat_requested(command: StringName, position: int, action_id: StringName, other: int)
signal field_guide_requested
signal familiar_requested(id: StringName)
signal familiar_passive_requested(id: StringName)
signal journal_requested
var inspector: HoverInspector
## &"equipment" (the Loadout) or &"inventory".
var selected_tab: StringName = &"inventory"
## The host's gear slot context (a bench returns to it); the Loadout chooses gear in popups.
var selected_slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON
var first_item: Button
## The selected combat position (the target of the next placed action).
var combat_position := 0
var _inventory: InventoryReadout
var _loadout: LoadoutReadout
var _body: Control
var _pages: VBoxContainer
var _detail_host: Control
var _tabs: Array[Button] = []
var _loadout_view: WorldLoadoutView

func present(inventory: InventoryReadout, loadout: LoadoutReadout) -> void:
	_inventory = inventory
	_loadout = loadout
	name = "Character"
	add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	add_child(header)
	for id in [&"equipment", &"inventory"]:
		var button := Button.new()
		button.name = "Tab_" + String(id)
		button.text = "Loadout" if id == &"equipment" else "Inventory"
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(180, 44)
		header.add_child(button)
		_tabs.append(button)
		button.pressed.connect(func() -> void: select_tab(id))
		UIFeedback.navigation(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var guide := Button.new()
	guide.name = "FieldGuide"
	guide.text = "Field Guide"
	guide.custom_minimum_size.y = 44
	header.add_child(guide)
	guide.pressed.connect(func() -> void: field_guide_requested.emit())
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size.y = 410
	add_child(_body)
	_pages = VBoxContainer.new()
	_body.add_child(_pages)
	_pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var help := JourneyUI.help(_body, "Loadout: choose gear, a pet or a supply position to see owned choices. Changes save before taking effect and apply to the next encounter.\n\nCombat: choose a destination, then a source action. Six positions are usable; two remain locked. Placing an action already in the arrangement swaps places. Highlighted source actions are placed. Core includes your stance, innate actions and Inspect. Passive icons are always active.\n\nSupplies: held stock limits the next battle's allowance. Only a saved victory spends the doses used. Brew more at the Stillroom.\n\nInventory: hover or focus equipment to inspect. Hold %s for details; right-click pins the information box. Journal records your current objective." % InputBindings.prompt(InputBindings.INFO))
	header.add_child(help)
	var journal := Button.new()
	journal.name = "Journal"
	journal.text = "Journal"
	journal.custom_minimum_size.y = 44
	header.add_child(journal)
	journal.pressed.connect(func() -> void: journal_requested.emit())
	select_tab(&"inventory")

## Opens the Loadout (&"equipment"; any other id but &"inventory" means it too) or the Inventory.
func select_tab(id: StringName) -> void:
	selected_tab = &"inventory" if id == &"inventory" else &"equipment"
	if is_instance_valid(inspector):
		_body.remove_child(inspector)
		inspector.queue_free()
		inspector = null
	JourneyUI.clear_children(_pages)
	for tab in _tabs: tab.set_pressed_no_signal(tab.name == "Tab_" + String(selected_tab))
	if selected_tab == &"equipment":
		_loadout_view = WorldLoadoutView.new()
		_loadout_view.combat_position = combat_position
		_pages.add_child(_loadout_view)
		_loadout_view.present(_loadout)
		_loadout_view.equip_requested.connect(func(slot: int, item: StringName) -> void: equip_requested.emit(slot, item))
		_loadout_view.unequip_requested.connect(func(slot: int) -> void: unequip_requested.emit(slot))
		_loadout_view.potion_requested.connect(func(slot: int, item: StringName) -> void: potion_requested.emit(slot, item))
		_loadout_view.combat_requested.connect(func(command: StringName, position: int, action: StringName, other: int) -> void:
			combat_position = position
			combat_requested.emit(command, position, action, other))
		_loadout_view.familiar_requested.connect(func(item: StringName) -> void: familiar_requested.emit(item))
		_loadout_view.familiar_passive_requested.connect(func(item: StringName) -> void: familiar_passive_requested.emit(item))
		_loadout_view.position_selected.connect(func(index: int) -> void: combat_position = index)
		first_item = _loadout_view.first_item
		WorldModal.focus_later(first_item)
		_relink.call_deferred()
		return
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	_pages.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 430
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)
	var bag := WorldInventoryView.make(_inventory)
	left.add_child(bag)
	bag.size_flags_vertical = Control.SIZE_EXPAND_FILL
	first_item = bag.first_item
	right.add_child(UITheme.label("Details", UITheme.ACCENT, 22))
	_detail_host = Control.new()
	_detail_host.custom_minimum_size.y = 216
	_detail_host.size_flags_vertical = Control.SIZE_FILL
	right.add_child(_detail_host)
	inspector = JourneyUI.inspector(_body, _detail_host, "CharacterInspector")
	WorldModal.focus_later(first_item)
	inspector.follow_keyboard()
	_relink.call_deferred()

## The tab to reopen after a command.
func selected_tab_id() -> StringName:
	return selected_tab

## The adopted equipment result: the Loadout shows its reconciliation facts concisely.
func present_preparation(result: PreparationResult) -> void:
	if is_instance_valid(_loadout_view):
		_loadout_view.present_preparation(result)

## The adopted arrangement result (no operation event exists for it, so the view confirms it).
func present_combat(result: CombatResult) -> void:
	if is_instance_valid(_loadout_view) and result.changed:
		AudioManager.play(AudioManager.Cue.UI_CONFIRM, 0, -9)

func _relink() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is WorldModal: ancestor = ancestor.get_parent()
	if ancestor is WorldModal: ancestor._link_focus()
