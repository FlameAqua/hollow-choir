class_name FamiliarCard
extends Control
## Equipped familiar stands beside the companion. No party slot or turn.
var familiar: FamiliarDefinition
var ledger: PresentationLedger
var _show_art := true
var _pulse: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(value: FamiliarDefinition, display: PresentationLedger, show_art: bool = true) -> void:
	familiar = value
	ledger = display
	_show_art = show_art
	refresh()

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
		draw_texture_rect(familiar.portrait, art_rect(), false)
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
	var source := familiar.portrait.get_size()
	var floor_y := maxf(0, size.y - 8)
	var drawn := source * maxf(0, minf(size.x / source.x, floor_y / source.y))
	return Rect2(Vector2((size.x - drawn.x) * 0.5, floor_y - drawn.y), drawn)

func stage_size() -> Vector2:
	return (Vector2(52, 58) * (familiar.display_scale if familiar != null else 1.0)).round()
