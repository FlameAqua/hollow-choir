class_name PartyCard
extends Control
## Bottom-left status card for one party member: HP, Focus, statuses, stance, cover, turn marker.

var unit: BattleUnit
var active: bool = false:
	set(value):
		active = value
		queue_redraw()
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	custom_minimum_size = Vector2(290, 96)
	mouse_filter = Control.MOUSE_FILTER_PASS


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UITheme.PANEL_LIGHT if active else UITheme.PANEL)
	draw_rect(rect, UITheme.ACCENT if active else UITheme.BORDER, false, 2.0 if active else 1.0)
	var font_size := UITheme.font_size(0.95)
	var small := UITheme.font_size(0.72)
	var name := unit.display_name + ("" if unit.is_alive() else "  (down)")
	draw_string(_font, Vector2(10, 6 + font_size), name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		UITheme.TEXT if unit.is_alive() else UITheme.TEXT_DIM)
	if active:
		draw_string(_font, Vector2(size.x - 80, 6 + font_size), "ACTING", HORIZONTAL_ALIGNMENT_RIGHT, 70, small, UITheme.ACCENT)
	var hp_rect := Rect2(10, 32, size.x - 20, 13)
	draw_rect(hp_rect, Color(0, 0, 0, 0.6))
	var ratio := clampf(float(unit.hp) / maxf(1.0, unit.max_hp), 0.0, 1.0)
	var hp_color := UITheme.BLOOM if ratio > 0.35 else UITheme.DANGER
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * ratio, hp_rect.size.y)), hp_color)
	draw_string(_font, hp_rect.position + Vector2(4, 11), "HP %d / %d" % [unit.hp, unit.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color.WHITE)
	var pip_width := (size.x - 20) / float(maxi(1, unit.max_focus))
	for i in unit.max_focus:
		var pip := Rect2(10 + i * pip_width, 50, pip_width - 3, 9)
		draw_rect(pip, UITheme.ACCENT if i < unit.focus else Color(0.22, 0.22, 0.28))
	draw_string(_font, Vector2(10, 76), "Focus %d/%d" % [unit.focus, unit.max_focus], HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.ACCENT)
	var x := 110.0
	for status in unit.statuses:
		IconPainter.draw_status(self, Rect2(x, 64, 16, 16), status.status)
		draw_string(_font, Vector2(x + 18, 77), "%s %d" % [status.definition.glyph, status.remaining],
			HORIZONTAL_ALIGNMENT_LEFT, -1, small, IconPainter.status_color(status.status))
		x += 62.0
	for buff in unit.buffs:
		draw_string(_font, Vector2(x, 77), buff.definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
		x += _font.get_string_size(buff.definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 10
	if unit.intercepted_by >= 0:
		draw_string(_font, Vector2(10, 92), "Covered by an ally", HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
	elif unit.intercepting_for >= 0:
		draw_string(_font, Vector2(10, 92), "Intercepting attacks", HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
