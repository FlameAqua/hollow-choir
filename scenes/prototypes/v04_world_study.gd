extends Control
## F6-only presentation/blockout study. No player movement, collision, progress or production entry.
## Layout lives under docs on purpose: this development scene is not an exported game feature.

var _layout: Dictionary
var _area_index := 0
var _restored := false
var _hud: ExplorationHUD
var _study_controls: HFlowContainer
var _overlay: PanelContainer
var _map_body: Label
var _capture := ""


func _ready() -> void:
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/world/v04_layout.json"))
	var preset := GameSettings.BASE_RESOLUTION
	for argument in OS.get_cmdline_user_args():
		if argument == "--study-area=briarfen":
			_area_index = 1
		elif argument == "--study-restored":
			_restored = true
		elif argument.begins_with("--study-size="):
			var dimensions := argument.trim_prefix("--study-size=").split("x")
			preset = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument.begins_with("--study-capture="):
			_capture = argument.trim_prefix("--study-capture=")
	if not GameSettings.RESOLUTIONS.has(preset):
		push_error("Study size must be a supported game resolution preset")
		get_tree().quit(1)
		return
	Settings.data.window_resolution = preset
	Settings.apply() # In-memory preview only; never writes the settings file.
	theme = UITheme.build()
	_hud = ExplorationHUD.new()
	_hud.prompt_bottom_inset = 105.0
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.map_requested.connect(_show_map)
	_hud.menu_requested.connect(_show_menu)
	_study_controls = HFlowContainer.new()
	_study_controls.add_theme_constant_override("h_separation", 12)
	add_child(_study_controls)
	_study_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_study_controls.offset_left = 24
	_study_controls.offset_right = -24
	_study_controls.offset_top = -80
	_study_controls.offset_bottom = -20
	_button(_study_controls, "Gloamstead", func() -> void: _select_area(0))
	_button(_study_controls, "Reedway", func() -> void: _select_area(1))
	_button(_study_controls, "Before / after", func() -> void:
		_restored = not _restored
		_refresh())
	_study_controls.minimum_size_changed.connect(_layout_study_controls.call_deferred)
	_hud._prompt.minimum_size_changed.connect(queue_redraw)
	_build_overlay()
	resized.connect(queue_redraw)
	resized.connect(_layout_study_controls.call_deferred)
	_refresh()
	_layout_study_controls.call_deferred()
	if not _capture.is_empty():
		_capture_frame.call_deferred()


func _select_area(index: int) -> void:
	_area_index = index
	_refresh()


func _refresh() -> void:
	var area: Dictionary = _layout.areas[_area_index]
	var readout := ExplorationReadout.new()
	readout.area_name = area.name
	readout.objective = "Find the wayside bell."
	if _restored:
		readout.objective = "The town bell answers again." if _area_index == 0 else "Return to Gloamstead."
	readout.interaction = "Speak to the Bellkeeper" if _area_index == 0 else "Inspect the wayside bell"
	readout.interaction_binding = InputBindings.prompt(InputBindings.CONFIRM)
	_hud.present(readout)
	queue_redraw()


func _layout_study_controls() -> void:
	_study_controls.size.x = maxf(0, size.x - 48)
	_study_controls.size.y = _study_controls.get_combined_minimum_size().y
	_study_controls.position = Vector2(24, size.y - 24 - _study_controls.size.y)
	_hud.prompt_bottom_inset = _study_controls.size.y + 40
	_hud._layout_prompt()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BG)
	if _layout.is_empty():
		return
	var area: Dictionary = _layout.areas[_area_index]
	var dimensions := Vector2(area.size_tiles[0], area.size_tiles[1])
	var top := maxf(160, _hud._objective.get_global_rect().end.y + 24)
	var bottom := _hud._prompt.position.y - 60
	var plot := Rect2(Vector2(40, top), Vector2(maxf(1, size.x - 80), maxf(1, bottom - top)))
	var unit := minf(plot.size.x / dimensions.x, plot.size.y / dimensions.y)
	var origin := plot.position + (plot.size - dimensions * unit) * 0.5
	draw_rect(Rect2(origin, dimensions * unit), UITheme.PANEL)
	for facade: Dictionary in area.get("facades", []):
		var r: Array = facade.rect_tiles
		draw_rect(Rect2(origin + Vector2(r[0], r[1]) * unit, Vector2(r[2], r[3]) * unit), UITheme.PANEL_LIGHT)
	for path: Dictionary in area.paths:
		var points := PackedVector2Array()
		for point: Array in path.points:
			points.append(origin + Vector2(point[0], point[1]) * unit)
		var open := not path.has("requires_flag") or _restored
		draw_polyline(points, UITheme.BORDER if open else UITheme.TEXT_FAINT, maxf(2, path.width_tiles * unit), false)
	for landmark: Dictionary in area.landmarks:
		var point := origin + Vector2(landmark.tile[0], landmark.tile[1]) * unit
		var color := UITheme.THREAT if landmark.kind == "encounter" else UITheme.ACCENT
		if landmark.id == "town_bell" and _restored:
			color = UITheme.HEART
		draw_circle(point, maxf(5, unit), color)
	var study_label := "DESIGN STUDY · no movement or saves"
	draw_string(UITheme.PIXEL_FONT, Vector2(24, _hud._prompt.position.y - 18), study_label,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 22, UITheme.TEXT_DIM)


func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.add_theme_stylebox_override("panel", ExplorationHUD.FRAME)
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.offset_left = 24
	_overlay.offset_right = -24
	_overlay.offset_top = 24
	_overlay.offset_bottom = -24
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_overlay.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_map_body = UITheme.label("", UITheme.TEXT, -1, true)
	_map_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_map_body)
	_button(column, "Close", _close_overlay)
	_overlay.hide()


func _show_map() -> void:
	var area: Dictionary = _layout.areas[_area_index]
	var names := PackedStringArray()
	for landmark: Dictionary in area.landmarks:
		names.append(landmark.name)
	_map_body.text = "Local map · presentation study\n\n%s\n\n%s\n\nThis study shows the authored layout. The runtime map must receive discovered landmarks only; there is no fast travel." % [
		area.name, "\n".join(names)]
	_open_overlay()


func _show_menu() -> void:
	_map_body.text = "World menu · presentation study\n\nPlanned actions: Resume, Field Guide, Settings, Save and return to title.\n\nThe playable world host, save boundaries, dialogue and map are Claude's next implementation stage. This scene changes no saves or settings."
	_open_overlay()


func _open_overlay() -> void:
	_overlay.show()
	_hud.hide()
	_study_controls.hide()
	(_overlay.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func _close_overlay() -> void:
	_overlay.hide()
	_hud.show()
	_study_controls.show()
	_hud.focus_map()


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed(InputBindings.CANCEL):
		get_viewport().set_input_as_handled()
		_close_overlay()


func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = UITheme.control_height()
	button.pressed.connect(callback)
	parent.add_child(button)


func _capture_frame() -> void:
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_capture)
	print("World presentation study capture: %s (%s)" % [_capture, error])
	print("Fixed display: window=%s canvas=%s body=%s unresizable=%s" % [get_window().size,
		get_viewport_rect().size, _hud._objective.get_theme_font_size("font_size"), get_window().unresizable])
	get_tree().quit(error)
