class_name InputBindings
extends RefCounted
## Game input actions and default bindings, registered at runtime (DECISION_LOG D-010).
## Bindings are strings so settings files stay readable: "key:Space" (physical key, so reaction
## keys keep their position on any keyboard layout), "joy:9" (joypad button), "mouse:1",
## "axis:0:-1" (joypad axis and direction, used by the world movement defaults).

const CONFIRM := &"hc_confirm"
const CANCEL := &"hc_cancel"
const COMMAND := &"hc_command"
const BRACE := &"hc_brace"
const EVADE := &"hc_evade"
const PARRY := &"hc_parry"
const INFO := &"hc_info"
const UP := &"hc_up"
const DOWN := &"hc_down"
const LEFT := &"hc_left"
const RIGHT := &"hc_right"
const LOG := &"hc_log"
const MENU := &"hc_menu"
## World context (V0.4). Read only by the exploration host, so sharing physical keys with combat
## actions (WASD vs the A/S/D reactions) never makes one context act on the other's input.
const WORLD_UP := &"hc_world_up"
const WORLD_DOWN := &"hc_world_down"
const WORLD_LEFT := &"hc_world_left"
const WORLD_RIGHT := &"hc_world_right"
const WORLD_INTERACT := &"hc_world_interact"
const WORLD_MAP := &"hc_world_map"
const WORLD_MENU := &"hc_world_menu"
const WORLD_MOVES: Array[StringName] = [WORLD_UP, WORLD_DOWN, WORLD_LEFT, WORLD_RIGHT]
const WORLD_ACTIONS: Array[StringName] = [WORLD_UP, WORLD_DOWN, WORLD_LEFT, WORLD_RIGHT, WORLD_INTERACT, WORLD_MAP,
	WORLD_MENU]

## Menus use arrows + Enter/X so A/S/D are free for the three reactions,
## ordered left to right from safe to risky.
const DEFAULTS := {
	CONFIRM: ["key:Enter", "joy:0"],
	CANCEL: ["key:Escape", "key:X", "key:Backspace", "joy:1"],
	COMMAND: ["key:Space", "key:Z", "joy:0", "joy:2"],
	BRACE: ["key:A", "joy:9"],
	EVADE: ["key:S", "joy:2"],
	PARRY: ["key:D", "joy:10"],
	INFO: ["key:Alt", "joy:3"],
	UP: ["key:Up", "joy:11"],
	DOWN: ["key:Down", "joy:12"],
	LEFT: ["key:Left", "joy:13"],
	RIGHT: ["key:Right", "joy:14"],
	LOG: ["key:Tab", "joy:4"],
	MENU: ["key:Escape", "joy:6"],
	WORLD_UP: ["key:W", "key:Up", "joy:11", "axis:1:-1"],
	WORLD_DOWN: ["key:S", "key:Down", "joy:12", "axis:1:1"],
	WORLD_LEFT: ["key:A", "key:Left", "joy:13", "axis:0:-1"],
	WORLD_RIGHT: ["key:D", "key:Right", "joy:14", "axis:0:1"],
	WORLD_INTERACT: ["key:E", "key:Enter", "key:Space", "joy:0"],
	WORLD_MAP: ["key:M", "joy:4"],
	WORLD_MENU: ["key:Escape", "joy:6"],
}

## Analog world movement reads small stick deflections; every other action keeps the 0.5 default.
const DEADZONES := {WORLD_UP: 0.25, WORLD_DOWN: 0.25, WORLD_LEFT: 0.25, WORLD_RIGHT: 0.25}

const DISPLAY_NAMES := {
	CONFIRM: "Confirm", CANCEL: "Back", COMMAND: "Action command", BRACE: "Brace", EVADE: "Evade",
	PARRY: "Parry", INFO: "Details", UP: "Up", DOWN: "Down", LEFT: "Left", RIGHT: "Right",
	LOG: "Battle log", MENU: "Pause",
	WORLD_UP: "World: move up", WORLD_DOWN: "World: move down", WORLD_LEFT: "World: move left",
	WORLD_RIGHT: "World: move right", WORLD_INTERACT: "World: interact", WORLD_MAP: "World: map",
	WORLD_MENU: "World: menu",
}

## The device whose bindings prompts should show (M1.1: "current device bindings").
enum Device { KEYBOARD = 0, GAMEPAD = 1 }

## Last device the player used. Updated from every window input event (Settings autoload).
static var active_device: Device = Device.KEYBOARD


## Godot's built-in UI actions (focus navigation, pressing buttons) also follow these bindings, so
## menus obey rebinding and explicit confirmation works everywhere.
const UI_MIRRORS := {
	CONFIRM: &"ui_accept", CANCEL: &"ui_cancel", UP: &"ui_up", DOWN: &"ui_down", LEFT: &"ui_left",
	RIGHT: &"ui_right",
}


## Registers every action with its defaults, then applies [param overrides] (action -> codes).
## Starts from the project's input map, so re-installing after a rebind leaves no stale mirrors.
static func install(overrides: Dictionary = {}) -> void:
	InputMap.load_from_project_settings()
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONES.get(action, 0.5))
		var codes: Array = overrides.get(action, DEFAULTS[action])
		for code in codes:
			var event := event_from_code(String(code))
			if event != null:
				InputMap.action_add_event(action, event)
	for action: StringName in UI_MIRRORS:
		var ui_action: StringName = UI_MIRRORS[action]
		if InputMap.has_action(ui_action):
			InputMap.action_erase_events(ui_action)
			for event in InputMap.action_get_events(action):
				InputMap.action_add_event(ui_action, event)


static func codes_for(action: StringName) -> PackedStringArray:
	var codes := PackedStringArray()
	if not InputMap.has_action(action):
		return codes
	for event in InputMap.action_get_events(action):
		var code := code_from_event(event)
		if not code.is_empty():
			codes.append(code)
	return codes


static func event_from_code(code: String) -> InputEvent:
	var parts := code.split(":", true, 1)
	if parts.size() != 2:
		return null
	match parts[0]:
		"key":
			var keycode := OS.find_keycode_from_string(parts[1])
			if keycode == KEY_NONE:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			return key
		"joy":
			var button := InputEventJoypadButton.new()
			button.button_index = int(parts[1]) as JoyButton
			return button
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(parts[1]) as MouseButton
			return mouse
		"axis":
			var axis_parts := parts[1].split(":")
			if axis_parts.size() != 2:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(axis_parts[0]) as JoyAxis
			motion.axis_value = 1.0 if int(axis_parts[1]) > 0 else -1.0
			return motion
	return null


static func code_from_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var keycode := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%s" % OS.get_keycode_string(keycode)
	if event is InputEventJoypadButton:
		return "joy:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "axis:%d:%d" % [motion.axis, 1 if motion.axis_value > 0.0 else -1]
	return ""


## Gamepad button names (SDL / Xbox layout) for JoyButton indices 0..14.
const PAD_NAMES := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L-Stick", "R-Stick", "LB", "RB",
	"D-Up", "D-Down", "D-Left", "D-Right"]


const AXIS_NAMES := {"0:-1": "L-Stick Left", "0:1": "L-Stick Right", "1:-1": "L-Stick Up", "1:1": "L-Stick Down"}


## Readable name for one binding code ("key:Space" -> "Space", "joy:9" -> "Pad LB").
static func code_label(code: String) -> String:
	var parts := code.split(":", true, 1)
	if parts.size() != 2:
		return code
	match parts[0]:
		"joy":
			var index := int(parts[1])
			return "Pad %s" % (PAD_NAMES[index] if index >= 0 and index < PAD_NAMES.size() else parts[1])
		"mouse":
			return "Mouse %s" % parts[1]
		"axis":
			return "Pad %s" % AXIS_NAMES.get(parts[1], "Axis " + parts[1])
	return parts[1]


## Records which device produced [param event]. Returns true when the active device changed, so
## prompts can redraw (mouse movement and weak stick noise never switch devices).
static func note_event(event: InputEvent) -> bool:
	var device := active_device
	if event is InputEventJoypadButton:
		device = Device.GAMEPAD
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		device = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton:
		device = Device.KEYBOARD
	if device == active_device:
		return false
	active_device = device
	return true


## Label for [param action] on the active device: "Space", "A" on a keyboard; "A", "LB" on a pad.
## Falls back to the other device when the action has no binding on the active one.
static func label(action: StringName) -> String:
	if active_device == Device.GAMEPAD:
		var pad := pad_label(action)
		if not pad.is_empty():
			return pad
	var key := key_label(action)
	if key == "?":
		var fallback := pad_label(action)
		return fallback if not fallback.is_empty() else key
	return key


## The key in brackets for prompts: "[Space] Use", "[LB] Brace".
static func prompt(action: StringName) -> String:
	return "[%s]" % label(action)


## Every label of [param action] on the active device, joined ("Space / Z").
static func labels(action: StringName, separator: String = " / ") -> String:
	var names := PackedStringArray()
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var is_pad := event is InputEventJoypadButton
		if is_pad != (active_device == Device.GAMEPAD):
			continue
		var name := _pad_name((event as InputEventJoypadButton).button_index) if is_pad else _key_name(event as InputEventKey)
		if not name.is_empty() and not names.has(name):
			names.append(name)
	return separator.join(names) if not names.is_empty() else label(action)


## First gamepad binding of [param action] ("A", "LB"), or "".
static func pad_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return _pad_name((event as InputEventJoypadButton).button_index)
	return ""


static func _pad_name(index: int) -> String:
	return PAD_NAMES[index] if index >= 0 and index < PAD_NAMES.size() else "Pad %d" % index


static func _key_name(key: InputEventKey) -> String:
	if key == null:
		return ""
	if key.physical_keycode != KEY_NONE:
		if DisplayServer.get_name() != "headless":
			var layout_label := DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
			if layout_label != KEY_NONE:
				return OS.get_keycode_string(layout_label)
		return OS.get_keycode_string(key.physical_keycode)
	return OS.get_keycode_string(key.keycode)


## Human label for the first keyboard binding of [param action] on the player's own layout.
static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			# Layout-aware label where the display server knows the layout (not headless).
			return _key_name(event as InputEventKey)
	return "?"
