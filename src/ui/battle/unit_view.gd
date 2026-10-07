class_name UnitView
extends Control
## Battlefield view of one BattleUnit: placeholder pixel silhouette (until sprites exist), HP and
## Stagger bars, statuses, buffs, weak-point marker and Broken state. Read-only on the unit.

signal clicked(uid: int)
signal hovered(uid: int)

const PIXEL := 4.0
const BAR_WIDTH := 112.0
const FOOTER := 64.0

## Pixel-art silhouettes: [x, y, w, h, shade] in grid cells. shade: 0 base, 1 dark, 2 light, 3 accent.
const SHAPES := {
	Enums.VisualShape.HUMANOID: {"grid": Vector2(16, 24), "cells": [
		[5, 0, 6, 2, 1], [6, 1, 4, 4, 2], [5, 5, 6, 8, 0], [4, 6, 1, 9, 1], [11, 6, 1, 9, 1],
		[3, 6, 2, 6, 0], [11, 6, 2, 6, 0], [5, 13, 2, 7, 1], [9, 13, 2, 7, 1], [13, 3, 1, 13, 3]]},
	Enums.VisualShape.TALL: {"grid": Vector2(16, 28), "cells": [
		[6, 0, 4, 2, 3], [6, 2, 4, 4, 2], [5, 6, 6, 10, 0], [4, 7, 1, 10, 1], [11, 7, 1, 10, 1],
		[3, 7, 2, 7, 0], [11, 7, 2, 7, 0], [5, 16, 2, 9, 1], [9, 16, 2, 9, 1], [13, 0, 1, 27, 3], [12, 0, 3, 2, 2]]},
	Enums.VisualShape.BEAST: {"grid": Vector2(24, 16), "cells": [
		[1, 5, 5, 2, 1], [5, 6, 13, 6, 0], [17, 3, 6, 5, 0], [21, 5, 2, 2, 3], [6, 12, 2, 4, 1],
		[10, 12, 2, 4, 1], [14, 12, 2, 4, 1], [17, 12, 2, 4, 1], [7, 4, 1, 2, 2], [10, 3, 1, 3, 2],
		[13, 4, 1, 2, 2], [16, 2, 1, 2, 2]]},
	Enums.VisualShape.SHELL: {"grid": Vector2(24, 16), "cells": [
		[4, 4, 16, 8, 0], [6, 2, 12, 3, 2], [0, 8, 4, 3, 1], [20, 8, 4, 3, 1], [5, 12, 2, 3, 1],
		[9, 12, 2, 3, 1], [13, 12, 2, 3, 1], [17, 12, 2, 3, 1], [9, 0, 1, 2, 3], [14, 0, 1, 2, 3],
		[7, 6, 10, 1, 1]]},
	Enums.VisualShape.BLOB: {"grid": Vector2(22, 20), "cells": [
		[5, 10, 2, 9, 1], [15, 9, 3, 10, 1], [10, 5, 2, 14, 1], [2, 6, 8, 4, 0], [12, 4, 9, 5, 0],
		[7, 0, 8, 5, 2], [4, 7, 1, 1, 3], [15, 5, 1, 1, 3], [10, 1, 1, 1, 3], [18, 6, 1, 1, 3]]},
	Enums.VisualShape.COLOSSUS: {"grid": Vector2(24, 28), "cells": [
		[3, 2, 18, 7, 2], [6, 8, 12, 14, 0], [2, 10, 4, 10, 1], [18, 10, 4, 10, 1], [7, 22, 4, 6, 1],
		[13, 22, 4, 6, 1], [6, 4, 2, 2, 3], [15, 3, 2, 2, 3], [11, 5, 2, 1, 3]]},
	Enums.VisualShape.DUMMY: {"grid": Vector2(16, 24), "cells": [
		[7, 8, 2, 16, 1], [1, 9, 14, 2, 1], [5, 1, 6, 7, 2], [4, 10, 8, 6, 0], [6, 3, 1, 1, 1], [9, 3, 1, 1, 1]]},
}

var uid: int = -1
var unit: BattleUnit
var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()
var active: bool = false:
	set(value):
		active = value
		queue_redraw()
## 0..1 white flash after a hit (reduced-flashing uses a dark tint instead).
var flash: float = 0.0:
	set(value):
		flash = value
		queue_redraw()
var body_offset: Vector2 = Vector2.ZERO:
	set(value):
		body_offset = value
		queue_redraw()
var body_scale: float = 1.0:
	set(value):
		body_scale = value
		queue_redraw()
var displayed_hp: float = 0.0:
	set(value):
		displayed_hp = value
		queue_redraw()
var displayed_stagger: float = 0.0:
	set(value):
		displayed_stagger = value
		queue_redraw()
var reduce_flashing: bool = false
var faces_left: bool = false

var _font: Font
var _sprite_size: Vector2


func setup(battle_unit: BattleUnit) -> void:
	unit = battle_unit
	uid = battle_unit.uid
	faces_left = battle_unit.is_enemy()
	var shape: Dictionary = SHAPES.get(battle_unit.definition.shape, SHAPES[Enums.VisualShape.HUMANOID])
	var scale_factor := battle_unit.definition.visual_scale
	_sprite_size = shape.grid * PIXEL * scale_factor
	custom_minimum_size = Vector2(maxf(_sprite_size.x, BAR_WIDTH) + 16.0, _sprite_size.y + FOOTER)
	size = custom_minimum_size
	displayed_hp = battle_unit.hp
	displayed_stagger = battle_unit.stagger
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(uid))
	tooltip_text = ""


func _ready() -> void:
	_font = get_theme_default_font()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(uid)
		accept_event()


## Point where effects/floating text should appear (above the sprite).
func anchor_top() -> Vector2:
	return global_position + Vector2(size.x * 0.5, 0.0)


func anchor_center() -> Vector2:
	return global_position + Vector2(size.x * 0.5, _sprite_size.y * 0.55)


func _draw() -> void:
	if unit == null:
		return
	var alive := unit.is_alive() or displayed_hp > 0.5
	var sprite_origin := Vector2((size.x - _sprite_size.x) * 0.5, 0.0) + body_offset
	var center := sprite_origin + _sprite_size * 0.5
	# Shadow.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ellipse(Vector2(size.x * 0.5, _sprite_size.y - 2.0), Vector2(_sprite_size.x * 0.42, 6.0), Color(0, 0, 0, 0.35))
	# Selection / active markers.
	if highlighted:
		_draw_brackets(Rect2(sprite_origin - Vector2(6, 6), _sprite_size + Vector2(12, 12)), UITheme.FOCUS)
	elif active:
		_draw_brackets(Rect2(sprite_origin - Vector2(4, 4), _sprite_size + Vector2(8, 8)), UITheme.ACCENT.darkened(0.2))
	# Body (scaled around its feet, tilted when Broken, lying down when a party member falls).
	var tilt := 0.18 if unit.is_broken() else 0.0
	if not alive:
		tilt = -1.35
	var pivot := Vector2(center.x, sprite_origin.y + _sprite_size.y)
	draw_set_transform(pivot, tilt, Vector2(body_scale, body_scale))
	var local_origin := sprite_origin - pivot
	if alive or not unit.is_enemy():
		_draw_silhouette(local_origin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not alive:
		return
	if unit.is_weak_point_exposed():
		_draw_weak_point(center + Vector2(0, _sprite_size.y * 0.05))
	if unit.is_broken():
		_draw_cracks(center)
	_draw_footer(Vector2(0.0, _sprite_size.y + 4.0))


func _draw_silhouette(origin: Vector2) -> void:
	var base := unit.definition.color
	var flash_color := Color(0.15, 0.1, 0.1) if reduce_flashing else Color(1, 1, 1)
	var shades := [base, base.darkened(0.35), base.lightened(0.28), UITheme.ACCENT.lerp(base, 0.3)]
	var shape: Dictionary = SHAPES.get(unit.definition.shape, SHAPES[Enums.VisualShape.HUMANOID])
	var cell := PIXEL * unit.definition.visual_scale
	var grid_width: float = shape.grid.x
	if unit.definition.shape == Enums.VisualShape.FLYER:
		var c := origin + Vector2(8, 8) * cell
		draw_circle(c, 7.5 * cell, Color(base, 0.18))
		draw_circle(c, 5.0 * cell, Color(base, 0.45).lerp(flash_color, flash))
		draw_circle(c, 3.0 * cell, base.lightened(0.5).lerp(flash_color, flash))
		for i in 3:
			draw_line(c + Vector2(-3 + i * 3, 5) * cell, c + Vector2(-4 + i * 3, 9) * cell, Color(base, 0.5), cell * 0.8)
		return
	for spec: Array in shape.cells:
		var x: float = spec[0]
		if faces_left:
			x = grid_width - spec[0] - spec[2]
		var rect := Rect2(origin + Vector2(x, spec[1]) * cell, Vector2(spec[2], spec[3]) * cell)
		var color: Color = shades[spec[4]]
		draw_rect(rect, color.lerp(flash_color, flash))
	if unit.is_enemy() and unit.enemy_def().has_weak_point and unit.definition.shape == Enums.VisualShape.COLOSSUS:
		# The Cantor's bell, its weak point.
		var bell := Rect2(origin + Vector2(9, 12) * cell, Vector2(6, 6) * cell)
		draw_rect(bell, Color(0.75, 0.62, 0.3).lerp(flash_color, flash))
		draw_rect(Rect2(bell.position + Vector2(bell.size.x * 0.4, bell.size.y), Vector2(bell.size.x * 0.2, cell)), Color(0.5, 0.4, 0.2))


func _draw_weak_point(at: Vector2) -> void:
	var r := 9.0
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	draw_colored_polygon(diamond, Color(1.0, 0.85, 0.3, 0.5 + 0.4 * pulse))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color.WHITE, 1.5)
	queue_redraw()


func _draw_cracks(at: Vector2) -> void:
	var color := Color(0.95, 0.9, 1.0, 0.85)
	draw_polyline(PackedVector2Array([at + Vector2(-18, -20), at + Vector2(-6, -6), at + Vector2(-12, 6), at + Vector2(2, 18)]), color, 2.0)
	draw_polyline(PackedVector2Array([at + Vector2(14, -16), at + Vector2(4, -4), at + Vector2(16, 8)]), color, 2.0)


func _draw_footer(origin: Vector2) -> void:
	var x := (size.x - BAR_WIDTH) * 0.5
	var y := origin.y
	var font_size := UITheme.font_size(0.8)
	draw_string(_font, Vector2(0.0, y + font_size), unit.display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, UITheme.TEXT)
	y += font_size + 4.0
	# HP bar with numbers.
	var hp_rect := Rect2(x, y, BAR_WIDTH, 9.0)
	draw_rect(hp_rect, Color(0, 0, 0, 0.7))
	var hp_ratio := clampf(displayed_hp / float(maxi(1, unit.max_hp)), 0.0, 1.0)
	var hp_color := UITheme.BLOOM if unit.side == Enums.Side.PLAYER else Color(0.85, 0.32, 0.28)
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * hp_ratio, hp_rect.size.y)), hp_color)
	draw_rect(hp_rect, Color(0, 0, 0, 0.9), false, 1.0)
	var small := UITheme.font_size(0.66)
	draw_string(_font, Vector2(x + 2, y + 8), "%d/%d" % [roundi(displayed_hp), unit.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color.WHITE)
	y += 12.0
	if unit.is_enemy():
		var stagger_rect := Rect2(x, y, BAR_WIDTH, 6.0)
		draw_rect(stagger_rect, Color(0, 0, 0, 0.7))
		if unit.is_broken():
			draw_rect(stagger_rect, Color(1, 1, 1, 0.25))
			draw_string(_font, Vector2(x, y + 6), "BROKEN", HORIZONTAL_ALIGNMENT_CENTER, BAR_WIDTH, small, UITheme.STAGGER)
		else:
			var stagger_ratio := clampf(displayed_stagger / maxf(1.0, unit.max_stagger), 0.0, 1.0)
			draw_rect(Rect2(stagger_rect.position, Vector2(stagger_rect.size.x * stagger_ratio, stagger_rect.size.y)), UITheme.STAGGER)
		draw_rect(stagger_rect, Color(0, 0, 0, 0.9), false, 1.0)
		y += 9.0
	else:
		for i in unit.max_focus:
			var pip := Rect2(x + i * (BAR_WIDTH / unit.max_focus), y, BAR_WIDTH / unit.max_focus - 2.0, 5.0)
			draw_rect(pip, UITheme.ACCENT if i < unit.focus else Color(0.25, 0.25, 0.3))
		y += 8.0
	# Statuses then buff badges.
	var cursor := x
	for status in unit.statuses:
		IconPainter.draw_status(self, Rect2(cursor, y, 16, 16), status.status)
		draw_string(_font, Vector2(cursor + 10, y + 16), str(status.remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color.WHITE)
		cursor += 21.0
	for buff in unit.buffs:
		var glyph := buff.definition.glyph if not buff.definition.glyph.is_empty() else buff.definition.display_name.left(3).to_upper()
		var badge := Rect2(cursor, y + 1, 28, 14)
		draw_rect(badge, Color(0.6, 0.15, 0.15, 0.8) if buff.definition.is_debuff else Color(0.15, 0.3, 0.5, 0.85))
		draw_string(_font, Vector2(cursor + 2, y + 12), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color.WHITE)
		cursor += 31.0
	if unit.intercepted_by >= 0 or unit.intercepting_for >= 0:
		var label := "COVERED" if unit.intercepted_by >= 0 else "COVERING"
		draw_string(_font, Vector2(cursor + 2, y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)


func _draw_brackets(rect: Rect2, color: Color) -> void:
	var length := 10.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var horizontal := Vector2(length if corner.x == rect.position.x else -length, 0)
		var vertical := Vector2(0, length if corner.y == rect.position.y else -length)
		draw_line(corner, corner + horizontal, color, 2.0)
		draw_line(corner, corner + vertical, color, 2.0)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
