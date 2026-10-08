class_name Battlefield
extends Control
## The stage: the Briarfen backdrop (or the procedural fen when no art is set), tinted by the active
## battlefield conditions, and the unit views. Party stands on the left facing right, enemies on the
## right facing left, compact icon/number stats below. Intent strips reserve no actor space; only a
## genuinely short viewport can shrink sprites. Conditions are inspected through header icons.

signal unit_clicked(uid: int)
## uid of the unit under the pointer, or -1 when the pointer leaves it.
signal unit_hovered(uid: int)

const HORIZON := 0.38
const SKY_TOP := Color("141826")
const SKY_BOTTOM := Color("2b3140")
const GROUND_TOP := Color("1d241f")
const GROUND_BOTTOM := Color("121612")
## Vertical anchor of the backdrop crop (0 = top of the art, 1 = bottom).
const BACKDROP_FOCUS := 0.62
## Small clearance above a sprite; turn/target words are not drawn over actors.
const TAG_ROOM := 6.0

## Optional painted backdrop (M1.1 F5). Null = procedural fen.
@export var backdrop: Texture2D
var engine: BattleEngine
var ledger: PresentationLedger
var views: Dictionary[int, UnitView] = {}
var screen_shake := true
var reduce_motion := false
## Legacy compatibility field; the icon-first layout leaves it empty and does not reserve space.
var reserved_rect := Rect2()
## Real art on/off (tests compare results with art disabled).
var use_art := true

var _stage: Control
var _shake := 0.0
var _time := 0.0
var _scenery_seed := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	resized.connect(layout_units)


func setup(p_engine: BattleEngine, p_ledger: PresentationLedger, reduce_flashing: bool) -> void:
	engine = p_engine
	ledger = p_ledger
	_scenery_seed = hash(engine.ctx.setup.label) if not engine.ctx.setup.label.is_empty() else 7
	for child in _stage.get_children():
		child.queue_free()
	views.clear()
	var slot := 0
	for unit in engine.get_state().units:
		var view := UnitView.new()
		view.name = "Unit%d" % unit.uid
		view.reduce_flashing = reduce_flashing
		view.reduce_motion = reduce_motion
		view.use_sprites = use_art
		if unit.is_enemy():
			slot += 1
		_stage.add_child(view)
		view.setup(unit, ledger, slot if unit.is_enemy() else 0)
		view.clicked.connect(func(uid: int) -> void: unit_clicked.emit(uid))
		view.hovered.connect(func(uid: int) -> void: unit_hovered.emit(uid))
		view.mouse_exited.connect(func() -> void: unit_hovered.emit(-1))
		views[unit.uid] = view
	layout_units()


func view(uid: int) -> UnitView:
	return views.get(uid)


## 1-based rail slot of an enemy (stable for the whole battle), or 0.
func slot_of(uid: int) -> int:
	var unit_view := view(uid)
	return unit_view.slot if unit_view != null else 0


## Global position of a unit's body centre (reaction rings, projectiles).
func body_point(uid: int) -> Vector2:
	var unit_view := view(uid)
	return unit_view.body_rect().get_center() if unit_view != null else global_position + size * 0.5


## Global position just above a unit (floating text).
func top_point(uid: int) -> Vector2:
	var unit_view := view(uid)
	return unit_view.anchor_top() if unit_view != null else global_position + size * 0.5


## Direction the unit lunges when it acts.
func forward(uid: int) -> Vector2:
	var unit := engine.get_unit(uid) if engine != null else null
	return Vector2.LEFT if unit != null and unit.is_enemy() else Vector2.RIGHT


func set_active(uid: int, label: String = "") -> void:
	for key: int in views:
		views[key].active_label = label if key == uid else ""
		views[key].active = key == uid


## Highlights [param uid] with a bracket and [param label] ("TARGET"); -1 clears.
func set_highlight(uid: int, label: String = "TARGET") -> void:
	for key: int in views:
		views[key].highlight_label = label
		views[key].highlighted = key == uid


## Highlights several units at once (reaction targets).
func set_highlights(uids: Array[int], label: String) -> void:
	for key: int in views:
		views[key].highlight_label = label
		views[key].highlighted = uids.has(key)


## Shows or hides every nameplate (hidden at large text; the rail and party column carry the
## numbers and a slot badge identifies each unit).
func set_plates(visible_plates: bool) -> void:
	for key: int in views:
		views[key].show_plate = visible_plates
	layout_units()


func refresh_units() -> void:
	for key: int in views:
		views[key].queue_redraw()


func shake(strength: float) -> void:
	if screen_shake and not reduce_motion:
		_shake = maxf(_shake, strength)


## Places every unit: plates in a row along the bottom, sprites scaled to the room above them.
func layout_units() -> void:
	if engine == null or size.x <= 0.0:
		return
	var party := engine.get_state().party(false)
	var enemies := engine.get_state().enemies(false)
	var plate_h := 0.0
	for unit_view: UnitView in views.values():
		plate_h = maxf(plate_h, unit_view.plate_height())
	var baseline := size.y - plate_h - 6.0
	var half := size.x * 0.5
	var enemy_plate := clampf(half / maxf(1.0, enemies.size()) - 10.0, 120.0, 300.0)
	# Party members stand 40% of their area apart; plates never overlap.
	var party_area := size.x * 0.46
	var party_plate := clampf(party_area * 0.4 - 12.0, 120.0, 240.0) if party.size() > 1 else clampf(party_area * 0.5, 120.0, 240.0)
	_place_side(party, Rect2(0.0, 0.0, party_area, baseline), party_plate, true)
	_place_side(enemies, Rect2(half, 0.0, half, baseline), enemy_plate, false)


func _place_side(units: Array[BattleUnit], area: Rect2, plate_width: float, is_party: bool) -> void:
	if units.is_empty():
		return
	var top := 8.0 + TAG_ROOM
	var room := maxf(24.0, area.end.y - top)
	var tallest := 1.0
	for unit in units:
		tallest = maxf(tallest, views[unit.uid].natural_height())
	var shrink := minf(1.0, room / tallest)
	var count := units.size()
	for index in count:
		var unit_view: UnitView = views[units[index].uid]
		unit_view.fit(shrink, plate_width)
		var slot_center: float
		if is_party:
			# The protagonist stands forward; the companion behind and to the left, like the study.
			var fraction := 0.62 if count == 1 else 0.7 - 0.4 * float(index) / float(count - 1)
			slot_center = area.position.x + area.size.x * fraction
		else:
			slot_center = area.position.x + area.size.x * (float(index) + 0.5) / float(count)
		var sprite_height := unit_view.size.y - unit_view.plate_height()
		var at := Vector2(slot_center - unit_view.size.x * 0.5, area.end.y - sprite_height)
		at.x = clampf(at.x, 4.0, maxf(4.0, size.x - unit_view.size.x - 4.0))
		unit_view.position = at


func _process(delta: float) -> void:
	_time += delta
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		_stage.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.6)
	elif _stage.position != Vector2.ZERO:
		_stage.position = Vector2.ZERO
	if not reduce_motion:
		queue_redraw()


# --- Backdrop ------------------------------------------------------------------------------------

func _draw() -> void:
	var horizon := size.y * HORIZON
	if backdrop != null and use_art:
		_draw_backdrop()
	else:
		_draw_procedural(horizon)
	if engine != null:
		_draw_conditions(horizon)


## Fills the stage with the painted plate ("cover" fit), then dims it so plates and units read.
func _draw_backdrop() -> void:
	var source := Vector2(backdrop.get_width(), backdrop.get_height())
	var scale := maxf(size.x / source.x, size.y / source.y)
	var crop := size / scale
	var region := Rect2(Vector2((source.x - crop.x) * 0.5, (source.y - crop.y) * BACKDROP_FOCUS), crop)
	draw_texture_rect_region(backdrop, Rect2(Vector2.ZERO, size), region)
	draw_rect(Rect2(Vector2.ZERO, size), Color(UITheme.BG, 0.28))


func _draw_procedural(horizon: float) -> void:
	_vertical_gradient(Rect2(0, 0, size.x, horizon), SKY_TOP, SKY_BOTTOM)
	_vertical_gradient(Rect2(0, horizon, size.x, size.y - horizon), GROUND_TOP, GROUND_BOTTOM)
	var rng := RandomNumberGenerator.new()
	rng.seed = _scenery_seed
	var moon := Vector2(size.x * rng.randf_range(0.3, 0.7), horizon * 0.35)
	draw_circle(moon, 26.0, Color(0.85, 0.82, 0.7, 0.10))
	draw_circle(moon, 16.0, Color(0.9, 0.88, 0.78, 0.22))
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
	for i in 6:
		var pool := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(horizon + 20.0, size.y - 20.0))
		_ellipse(pool, Vector2(rng.randf_range(40.0, 110.0), rng.randf_range(6.0, 14.0)), Color(0.25, 0.32, 0.38, 0.22))
	for i in 26:
		var tuft := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(horizon + 8.0, size.y))
		for blade in 3:
			draw_line(tuft, tuft + Vector2(rng.randf_range(-6.0, 6.0), -rng.randf_range(8.0, 18.0)), Color(0.2, 0.27, 0.18, 0.8), 1.5)


## Shared pixel terrain art, driven only by announced condition state.
func _draw_conditions(_horizon: float) -> void:
	var shown: Array[BattlefieldConditionDefinition] = []
	if ledger != null:
		shown = ledger.conditions
	else:
		for active in engine.get_state().conditions:
			shown.append(active.definition)
	for definition in shown:
		ConditionArt.paint(self, size, definition, _time, reduce_motion)


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
