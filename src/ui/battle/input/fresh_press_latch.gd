class_name FreshPressLatch
extends RefCounted
## "A held button never counts as a new press" (M1.1 F2). An action latched here must be released
## before its next press is accepted. This consumes the press that opened a state: the Confirm that
## committed an action (which shares Space / Z / pad A with the command), a command still held when a
## reaction opens on the shared pad X, or a key still down after the window regains focus.
## Key repeat (echo) never counts either.

var _latched: Dictionary[StringName, bool] = {}


## Latches every action in [param actions] that is held right now.
func latch_held(actions: Array[StringName]) -> void:
	for action in actions:
		if Input.is_action_pressed(action):
			_latched[action] = true


func latch(action: StringName) -> void:
	_latched[action] = true


## Releases latches whose action is no longer held. Call every frame: the release event itself may
## have been consumed by another node (or by the window losing focus).
func poll() -> void:
	for action: StringName in _latched.keys():
		if not Input.is_action_pressed(action):
			_latched.erase(action)


## True when [param event] is a fresh, non-echo press of [param action]. Release events unlatch.
func is_fresh_press(event: InputEvent, action: StringName) -> bool:
	if event.is_action_released(action):
		_latched.erase(action)
		return false
	if not event.is_action_pressed(action, false):
		return false
	return not _latched.has(action)


func is_latched(action: StringName) -> bool:
	return _latched.has(action)


func any_latched() -> bool:
	return not _latched.is_empty()


func clear() -> void:
	_latched.clear()
