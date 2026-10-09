class_name FamiliarCard
extends Control
## Equipped familiar stands beside the companion. No party slot or turn.
var familiar: FamiliarDefinition
var ledger: PresentationLedger
var _show_art := true
var _pulse: Tween
var _idle: SpriteFrames
var _idle_time := 0.0
## A private presentation clock/RNG never consumes the battle's random stream.
var _fidget_rng := RandomNumberGenerator.new()
var _next_fidget := 12.0
var _fidget_time := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(value: FamiliarDefinition, display: PresentationLedger, show_art: bool = true) -> void:
	familiar = value
	ledger = display
	_show_art = show_art
	_idle = preload("res://assets/art/global/familiars/frames/bell_crow_idle_v03.tres") if familiar != null and familiar.id == &"bell_crow" else null
	_idle_time = 0.0
	_fidget_rng.randomize()
	_next_fidget = _fidget_rng.randf_range(8, 18)
	_fidget_time = -1
	refresh()

func _process(delta: float) -> void:
	if _idle != null and visible and _show_art:
		if Settings.data.reduce_motion:
			_idle_time = 0
			_fidget_time = -1
		else:
			_idle_time += delta
			if _fidget_time >= 0:
				_fidget_time += delta
				if _fidget_time >= _idle.get_frame_count(&"fidget") / _idle.get_animation_speed(&"fidget"):
					_fidget_time = -1
					_next_fidget = _fidget_rng.randf_range(8, 18)
			else:
				_next_fidget -= delta
				if _next_fidget <= 0:
					_fidget_time = 0
		queue_redraw()

func idle_texture() -> Texture2D:
	if _idle != null:
		var animation := &"fidget" if _fidget_time >= 0 else &"idle"
		var elapsed := _fidget_time if _fidget_time >= 0 else _idle_time
		var index := int(elapsed * _idle.get_animation_speed(animation)) % _idle.get_frame_count(animation)
		return _idle.get_frame_texture(animation, index)
	return familiar.portrait if familiar != null else null

func refresh() -> void:
	visible = familiar != null
	queue_redraw()

func plain_text() -> String:
	if familiar == null:
		return "No familiar in this loadout."
	return "%s\n%s\n%s\n%s · no turn cost" % [familiar.display_name, "Ready this round" if ledger == null or ledger.familiar_ready() else "Used this round", familiar.description, limit_text()]

func limit_text() -> String:
	var limit := ledger.familiar_limit if ledger != null else 0
	match limit:
		0: return "No limit"
		1: return "Once per round"
		2: return "Twice per round"
	return "%d times per round" % limit

func _get_tooltip(_point: Vector2) -> String:
	return plain_text()

func pulse(reduce_motion: bool) -> void:
	refresh()
	if reduce_motion:
		return
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	modulate = Color(1.25, 1.2, 1.05)
	_pulse = create_tween()
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.6)

func _draw() -> void:
	if familiar == null:
		return
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.ACCENT, false, 2)
	draw_ellipse_shadow()
	if familiar.portrait != null and _show_art:
		draw_texture_rect(idle_texture(), art_rect(), false)
	else:
		# Explicit procedural fallback for familiars without painted art.
		draw_rect(Rect2(9, 22, 31, 19), UITheme.ACCENT)
		draw_rect(Rect2(30, 12, 18, 20), UITheme.TEXT_DIM)
		draw_rect(Rect2(39, 17, 4, 4), UITheme.BG)
		draw_rect(Rect2(10, 40, 5, 12), UITheme.TEXT_DIM)
		draw_rect(Rect2(32, 40, 5, 12), UITheme.TEXT_DIM)
	# Readiness and trigger limits are explicit in inspection; no unexplained stage marker.

func draw_ellipse_shadow() -> void:
	draw_rect(Rect2(5, size.y - 7, size.x - 10, 4), Color(0, 0, 0, 0.3))

func art_rect() -> Rect2:
	var source := idle_texture().get_size()
	var floor_y := maxf(0, size.y - 8)
	var drawn := source * maxf(0, minf(size.x / source.x, floor_y / source.y))
	return Rect2(Vector2((size.x - drawn.x) * 0.5, floor_y - drawn.y), drawn)

func stage_size() -> Vector2:
	return (Vector2(52, 58) * (familiar.display_scale if familiar != null else 1.0)).round()
