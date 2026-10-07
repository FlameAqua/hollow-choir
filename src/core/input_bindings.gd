class_name InputBindings
extends RefCounted
## Game input actions and default bindings, registered at runtime (DECISION_LOG D-010).
## Bindings are strings so settings files stay readable: "key:Space" (physical key, so reaction
## keys keep their position on any keyboard layout), "joy:9" (joypad button), "mouse:1".

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

## Menus use arrows + Z/X (JRPG convention) so A/S/D are free for the three reactions,
## ordered left to right from safe to risky.
const DEFAULTS := {
	CONFIRM: ["key:Enter", "key:Z", "key:Space", "joy:0"],
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
}

const DISPLAY_NAMES := {
	CONFIRM: "Confirm", CANCEL: "Back", COMMAND: "Action command", BRACE: "Brace", EVADE: "Evade",
	PARRY: "Parry", INFO: "Details (hold)", UP: "Up", DOWN: "Down", LEFT: "Left", RIGHT: "Right",
	LOG: "Battle log", MENU: "Menu",
}


## Godot's built-in UI actions (focus navigation, pressing buttons) also follow these bindings, so
## menus obey rebinding and the JRPG keys (Z confirm, X back) work everywhere.
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
			InputMap.add_action(action, 0.5)
		var codes: Array = overrides.get(action, DEFAULTS[action])
		for code in codes:
			var event := event_from_code(String(code))
			if event != null:
				InputMap.action_add_event(action, event)
	for action: StringName in UI_MIRRORS:
		var ui_action: StringName = UI_MIRRORS[action]
		if InputMap.has_action(ui_action):
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
	return ""


## Gamepad button names (SDL / Xbox layout) for JoyButton indices 0..14.
const PAD_NAMES := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L-Stick", "R-Stick", "LB", "RB",
	"D-Up", "D-Down", "D-Left", "D-Right"]


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
	return parts[1]


## Human label for the first keyboard binding of [param action] on the player's own layout.
static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.physical_keycode != KEY_NONE:
				# Layout-aware label where the display server knows the layout (not headless).
				if DisplayServer.get_name() != "headless":
					var label := DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
					if label != KEY_NONE:
						return OS.get_keycode_string(label)
				return OS.get_keycode_string(key.physical_keycode)
			return OS.get_keycode_string(key.keycode)
	return "?"
