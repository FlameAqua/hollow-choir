class_name MainMenu
extends Control
## Scenic title menu: Continue (typed save summaries, newest first), New Journey (difficulty and
## starter preset, then an explicit save slot; GameState.start_journey writes and adopts it),
## Settings, Credits and Quit. Browsing never loads, writes or changes the active slot.

const TITLE_BACKDROP := preload("res://assets/art/environments/briarfen/briarfen_marsh_night_1.png")
const FRAME := preload("res://assets/art/global/ui/frames/choir_v01/styles/panel.tres")
const RAISED := preload("res://assets/art/global/ui/frames/choir_v01/styles/raised.tres")
const SELECTED := preload("res://assets/art/global/ui/frames/choir_v01/styles/selected.tres")
const FOCUS_FRAME := preload("res://assets/art/global/ui/frames/choir_v01/styles/focus.tres")

var _first_button: Button
var _new_button: Button
var _menu_panel: PanelContainer
var _column: VBoxContainer
signal new_journey_requested(options: Dictionary)
var _modal: WorldModal
var _preset: StringName = &"pilgrims_edge"
var _difficulty := 1
var _setup: JourneySetupReadout
## Entering the world after a successful load or New Journey (tests replace it; never called on failure).
var enter_world := func() -> void: SceneRouter.goto(SceneRouter.WORLD)
## The New Journey writer for GameState.start_journey (tests inject failures; default SaveManager).
var journey_writer := Callable()


func _ready() -> void:
	# The New Journey listener is connected before any setup can open (V0.5 UI backend seam).
	new_journey_requested.connect(_on_new_journey_requested)
	_setup = JourneyRules.setup(Database.registry, SaveManager.summaries(), int(Settings.data.tactical_difficulty))
	_difficulty = _setup.default_difficulty
	_preset = _setup.default_preset
	AudioManager.request_music(&"global_title")
	var backdrop := TextureRect.new()
	backdrop.texture = TITLE_BACKDROP
	var scenic_material := ShaderMaterial.new()
	scenic_material.shader = preload("res://src/ui/title_soften.gdshader")
	backdrop.material = scenic_material
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.018, 0.032, 0.027, 0.97))
	gradient.set_color(1, Color(0.025, 0.045, 0.035, 0.2))
	var veil := GradientTexture2D.new()
	veil.gradient = gradient
	veil.fill_from = Vector2.ZERO
	veil.fill_to = Vector2(0.85, 0)
	var shade := TextureRect.new()
	shade.texture = veil
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(TitleAtmosphere.new())
	_menu_panel = PanelContainer.new()
	_menu_panel.name = "TitleComposition"
	_menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_menu_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_menu_panel.add_child(margin)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 8)
	margin.add_child(_column)
	var title := TextureRect.new()
	title.name = "Wordmark"
	title.texture = UICraft.texture("wordmark")
	title.material = scenic_material
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title.custom_minimum_size.y = 120
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(title)
	var title_space := Control.new()
	title_space.custom_minimum_size.y = 22
	_column.add_child(title_space)
	_first_button = _button("Continue Journey", func() -> void: _open_save_picker())
	_first_button.disabled = _saves().is_empty()
	_first_button.tooltip_text = "No saved journeys yet." if _first_button.disabled else "Choose a saved journey. Newest first."
	_new_button = _button("New Journey", _open_new_journey)
	_new_button.tooltip_text = "Choose your starter set and difficulty, then a save place for your journey."
	_button("Settings", func() -> void: SceneRouter.goto(SceneRouter.SETTINGS))
	_button("Credits", _open_credits)
	_button("Quit", func() -> void: get_tree().quit())
	var version := UITheme.label("v%s" % ProjectSettings.get_setting("application/config/version", "0"), UITheme.TEXT_DIM, 22)
	version.name = "Version"
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(size.x - 220, size.y - 52)
	version.size = Vector2(192, 26)
	if not Database.problems.is_empty():
		_first_button.tooltip_text = "Some content could not load. See the diagnostic log."
	resized.connect(_layout_menu)
	_menu_panel.minimum_size_changed.connect(_layout_menu.call_deferred)
	_layout_menu()
	TooltipPolicy.install(self)
	(_new_button if _first_button.disabled else _first_button).grab_focus.call_deferred()


## The loadable journeys, newest first (equal times by slot number).
func _saves() -> Array[SaveSlotSummary]:
	return SaveManager.journeys()


## "Journey 2 · 2026-10-10 14:03 UTC" plus a second line of public facts (or the damage reason).
## [param suffix] ends the first line (the slot step adds its Replace hint there).
static func slot_text(entry: SaveSlotSummary, suffix: String = "") -> String:
	if entry.state == SaveSlotSummary.State.EMPTY:
		return "%s   ·   %s" % [entry.label(), WorldCopy.SAVE_SLOT_EMPTY]
	var first := PackedStringArray([entry.label()])
	if entry.saved_at_unix > 0 or entry.loadable():
		first.append(entry.saved_at_text)
	if not suffix.is_empty():
		first.append(suffix)
	if not entry.loadable():
		return "%s\n%s" % ["   ·   ".join(first), entry.reason_text]
	var facts := PackedStringArray([entry.difficulty_name])
	if not entry.weapon_name.is_empty():
		facts.append(entry.weapon_name)
	facts.append(WorldCopy.SAVE_SLOT_VICTORY % entry.battles_won if entry.battles_won == 1 else WorldCopy.SAVE_SLOT_VICTORIES % entry.battles_won)
	return "%s\n%s" % ["   ·   ".join(first), "   ·   ".join(facts)]


func _show(view: WorldModal) -> void:
	if is_instance_valid(_modal):
		remove_child(_modal)
		_modal.queue_free()
	_modal = view
	add_child(view)
	view.cancel_id = &"back"


func _back() -> void:
	if is_instance_valid(_modal):
		remove_child(_modal)
		_modal.queue_free()
	_modal = null
	WorldModal.focus_later(_first_button if not _first_button.disabled else _new_button)


## Readable journeys newest first, then any damaged or newer-version slot as a disabled entry with its
## reason. A load that fails (the file changed since the list was built) keeps the live journey and
## the active slot, says so and rebuilds the list from the current files.
func _open_save_picker(status: String = "") -> void:
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 12)
	var listed: Array[SaveSlotSummary] = _saves()
	for entry in SaveManager.summaries():
		if entry.occupied() and not entry.loadable():
			listed.append(entry)
	for entry in listed:
		var button := _slot_card(entry)
		button.name = "SaveSlot_%d" % entry.slot
		button.disabled = not entry.loadable()
		button.tooltip_text = entry.reason_text
		entries.add_child(button)
		var slot := entry.slot
		button.pressed.connect(func() -> void:
			if SaveManager.load_slot(slot) != OK:
				_open_save_picker(WorldCopy.SAVE_LOAD_FAILED)
				return
			enter_world.call())
	_show(WorldModal.make(&"saves", "Continue Journey", PackedStringArray(), [WorldDialogueReadout.action(&"back", "Back")], entries))
	_modal.set_status(status)
	_modal.chosen.connect(func(_id: StringName) -> void: _back())
	for child in entries.get_children():
		if not (child as Button).disabled:
			WorldModal.focus_later(child)
			break


func _open_new_journey() -> void:
	_setup = JourneyRules.setup(Database.registry, SaveManager.summaries(), _difficulty)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.add_child(UITheme.label("Difficulty", UITheme.ACCENT, 22))
	var difficulties := HBoxContainer.new()
	content.add_child(difficulties)
	var group := ButtonGroup.new()
	for entry in _setup.difficulties:
		var index: int = entry.id
		var button := Button.new()
		button.name = "Difficulty_%d" % index
		button.text = entry.name
		button.tooltip_text = entry.description
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(index == _difficulty)
		button.custom_minimum_size = Vector2(190, 48)
		difficulties.add_child(button)
		button.pressed.connect(func() -> void: _difficulty = index)
	content.add_child(UITheme.label("Starter set", UITheme.ACCENT, 22))
	var presets := HBoxContainer.new()
	content.add_child(presets)
	var preset_group := ButtonGroup.new()
	for entry in _setup.presets:
		var id: StringName = entry.id
		var payload := JourneyUI.facts(entry.name, entry.description, entry.category, load(entry.icon_path) if not String(entry.icon_path).is_empty() else null)
		payload.facts = entry.facts
		payload.details = entry.details
		var button := JourneyUI.button(payload, Vector2(100, 100))
		button.name = "Preset_" + String(id)
		button.toggle_mode = true
		button.button_group = preset_group
		button.set_pressed_no_signal(id == _preset)
		presets.add_child(button)
		button.pressed.connect(func() -> void: _preset = id)
	content.add_child(UITheme.label(WorldCopy.JOURNEY_SETUP_NOTE, UITheme.TEXT_DIM, 22, true))
	_show(WorldModal.make(&"new_journey", "New Journey", PackedStringArray(),
		[WorldDialogueReadout.action(&"back", "Back"), WorldDialogueReadout.action(&"start", WorldCopy.JOURNEY_CHOOSE_SAVE)], content))
	_modal.button(&"start").disabled = new_journey_requested.get_connections().is_empty()
	_modal.button(&"start").tooltip_text = "Choose a save slot for this journey next."
	_modal.chosen.connect(func(id: StringName) -> void:
		if id == &"back": _back()
		else: new_journey_requested.emit({"difficulty": _difficulty, "preset_id": _preset}))


## The New Journey listener: setup choices arrive without a slot, so the player chooses one
## explicitly (an occupied slot only after a separate Replace confirmation). The request then goes to
## GameState.start_journey; success enters the world, anything else returns to the slot list with
## the typed reason and every save unchanged (choosing again retries the same request).
func _on_new_journey_requested(options: Dictionary) -> void:
	if not options.has(JourneyRules.SLOT):
		_open_slot_choice(options)
		return
	var result := GameState.start_journey(options, journey_writer)
	if result.ok():
		enter_world.call()
		return
	_open_slot_choice(options, result.text())


func _open_slot_choice(options: Dictionary, status: String = "") -> void:
	# Each choice starts from the setup alone: a slot or a replacement is never carried over.
	var base := options.duplicate()
	base.erase(JourneyRules.SLOT)
	base.erase(JourneyRules.REPLACE)
	_setup = JourneyRules.setup(Database.registry, SaveManager.summaries(), _difficulty)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 12)
	var first: Button = null
	for entry in _setup.slots:
		var button := _slot_card(entry, true)
		button.name = "JourneySlot_%d" % entry.slot
		entries.add_child(button)
		var chosen := entry
		button.pressed.connect(func() -> void:
			var request := base.duplicate()
			request[JourneyRules.SLOT] = chosen.slot
			if chosen.occupied():
				_confirm_replace(request, chosen)
			else:
				new_journey_requested.emit(request))
		if entry.slot == _setup.suggested_slot or (first == null and _setup.all_full()):
			first = button
	_show(WorldModal.make(&"journey_slot", WorldCopy.JOURNEY_SLOT_TITLE, PackedStringArray(),
		[WorldDialogueReadout.action(&"back", WorldCopy.JOURNEY_BACK_TO_SETUP)], entries, 1000, _journey_recap(base)))
	_modal.set_status(status if not status.is_empty() else (WorldCopy.JOURNEY_SLOTS_FULL if _setup.all_full() else ""))
	_modal.chosen.connect(func(_id: StringName) -> void: _open_new_journey())
	WorldModal.focus_later(first if first != null else entries.get_child(0))


## Replacing an occupied slot needs this deliberate decision; Cancel is focused.
func _confirm_replace(request: Dictionary, entry: SaveSlotSummary) -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	var existing := _slot_card(entry)
	existing.name = "ReplacementJourney"
	existing.focus_mode = Control.FOCUS_NONE
	existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(existing)
	content.add_child(UITheme.label(WorldCopy.JOURNEY_REPLACE_BODY % entry.label(), UITheme.DANGER, 22, true))
	content.add_child(_journey_recap(request))
	_show(WorldModal.make(&"journey_replace", WorldCopy.JOURNEY_REPLACE_TITLE % (entry.slot + 1),
		PackedStringArray(),
		[WorldDialogueReadout.action(&"cancel", WorldCopy.ACTION_CANCEL),
		WorldDialogueReadout.action(&"replace", WorldCopy.JOURNEY_REPLACE_ACTION % (entry.slot + 1))], content))
	_modal.button(&"replace").add_theme_color_override("font_color", UITheme.DANGER)
	_modal.cancel_id = &"cancel"
	_modal.chosen.connect(func(id: StringName) -> void:
		if id == &"replace":
			var confirmed := request.duplicate()
			confirmed[JourneyRules.REPLACE] = true
			new_journey_requested.emit(confirmed)
		else:
			var back := request.duplicate()
			back.erase(JourneyRules.SLOT)
			_open_slot_choice(back))
	WorldModal.focus_later(_modal.button(&"cancel"))


## One focusable choice, with a stable reading order and wrapped damage reasons.
## All children ignore the pointer so the whole card remains the button's hit area.
static func _slot_card(entry: SaveSlotSummary, choosing: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 110
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = slot_text(entry)
	button.add_theme_stylebox_override("normal", UICraft.panel("inspection", 18, 12))
	button.add_theme_stylebox_override("hover", UICraft.panel("selected", 18, 12))
	button.add_theme_stylebox_override("focus", UICraft.panel("selected", 18, 12, Color(1.15, 1.1, .95)))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	button.add_child(margin)
	margin.minimum_size_changed.connect(func() -> void:
		button.custom_minimum_size.y = maxf(110, margin.get_combined_minimum_size().y))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	row.add_child(JourneyUI.picture(JourneyUI.icon("save"), Vector2(40, 40)))
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	row.add_child(copy)
	var heading := HBoxContainer.new()
	copy.add_child(heading)
	var title := UITheme.label(entry.label(), UITheme.ACCENT, 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	if choosing:
		var intent := UITheme.label(WorldCopy.JOURNEY_REPLACE_HINT if entry.occupied() else WorldCopy.JOURNEY_BEGIN_HERE,
			UITheme.DANGER if entry.occupied() else UITheme.INFO, 22)
		intent.name = "SlotIntent"
		heading.add_child(intent)
	if entry.loadable():
		copy.add_child(UITheme.label(entry.saved_at_text, UITheme.TEXT_DIM, 22))
		copy.add_child(UITheme.label(" · ".join(PackedStringArray([entry.difficulty_name, entry.weapon_name,
			WorldCopy.SAVE_SLOT_VICTORY % entry.battles_won if entry.battles_won == 1 else WorldCopy.SAVE_SLOT_VICTORIES % entry.battles_won])), UITheme.TEXT, 22, true))
	else:
		copy.add_child(UITheme.label(entry.reason_text if entry.occupied() else WorldCopy.SAVE_SLOT_FREE, UITheme.TEXT_DIM, 22, true))
	for child in button.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _journey_recap(options: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "JourneyRecap"
	panel.add_theme_stylebox_override("panel", UICraft.panel("header", 16, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var preset := _setup.preset(StringName(options.get(JourneyRules.PRESET, _preset)))
	var difficulty := _setup.difficulty(int(options.get(JourneyRules.DIFFICULTY, _difficulty)))
	if not preset.is_empty() and not String(preset.icon_path).is_empty():
		row.add_child(JourneyUI.picture(load(preset.icon_path), Vector2(44, 44)))
	var label := UITheme.label("%s · %s" % [preset.get("name", ""), difficulty.get("name", "")], UITheme.TEXT, 22, true)
	label.name = "JourneyChoices"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return panel


func _open_credits() -> void:
	_show(WorldModal.make(&"credits", "Credits & Updates", PackedStringArray([
		"Hollow Choir", "Credits and development updates will be added here during Beta.",
		"V0.5 · Salvage, equipment, the Forge, the Stillroom and listening stones."]),
		[WorldDialogueReadout.action(&"back", "Back")]))
	_modal.chosen.connect(func(_id: StringName) -> void: _back())


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		_show(WorldModal.make(&"debug", "Development tools", PackedStringArray(), [
			WorldDialogueReadout.action(&"sandbox", "Combat Sandbox"), WorldDialogueReadout.action(&"audio", "Audio Lab"),
			WorldDialogueReadout.action(&"world", "Preview journey"), WorldDialogueReadout.action(&"back", "Back")]))
		_modal.chosen.connect(func(id: StringName) -> void:
			if id == &"sandbox": SceneRouter.goto(SceneRouter.SANDBOX)
			elif id == &"audio": SceneRouter.goto(SceneRouter.AUDIO_LAB)
			elif id == &"world": SceneRouter.goto(SceneRouter.WORLD)
			else: _back())
		get_viewport().set_input_as_handled()


func _layout_menu() -> void:
	if _menu_panel == null:
		return
	var inset := minf(40, size.x * 0.04)
	var width := minf(size.x - inset * 2, maxf(440, size.x * 0.43))
	_menu_panel.position = Vector2(inset, size.y * .12)
	_menu_panel.size = Vector2(width, maxf(120, size.y * .70))


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = UITheme.control_height()
	button.add_theme_stylebox_override("normal", UICraft.panel("technique", 12, 4))
	button.add_theme_stylebox_override("hover", UICraft.panel("selected", 12, 4))
	button.add_theme_stylebox_override("focus", UICraft.panel("selected", 12, 4))
	button.pressed.connect(func() -> void:
		AudioManager.play(AudioManager.Cue.UI_CONFIRM)
		callback.call())
	_column.add_child(button)
	return button
