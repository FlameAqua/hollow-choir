class_name WorldMapView
extends Control
## Local chart from the filtered readout. Numbered markers correspond to adjacent names, so
## crowded junctions never produce overlapping labels. Unknown space stays blank. No travel.

var readout: WorldMapReadout
var selected: int = -1


func show_readout(p_readout: WorldMapReadout) -> void:
	readout = p_readout
	queue_redraw()


func select(index: int) -> void:
	selected = index
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(UICraft.texture("map"), Rect2(Vector2.ZERO, size), false)
	if readout == null or readout.area_size.x <= 0.0 or readout.area_size.y <= 0.0:
		return
	var scale := minf((size.x - 64.0) / readout.area_size.x, (size.y - 64.0) / readout.area_size.y)
	var offset := ((size - readout.area_size * scale) * 0.5).round()
	for line in readout.links:
		if line.size() < 2:
			continue
		var points := PackedVector2Array()
		for point in line:
			points.append((offset + point * scale).round())
		draw_polyline(points, UITheme.BORDER.darkened(0.3), 8.0)
		draw_polyline(points, UITheme.TEXT_DIM, 3.0)
	var font := get_theme_default_font()
	var badges: Array[Rect2] = []
	for index in readout.landmarks.size():
		var landmark: Dictionary = readout.landmarks[index]
		var at := (offset + (landmark.position as Vector2) * scale).round()
		var colour := UITheme.ACCENT if index == selected else UITheme.TEXT_DIM
		var badge := Rect2(at + Vector2(10, -18), Vector2(32, 36))
		for previous in badges:
			if badge.grow(4).intersects(previous):
				badge.position.y = previous.end.y + 8
		badge.position = badge.position.clamp(Vector2(8, 8), size - badge.size - Vector2(8, 8))
		badges.append(badge)
		draw_line(at, badge.get_center(), colour.darkened(0.3), 1.0)
		draw_circle(at, 5.0, colour)
		UICraft.draw(self, "selected" if index == selected else "number", badge)
		draw_string(font, badge.position + Vector2(0, 26), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER,
			badge.size.x, UITheme.body_size(), colour)
	var player := (offset + readout.player_position * scale).round()
	draw_texture_rect(UICraft.texture("hollow_head"), Rect2(player - Vector2(18, 20), Vector2(36, 36)), false)
