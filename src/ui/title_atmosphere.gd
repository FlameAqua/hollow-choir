class_name TitleAtmosphere
extends Control
## Six quiet, deterministic motes. Decorative motion never consumes gameplay RNG.
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if Settings.data.reduce_motion or Settings.data.reduce_flashing:
		if _time != 0:
			_time = 0
			queue_redraw()
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	if size.y <= 0: return
	for index in 6:
		var phase := float(index) * 1.73
		var point := Vector2((.50 + .085 * index) * size.x,
			fposmod((.19 + .137 * index) * size.y - _time * (2.0 + index * .3), size.y))
		point.x += sin(_time * .12 + phase) * 13
		draw_circle(point, 5, Color(.22, .42, .28, .035))
		draw_circle(point, 1.2, Color(.49, .73, .48, .28))
