class_name ThreatCountdownView
extends Control
## Draws authoritative countdown facts only. It never ticks, launches, pauses or cancels a threat.
var _readout: EncounterCountdownReadout

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func present(readout: EncounterCountdownReadout) -> void:
	_readout = readout
	visible = readout.active
	queue_redraw()

func _draw() -> void:
	if _readout == null or not _readout.active: return
	var color := UITheme.TEXT_DIM if _readout.frozen else UITheme.ACCENT
	var center := Vector2(22, 22)
	draw_circle(center, 18, Color(UITheme.BG, .86))
	draw_arc(center, 16, -PI * .5, -PI * .5 + TAU * clampf(_readout.fraction(), 0, 1), 48, color, 2, true)
	var text := str(ceili(_readout.remaining))
	var font := UITheme.PIXEL_FONT
	draw_string(font, center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x * .5, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
	draw_string(font, Vector2(50, 30), "%s%s" % [_readout.threat_label, " · paused" if _readout.frozen else ""], HORIZONTAL_ALIGNMENT_LEFT, 250, 22, color)
