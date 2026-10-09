class_name FieldGuide
extends Control
## Read-only view of existing saved knowledge and weapon practice. Footer stays outside scrolling.

## Emitted instead of routing to the title when a host (the paused world) embedded this screen.
signal closed

## Set by a host before the node enters the tree: keep the host's music and return via [signal closed].
var embedded := false
var _tabs: TabContainer
var _choices: OptionButton
var _scroll: ScrollContainer
var _details: VBoxContainer
var _back: Button
var _readouts: Array[FieldGuideReadout] = []

func _ready() -> void:
	if not embedded:
		GameState.resume_session()
		AudioManager.request_music(&"global_title")
	var background := ColorRect.new()
	background.color = UITheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(UITheme.label("Field Guide", UITheme.ACCENT, UITheme.font_size(1.5)))
	column.add_child(UITheme.label("Saved knowledge and weapon practice.", UITheme.TEXT_DIM, -1, true))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_bestiary()
	_build_mastery()
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.y = UITheme.control_height()
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(_leave)
	column.add_child(_back)
	_tabs.tab_changed.connect(func(_index: int) -> void: AudioManager.play(AudioManager.Cue.UI_MOVE))
	if not _readouts.is_empty():
		_choices.grab_focus.call_deferred()
	else:
		_back.grab_focus.call_deferred()

func _build_bestiary() -> void:
	var page := VBoxContainer.new()
	page.name = "Bestiary"
	_tabs.add_child(page)
	_choices = UITheme.selector()
	_choices.custom_minimum_size.y = UITheme.control_height()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices.fit_to_longest_item = false
	page.add_child(_choices)
	var registry := Database.registry
	for id in registry.sorted_ids(registry.enemies):
		var readout := FieldGuideReadout.build(registry.enemies[id], GameState.progress.bestiary, registry.research)
		if readout != null:
			_readouts.append(readout)
	_readouts.sort_custom(func(a: FieldGuideReadout, b: FieldGuideReadout) -> bool: return a.title < b.title)
	for readout in _readouts:
		_choices.add_item(readout.title + " · " + EnumText.research_level(readout.level))
	_choices.visible = not _readouts.is_empty()
	_choices.item_selected.connect(_select)
	_scroll = _make_scroll(page)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 12)
	_scroll.add_child(_details)
	if _readouts.is_empty():
		_details.add_child(UITheme.label("No field notes yet", UITheme.ACCENT, -1, true))
		_details.add_child(UITheme.label("Read an intent. Inspect a creature. Learn what changes your plan.", UITheme.TEXT, -1, true))
		_details.add_child(UITheme.label("Win encounters on your journey to save research here. You can also record battles in Combat Sandbox → Lab. Practice is always unrecorded.", UITheme.TEXT_DIM, -1, true))
	else:
		_select(0)

func _select(index: int) -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var readout := _readouts[index]
	_details.add_child(UITheme.label(readout.progress_text, UITheme.TEXT_DIM, -1, true))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.value = readout.progress_fraction * 100.0
	bar.custom_minimum_size.y = 8
	_details.add_child(bar)
	if readout.portrait != null:
		var portrait := TextureRect.new()
		portrait.texture = readout.portrait
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size.y = 160
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_details.add_child(portrait)
	for section in readout.sections:
		_details.add_child(UITheme.label(section.heading, UITheme.ACCENT, -1, true))
		_details.add_child(UITheme.label(section.body, UITheme.TEXT, -1, true))
	_scroll.scroll_vertical = 0

func _build_mastery() -> void:
	var page := VBoxContainer.new()
	page.name = "Weapon practice"
	_tabs.add_child(page)
	var scroll := _make_scroll(page)
	var records := VBoxContainer.new()
	records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	records.add_theme_constant_override("separation", 16)
	scroll.add_child(records)
	records.add_child(UITheme.label("Recorded practice", UITheme.ACCENT, -1, true))
	records.add_child(UITheme.label("One point per weapon action, plus one for a Perfect. These totals are a practice record; they grant no stat bonuses or unlocks in this build.", UITheme.TEXT_DIM, -1, true))
	var progress := GameState.progress
	var ids: Array[StringName] = progress.owned_equipment.duplicate()
	for id: StringName in progress.weapon_mastery:
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	for id in ids:
		var weapon: WeaponDefinition = Database.registry.weapons.get(id)
		if weapon == null:
			continue
		var points: int = progress.weapon_mastery.get(id, 0)
		records.add_child(UITheme.label(weapon.display_name + " · " + EnumText.family(weapon.family), UITheme.ACCENT, -1, true))
		records.add_child(UITheme.label("%d practice points" % points if points > 0 else "No recorded practice yet", UITheme.TEXT, -1, true))

func _make_scroll(page: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	page.add_child(scroll)
	return scroll

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.CANCEL) or event.is_action_pressed(InputBindings.MENU):
		get_viewport().set_input_as_handled()
		_leave()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var scroll := _scroll if _tabs.current_tab == 0 else _tabs.get_current_tab_control().get_child(0) as ScrollContainer
		scroll.scroll_vertical += roundi(scroll.size.y * 0.8) * (-1 if event.keycode == KEY_PAGEUP else 1)
		get_viewport().set_input_as_handled()

func _leave() -> void:
	AudioManager.play(AudioManager.Cue.UI_CANCEL)
	if embedded:
		closed.emit()
	else:
		SceneRouter.goto(SceneRouter.MAIN_MENU)
