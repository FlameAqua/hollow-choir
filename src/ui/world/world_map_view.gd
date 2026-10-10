class_name WorldMapView
extends Control
## Discovered chart, thin atlas medallions and worn textured path marks. No fast travel.
signal place_selected(index: int)
var readout: WorldMapReadout
var selected: int = -1
var _buttons: Array[Button] = []
var _positions := PackedVector2Array()

func show_readout(value: WorldMapReadout) -> void:
	readout = value
	if not resized.is_connected(_layout): resized.connect(_layout)
	JourneyUI.clear_children(self)
	_buttons.clear()
	for index in readout.landmarks.size():
		var entry: Dictionary = readout.landmarks[index]
		var button := Button.new()
		button.name = "Place%d" % index
		button.text = String(entry.label).replace(" ", "\n")
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(88, 88)
		button.size = Vector2(88, 88)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.tooltip_text = String(entry.label) + "\n" + String(entry.description)
		for state in ["normal", "hover", "pressed", "focus"]:
			var frame := StyleBoxTexture.new()
			frame.texture = UICraft.texture("ring_open")
			frame.set_texture_margin_all(0)
			frame.set_content_margin_all(8)
			frame.modulate_color = Color(1.13, 1.08, .9) if state in ["hover", "focus"] else Color(.72, .76, .68)
			button.add_theme_stylebox_override(state, frame)
		add_child(button)
		_buttons.append(button)
		button.pressed.connect(func() -> void:
			select(index)
			place_selected.emit(index))
		button.focus_entered.connect(func() -> void: select(index))
	_layout.call_deferred()

func select(index: int) -> void:
	selected = index
	for i in _buttons.size(): _buttons[i].modulate = Color(1.15, 1.08, .88) if i == selected else Color.WHITE
	queue_redraw()

func _layout() -> void:
	if readout == null or readout.area_size.x <= 0 or readout.area_size.y <= 0: return
	var chart_scale := minf((size.x - 110) / readout.area_size.x, (size.y - 110) / readout.area_size.y)
	var offset := (size - readout.area_size * chart_scale) * .5
	_positions.clear()
	for entry in readout.landmarks: _positions.append(offset + Vector2(entry.position) * chart_scale)
	for iteration in 100:
		for i in _positions.size():
			for j in range(i + 1, _positions.size()):
				var delta := _positions[j] - _positions[i]
				if delta.length() < 100:
					var away := delta.normalized() if delta.length() > .1 else Vector2.RIGHT
					_positions[i] -= away * 2
					_positions[j] += away * 2
			_positions[i] = _positions[i].clamp(Vector2(48, 48), size - Vector2(48, 48))
	for i in _buttons.size(): _buttons[i].position = (_positions[i] - Vector2(44, 44)).round()
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(UICraft.texture("map"), Rect2(Vector2.ZERO, size), false)
	if readout == null or readout.area_size.x <= 0 or _positions.is_empty(): return
	var chart_scale := minf((size.x - 110) / readout.area_size.x, (size.y - 110) / readout.area_size.y)
	var offset := (size - readout.area_size * chart_scale) * .5
	var texture := preload("res://assets/art/global/ui/journey_v05/map_track.svg")
	for link in readout.links:
		for index in range(1, link.size()):
			var start := _chart_point(Vector2(link[index - 1]), chart_scale, offset)
			var end := _chart_point(Vector2(link[index]), chart_scale, offset)
			var delta := end - start
			var steps := maxi(1, int(delta.length() / 16))
			for step in steps:
				var at := start.lerp(end, float(step) / steps)
				draw_set_transform(at, delta.angle())
				draw_texture_rect(texture, Rect2(-8, -6, 20, 12), false)
	draw_set_transform(Vector2.ZERO)
	for at in _positions: draw_circle(at, 38, Color(.10, .12, .08, .97))
	var player := offset + readout.player_position * chart_scale
	draw_texture_rect(UICraft.texture("hollow_head"), Rect2(player - Vector2(16, 18), Vector2(32, 32)), false)

func _chart_point(point: Vector2, chart_scale: float, offset: Vector2) -> Vector2:
	# Link endpoints follow displaced labels; only published landmark positions are considered.
	var nearest := -1
	var distance := 128.0
	for index in readout.landmarks.size():
		var candidate := point.distance_to(Vector2(readout.landmarks[index].position))
		if candidate < distance:
			distance = candidate
			nearest = index
	return _positions[nearest] if nearest >= 0 else offset + point * chart_scale
