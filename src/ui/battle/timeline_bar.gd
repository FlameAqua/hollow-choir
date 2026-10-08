class_name TimelineBar
extends Control
## Portrait order with a separate dimmed next-round forecast. Life, Broken and the forecast come from
## the PresentationLedger and channel markers from the rail's displayed intent, so nothing changes
## before the event that caused it has played (the engine is already at the end of the batch).
var engine: BattleEngine
## Displayed state (null = live engine state, e.g. a bare timeline in a tool).
var ledger: PresentationLedger
var rail: IntentRail
var use_art := true
var round_number := 0
var order: Array[int] = []
var acting_uid := -1
var acted: Dictionary[int, bool] = {}
var _chips: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func refresh() -> void:
	queue_redraw()

func describe() -> String:
	var parts := PackedStringArray()
	for uid in _upcoming():
		parts.append(("NOW " if uid == acting_uid else "") + engine.get_unit(uid).display_name)
	var forecast := PackedStringArray()
	for uid in _forecast():
		forecast.append(engine.get_unit(uid).display_name)
	if forecast.is_empty():
		return " › ".join(parts)
	return "%s | Next round · forecast: %s" % [" › ".join(parts), " → ".join(forecast)]

func _upcoming() -> Array[int]:
	var result: Array[int] = []
	if engine != null:
		for uid in order:
			var unit := engine.get_unit(uid)
			if unit != null and _alive(unit) and not acted.has(uid):
				result.append(uid)
	return result

func _forecast() -> Array[int]:
	return ledger.displayed_forecast() if ledger != null else engine.forecast_next_round()

func _alive(unit: BattleUnit) -> bool:
	var display := ledger.unit(unit.uid) if ledger != null else null
	return display.alive if display != null else unit.is_alive()

func _broken(unit: BattleUnit) -> bool:
	var display := ledger.unit(unit.uid) if ledger != null else null
	return display.broken if display != null else unit.is_broken()

## The hourglass mirrors the channel the rail currently shows for this enemy.
func _channel(unit: BattleUnit) -> bool:
	if rail == null:
		return unit.intent != null and unit.intent.is_channel()
	var slot := rail.slot(unit.uid)
	return slot != null and slot.readout != null and slot.readout.is_channel

func _draw() -> void:
	_chips.clear()
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.PANEL)
	if engine == null:
		return
	var side := size.y - 8
	var x := 8.0
	CombatIcons.paint(self, "turn_order", Rect2(x, 8, side - 8, side - 8))
	x += side + 12
	for uid in _upcoming():
		_chip(uid, Rect2(x, 4, side, side), false)
		x += side + 10
	var forecast := _forecast()
	var forecast_x := maxf(x + 32, size.x - (side + 6) * (forecast.size() + 1) - 10)
	if not forecast.is_empty() and forecast_x + (side + 6) * 2 <= size.x:
		draw_line(Vector2(forecast_x - 16, 8), Vector2(forecast_x - 16, size.y - 8), UITheme.BORDER)
		CombatIcons.paint(self, "channel", Rect2(forecast_x, 8, side - 8, side - 8), Color(1, 1, 1, 0.65))
		forecast_x += side + 6
		for index in forecast.size():
			var uid := forecast[index]
			if forecast_x + (side + 6) * 2 > size.x and index < forecast.size() - 1:
				var more := Rect2(forecast_x, 4, side, side)
				draw_string(get_theme_default_font(), more.position + Vector2(4, side * 0.65), "+%d" % (forecast.size() - index), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.secondary_size(), UITheme.TEXT_DIM)
				_chips.append({"rect": more, "uid": -1, "forecast": true})
				break
			_chip(uid, Rect2(forecast_x, 4, side, side), true)
			forecast_x += side + 6

func _chip(uid: int, rect: Rect2, forecast: bool) -> void:
	var unit := engine.get_unit(uid)
	if unit == null:
		return
	var current := uid == acting_uid and not forecast
	draw_rect(rect, UITheme.BG)
	draw_rect(rect, UITheme.ACCENT if current else UITheme.DANGER if unit.is_enemy() else UITheme.HEART, false, 2 if current else 1)
	CombatIcons.portrait(self, unit, rect.grow(-3), forecast, use_art)
	if current:
		draw_rect(Rect2(rect.position.x, rect.end.y - 3, rect.size.x, 3), UITheme.ACCENT)
	if _broken(unit):
		CombatIcons.paint(self, "state_broken", Rect2(rect.end - Vector2(18, 18), Vector2(18, 18)))
	elif unit.is_enemy() and _channel(unit):
		CombatIcons.paint(self, "channel", Rect2(rect.end - Vector2(16, 16), Vector2(16, 16)))
	if unit.is_enemy():
		var number := engine.get_state().enemies(false).find(unit) + 1
		var small := UITheme.secondary_size()
		draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(small * 0.7 + 4, small + 3)), Color(UITheme.BG, 0.9))
		draw_string(get_theme_default_font(), rect.position + Vector2(2, small + 1), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.TEXT)
	_chips.append({"rect": rect, "uid": uid, "forecast": forecast})

func _get_tooltip(point: Vector2) -> String:
	for chip in _chips:
		if (chip.rect as Rect2).has_point(point):
			if chip.uid < 0:
				return describe().get_slice(" | ", 1)
			var unit := engine.get_unit(chip.uid)
			return "%s%s\nTempo %d%s" % ["Next round · forecast\n" if chip.forecast else "Acting now\n" if chip.uid == acting_uid else "", unit.display_name, roundi(Stats.tempo(engine.ctx, unit)), "\nBroken: skips its next activation." if _broken(unit) else ""]
	return "Turn order\nGold underline: acting now. Red frame: enemy. Dim portraits: next-round forecast."
