class_name StaminaMeter
extends Node2D
## V0.5: the sprint meter just under Hollow's feet. It shows while stamina is below full (sprinting
## or refilling) and fades away once full; exhausted, the fill dims until the sprint input is let go.
## Drawn above the world's depth layers so a fence or reed in front never hides it. Reads only.

const SIZE := Vector2(22, 3)
## Seconds to fade in or out (instant under Reduce Motion).
const FADE := 0.25

var stamina: Stamina
var _alpha := 0.0
var _drawn := Vector3(-1.0, -1.0, -1.0)


func _init() -> void:
	name = "StaminaMeter"
	position = Vector2(0, 4)
	z_as_relative = false
	z_index = 30


func _process(delta: float) -> void:
	var target := 0.0 if stamina == null or (stamina.is_full() and not stamina.sprinting) else 1.0
	_alpha = target if Settings.data.reduce_motion else move_toward(_alpha, target, delta / FADE)
	var state := Vector3(_alpha, stamina.value if stamina != null else 1.0, 1.0 if stamina != null and stamina.exhausted else 0.0)
	if state != _drawn:
		_drawn = state
		queue_redraw()


## Fully visible (true) or hidden (false) at once, e.g. when Hollow is placed somewhere new.
func snap(shown: bool) -> void:
	_alpha = 1.0 if shown else 0.0
	_drawn = Vector3(-1.0, -1.0, -1.0)
	queue_redraw()


func visible_amount() -> float:
	return _alpha


func _draw() -> void:
	if stamina == null or _alpha <= 0.0:
		return
	var bar := Rect2(Vector2(-SIZE.x * 0.5, 0), SIZE)
	draw_rect(bar.grow(1), Color(UITheme.BG, 0.85 * _alpha))
	var fill := Rect2(bar.position, Vector2(roundf(SIZE.x * stamina.value), SIZE.y))
	if fill.size.x > 0:
		var color := UITheme.TEXT_FAINT if stamina.exhausted else UITheme.BLOOM
		draw_rect(fill, Color(color, _alpha))
