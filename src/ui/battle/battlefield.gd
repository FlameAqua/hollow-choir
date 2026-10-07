class_name Battlefield
extends Control
## The stage: a fen-at-dusk backdrop tinted by the active battlefield conditions (the environment is
## always visible, GDD "Battlefield conditions"), unit views in formation, intent bubbles above the
## enemies, and screen shake. Positions are fractions of the stage so any window size works.

signal unit_clicked(uid: int)
## uid of the unit under the pointer, or -1 when the pointer leaves it.
signal unit_hovered(uid: int)

## Bottom-centre of each unit view as a fraction of the stage. Party on the left facing right.
const PARTY_SLOTS := [Vector2(0.25, 0.98), Vector2(0.11, 0.86)]
const ENEMY_SLOTS := {
	1: [Vector2(0.70, 0.98)],
	2: [Vector2(0.60, 0.98), Vector2(0.81, 0.86)],
	3: [Vector2(0.56, 0.98), Vector2(0.71, 0.84), Vector2(0.86, 0.98)],
	4: [Vector2(0.53, 0.98), Vector2(0.65, 0.82), Vector2(0.77, 0.98), Vector2(0.89, 0.82)],
}
const HORIZON := 0.38
const SKY_TOP := Color("141826")
const SKY_BOTTOM := Color("2b3140")
const GROUND_TOP := Color("1d241f")
const GROUND_BOTTOM := Color("121612")
const MOTES := 28

var engine: BattleEngine
var views: Dictionary[int, UnitView] = {}
var bubbles: Dictionary[int, IntentBubble] = {}
var screen_shake := true

var _stage: Control
var _shake := 0.0
var _time := 0.0
var _scenery_seed := 1
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	resized.connect(_layout)


func setup(p_engine: BattleEngine, reduce_flashing: bool) -> void:
	engine = p_engine
	_scenery_seed = hash(engine.ctx.setup.label) if not engine.ctx.setup.label.is_empty() else 7
	for child in _stage.get_children():
		child.queue_free()
	views.clear()
	bubbles.clear()
	for unit in engine.get_state().units:
		var view := UnitView.new()
		view.name = "Unit%d" % unit.uid
		view.reduce_flashing = reduce_flashing
		_stage.add_child(view)
		view.setup(unit)
		view.clicked.connect(func(uid: int) -> void: unit_clicked.emit(uid))
		view.hovered.connect(func(uid: int) -> void: unit_hovered.emit(uid))
		view.mouse_exited.connect(func() -> void: unit_hovered.emit(-1))
		views[unit.uid] = view
		if unit.is_enemy():
			var bubble := IntentBubble.new()
			bubble.name = "Intent%d" % unit.uid
			bubble.enemy_uid = unit.uid
			bubble.visible = false
			_stage.add_child(bubble)
			bubble.hovered.connect(func(uid: int) -> void: unit_hovered.emit(uid))
			bubble.mouse_exited.connect(func() -> void: unit_hovered.emit(-1))
			bubbles[unit.uid] = bubble
	_layout()


func view(uid: int) -> UnitView:
	return views.get(uid)


## Global position of a unit's body centre (reaction rings, projectiles).
func body_point(uid: int) -> Vector2:
	var unit_view := view(uid)
	return unit_view.anchor_center() if unit_view != null else global_position + size * 0.5


## Global position just above a unit (floating text).
func top_point(uid: int) -> Vector2:
	var unit_view := view(uid)
	return unit_view.anchor_top() if unit_view != null else global_position + size * 0.5


## Direction the unit lunges when it acts.
func forward(uid: int) -> Vector2:
	var unit := engine.get_unit(uid) if engine != null else null
	return Vector2.LEFT if unit != null and unit.is_enemy() else Vector2.RIGHT


func set_active(uid: int) -> void:
	for key: int in views:
		views[key].active = key == uid


func set_highlight(uid: int) -> void:
	for key: int in views:
		views[key].highlighted = key == uid


## Rebuilds every intent bubble from the engine's current intents.
func refresh_intents() -> void:
	if engine == null:
		return
	for uid: int in bubbles:
		var unit := engine.get_unit(uid)
		var bubble := bubbles[uid]
		if unit == null or not unit.is_alive() or unit.intent == null:
			bubble.show_intent(null, "")
			continue
		var preview := engine.preview_intent(uid)
		bubble.show_intent(preview, target_names(preview))
	_layout_bubbles()


## Shows one enemy's telegraph with a short pop (intent declared / changed).
func show_intent(uid: int, preview: IntentPreview) -> void:
	var bubble: IntentBubble = bubbles.get(uid)
	if bubble == null:
		return
	bubble.show_intent(preview, target_names(preview))
	_layout_bubbles()
	bubble.pivot_offset = IntentBubble.SIZE * 0.5
	bubble.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.18)


func hide_intent(uid: int) -> void:
	var bubble: IntentBubble = bubbles.get(uid)
	if bubble != null:
		bubble.show_intent(null, "")


func hide_all_intents() -> void:
	for uid: int in bubbles:
		bubbles[uid].show_intent(null, "")


func refresh_units() -> void:
	for key: int in views:
		views[key].queue_redraw()


func shake(strength: float) -> void:
	if screen_shake:
		_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	_time += delta
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		_stage.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.6)
	elif _stage.position != Vector2.ZERO:
		_stage.position = Vector2.ZERO
	queue_redraw()


func target_names(preview: IntentPreview) -> String:
	if preview == null or preview.action.target_rule == Enums.TargetRule.NONE:
		return ""
	if preview.action.is_area():
		return "All" if preview.action.targets_enemies() else "Allies"
	var names := PackedStringArray()
	for uid in preview.target_uids:
		var unit := engine.get_unit(uid)
		if unit != null:
			names.append(unit.display_name)
	return ", ".join(names)


func _layout() -> void:
	if engine == null:
		return
	var party := engine.get_state().party(false)
	var enemies := engine.get_state().enemies(false)
	for index in party.size():
		_place(views.get(party[index].uid), PARTY_SLOTS[mini(index, PARTY_SLOTS.size() - 1)])
	var slots: Array = ENEMY_SLOTS.get(clampi(enemies.size(), 1, 4))
	for index in enemies.size():
		_place(views.get(enemies[index].uid), slots[mini(index, slots.size() - 1)])
	_layout_bubbles()


func _place(unit_view: UnitView, slot: Vector2) -> void:
	if unit_view == null:
		return
	var bottom_centre := Vector2(size.x * slot.x, size.y * slot.y)
	unit_view.position = bottom_centre - Vector2(unit_view.size.x * 0.5, unit_view.size.y)
	# Keep room for the intent bubble above tall enemies.
	unit_view.position.y = maxf(unit_view.position.y, IntentBubble.SIZE.y + 12.0)


## Bubbles sit above their enemy; overlapping bubbles are pushed upwards (left to right).
func _layout_bubbles() -> void:
	var placed: Array[Rect2] = []
	var order := bubbles.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return views[a].position.x < views[b].position.x)
	for uid: int in order:
		var bubble := bubbles[uid]
		var unit_view := views[uid]
		var at := unit_view.position + Vector2(unit_view.size.x * 0.5 - IntentBubble.SIZE.x * 0.5, -IntentBubble.SIZE.y - 10.0)
		at.x = clampf(at.x, 4.0, maxf(4.0, size.x - IntentBubble.SIZE.x - 4.0))
		var rect := Rect2(at, IntentBubble.SIZE)
		for other in placed:
			if rect.grow(2.0).intersects(other):
				rect.position.y = other.position.y - IntentBubble.SIZE.y - 12.0
		rect.position.y = maxf(rect.position.y, 2.0)
		bubble.position = rect.position
		if bubble.visible:
			placed.append(rect)


# --- Backdrop ------------------------------------------------------------------------------------

func _draw() -> void:
	var horizon := size.y * HORIZON
	_vertical_gradient(Rect2(0, 0, size.x, horizon), SKY_TOP, SKY_BOTTOM)
	_vertical_gradient(Rect2(0, horizon, size.x, size.y - horizon), GROUND_TOP, GROUND_BOTTOM)
	var rng := RandomNumberGenerator.new()
	rng.seed = _scenery_seed
	# A pale bell-moon behind the mist.
	var moon := Vector2(size.x * rng.randf_range(0.3, 0.7), horizon * 0.35)
	draw_circle(moon, 26.0, Color(0.85, 0.82, 0.7, 0.10))
	draw_circle(moon, 16.0, Color(0.9, 0.88, 0.78, 0.22))
	# Far treeline: dead trunks and reed spikes.
	var x := -10.0
	while x < size.x + 10.0:
		var height := rng.randf_range(18.0, 70.0)
		var width := rng.randf_range(3.0, 7.0)
		draw_rect(Rect2(x, horizon - height, width, height + 2.0), Color(0.07, 0.08, 0.1, 0.9))
		if rng.randf() < 0.35:
			var branch_y := horizon - height * rng.randf_range(0.5, 0.85)
			draw_line(Vector2(x + width * 0.5, branch_y), Vector2(x + width * 0.5 + rng.randf_range(-16, 16), branch_y - 12.0),
				Color(0.07, 0.08, 0.1, 0.9), 2.0)
		x += rng.randf_range(10.0, 34.0)
	draw_rect(Rect2(0, horizon - 6.0, size.x, 10.0), Color(0.55, 0.6, 0.6, 0.08))
	# Still pools and reed tufts on the ground.
	for i in 6:
		var pool := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(horizon + 20.0, size.y - 20.0))
		_ellipse(pool, Vector2(rng.randf_range(40.0, 110.0), rng.randf_range(6.0, 14.0)), Color(0.25, 0.32, 0.38, 0.22))
	for i in 26:
		var tuft := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(horizon + 8.0, size.y))
		for blade in 3:
			draw_line(tuft, tuft + Vector2(rng.randf_range(-6.0, 6.0), -rng.randf_range(8.0, 18.0)), Color(0.2, 0.27, 0.18, 0.8), 1.5)
	if engine != null:
		_draw_conditions(horizon)


## Each active condition washes the ground in its tint, adds drifting motes and a name plate.
func _draw_conditions(horizon: float) -> void:
	var plate_y := 8.0
	for active in engine.get_state().conditions:
		var definition := active.definition
		var tint := definition.tint
		draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color(tint, tint.a * 0.6))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(definition.id)
		for i in MOTES:
			var base := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(horizon * 0.6, size.y))
			var drift := Vector2(sin(_time * 0.4 + i) * 18.0, -fmod(_time * rng.randf_range(4.0, 12.0), 60.0))
			var alpha := 0.25 + 0.2 * sin(_time * 1.3 + i * 0.7)
			draw_circle(base + drift, rng.randf_range(1.5, 3.5), Color(tint.lightened(0.4), alpha))
		var label := definition.display_name.to_upper()
		var font_size := UITheme.font_size(0.72)
		var text_width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var plate := Rect2(8.0, plate_y, text_width + 18.0, font_size + 8.0)
		var ink := Color(tint.lightened(0.6), 1.0)
		draw_rect(plate, Color(0.03, 0.03, 0.05, 0.85))
		draw_rect(plate, ink, false, 1.0)
		draw_string(_font, plate.position + Vector2(9.0, font_size + 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		plate_y += plate.size.y + 4.0


func _vertical_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
