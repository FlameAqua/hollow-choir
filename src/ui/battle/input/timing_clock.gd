class_name TimingClock
extends RefCounted
## Elapsed time of one timed input (M1.1 F2). Wall-clock based, so Combat Speed and
## Engine.time_scale never touch a window (D-014), but it can freeze: while the window has no focus
## the clock stands still, and it resumes from the same instant. Nothing ever resets or rewinds it,
## so focus loss is never a free retry.

var _origin_us: int = 0
var _frozen: bool = false
var _frozen_us: int = 0


func start() -> void:
	_origin_us = Time.get_ticks_usec()
	_frozen = false
	_frozen_us = 0


func elapsed_ms() -> float:
	return (_frozen_us if _frozen else Time.get_ticks_usec() - _origin_us) / 1000.0


func freeze() -> void:
	if not _frozen:
		_frozen_us = Time.get_ticks_usec() - _origin_us
		_frozen = true


func resume() -> void:
	if _frozen:
		_origin_us = Time.get_ticks_usec() - _frozen_us
		_frozen = false


func is_frozen() -> bool:
	return _frozen


## Tests: pretend [param ms] more milliseconds have already passed.
func advance(ms: float) -> void:
	var delta := int(ms * 1000.0)
	if _frozen:
		_frozen_us += delta
	else:
		_origin_us -= delta


## Tests: jump to exactly [param ms] elapsed.
func set_elapsed(ms: float) -> void:
	if _frozen:
		_frozen_us = int(ms * 1000.0)
	else:
		_origin_us = Time.get_ticks_usec() - int(ms * 1000.0)
