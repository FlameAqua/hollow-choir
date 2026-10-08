class_name FloatingText
extends Label
## A short-lived label that rises and fades (damage numbers, "PERFECT!", "BREAK!").

static func spawn(parent: Node, at: Vector2, text: String, color: Color, size_multiplier: float = 1.0,
		duration: float = 0.9, render_scale: float = 1.0, bounds: Rect2 = Rect2()) -> FloatingText:
	var label := FloatingText.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", UITheme.font_size(size_multiplier))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	parent.add_child(label)
	label.reset_size()
	label.scale = Vector2.ONE * render_scale
	var drawn := label.size * render_scale
	label.position = at - Vector2(drawn.x * 0.5, drawn.y)
	if bounds.has_area():
		label.position.x = clampf(label.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - drawn.x))
		label.position.y = clampf(label.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - drawn.y))
	var end_y := maxf(bounds.position.y, label.position.y - 38) if bounds.has_area() else label.position.y - 38
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", end_y, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.55)
	tween.chain().tween_callback(label.queue_free)
	return label
