extends TestCase
## Playtest revision, extra mouse buttons end to end (core policy): middle, X1 and X2 can be
## captured, labelled, saved, reloaded and used as actions; the click that opens a capture, releases
## and the wheel never rebind; Cancel, the replace-first-of-kind rule, defaults and the fresh-press
## behaviour of actions are unchanged; a mouse-bound menu action reaches the focused control once.


func after_each() -> void:
	InputBindings.install(Settings.data.bindings)
	InputBindings.active_device = InputBindings.Device.KEYBOARD


static func _mouse(button: int, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.pressed = pressed
	return event


static func _key(keycode: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


func test_only_fresh_presses_of_supported_inputs_are_captured() -> void:
	assert_eq(InputBindings.CAPTURE_MOUSE_BUTTONS, [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2] as Array[int])
	assert_eq([InputBindings.capture_code(_mouse(MOUSE_BUTTON_MIDDLE)), InputBindings.capture_code(_mouse(MOUSE_BUTTON_XBUTTON1)),
		InputBindings.capture_code(_mouse(MOUSE_BUTTON_XBUTTON2))], ["mouse:3", "mouse:8", "mouse:9"])
	# The click that opened the capture (and its release), right click and the wheel never rebind.
	for button: int in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		assert_eq(InputBindings.capture_code(_mouse(button)), "", "button %d" % button)
		assert_eq(InputBindings.capture_code(_mouse(button, false)), "")
	for button: int in InputBindings.CAPTURE_MOUSE_BUTTONS:
		assert_eq(InputBindings.capture_code(_mouse(button, false)), "", "a release is never captured")
	assert_eq(InputBindings.capture_code(InputEventMouseMotion.new()), "")
	# Keys and joypad buttons as before: a fresh press only.
	assert_eq(InputBindings.capture_code(_key(KEY_K)), "key:K")
	assert_eq(InputBindings.capture_code(_key(KEY_K, true, true)), "", "a held key's echo")
	assert_eq(InputBindings.capture_code(_key(KEY_K, false)), "", "a key release")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	assert_eq(InputBindings.capture_code(pad), "joy:2")
	pad.pressed = false
	assert_eq(InputBindings.capture_code(pad), "")
	assert_eq(InputBindings.capture_code(InputEventJoypadMotion.new()), "", "sticks are not captured here")
	# Escape cancels the capture; nothing else does.
	assert_true(InputBindings.is_capture_cancel(_key(KEY_ESCAPE)))
	assert_false(InputBindings.is_capture_cancel(_key(KEY_ESCAPE, false)))
	assert_false(InputBindings.is_capture_cancel(_key(KEY_ESCAPE, true, true)))
	assert_false(InputBindings.is_capture_cancel(_key(KEY_K)))
	assert_false(InputBindings.is_capture_cancel(_mouse(MOUSE_BUTTON_XBUTTON1)))


func test_a_capture_replaces_the_first_binding_of_its_kind_and_keeps_the_rest() -> void:
	var codes := PackedStringArray(["key:Space", "key:Z", "joy:0", "joy:2"])
	assert_eq(InputBindings.rebound(codes, "key:K"), PackedStringArray(["key:K", "key:Z", "joy:0", "joy:2"]))
	assert_eq(InputBindings.rebound(codes, "joy:5"), PackedStringArray(["key:Space", "key:Z", "joy:5", "joy:2"]))
	# The first mouse binding is added in front; a second capture replaces it; the keys stay.
	var with_mouse := InputBindings.rebound(codes, "mouse:8")
	assert_eq(with_mouse, PackedStringArray(["mouse:8", "key:Space", "key:Z", "joy:0", "joy:2"]))
	assert_eq(InputBindings.rebound(with_mouse, "mouse:3"), PackedStringArray(["mouse:3", "key:Space", "key:Z", "joy:0", "joy:2"]))
	assert_eq(InputBindings.rebound(with_mouse, "mouse:8"), with_mouse, "capturing the same input changes nothing")
	assert_eq(InputBindings.rebound(codes, ""), codes, "a cancelled capture changes nothing")
	assert_eq(codes, PackedStringArray(["key:Space", "key:Z", "joy:0", "joy:2"]), "the input list is never edited in place")
	assert_eq([InputBindings.kind_of("mouse:8"), InputBindings.kind_of("key:Space"), InputBindings.kind_of("axis:0:-1"),
		InputBindings.kind_of("nonsense")], ["mouse", "key", "axis", ""])


func test_mouse_buttons_are_labelled_saved_and_reloaded() -> void:
	assert_eq([InputBindings.code_label("mouse:3"), InputBindings.code_label("mouse:8"), InputBindings.code_label("mouse:9"),
		InputBindings.code_label("mouse:1"), InputBindings.code_label("mouse:2"), InputBindings.code_label("mouse:4"),
		InputBindings.code_label("mouse:15")],
		["Middle Mouse", "Mouse X1", "Mouse X2", "Left Mouse", "Right Mouse", "Wheel Up", "Mouse 15"])
	assert_eq([InputBindings.code_label("key:Space"), InputBindings.code_label("joy:9")], ["Space", "Pad LB"], "other labels unchanged")
	# Codes round-trip through events.
	for code in ["mouse:3", "mouse:8", "mouse:9"]:
		assert_eq(InputBindings.code_from_event(InputBindings.event_from_code(code)), code)
	# Saved with the other bindings and read back unchanged.
	var settings := GameSettings.new()
	settings.bindings[InputBindings.PARRY] = PackedStringArray(["mouse:9", "key:D", "joy:10"])
	settings.bindings[InputBindings.WORLD_INTERACT] = PackedStringArray(["mouse:3"])
	var config := ConfigFile.new()
	settings.write_to(config)
	var restored := GameSettings.new()
	restored.read_from(config)
	assert_eq(restored.bindings[InputBindings.PARRY], PackedStringArray(["mouse:9", "key:D", "joy:10"]))
	assert_eq(restored.bindings[InputBindings.WORLD_INTERACT], PackedStringArray(["mouse:3"]))
	# Installed: the reloaded bindings are the action's events, and the defaults of every other
	# action are exactly what they were.
	InputBindings.install(restored.bindings)
	assert_eq(InputBindings.codes_for(InputBindings.PARRY), PackedStringArray(["mouse:9", "key:D", "joy:10"]))
	assert_eq(InputBindings.codes_for(InputBindings.WORLD_INTERACT), PackedStringArray(["mouse:3"]))
	for action: StringName in InputBindings.DEFAULTS:
		if action not in [InputBindings.PARRY, InputBindings.WORLD_INTERACT]:
			assert_eq(InputBindings.codes_for(action), PackedStringArray(InputBindings.DEFAULTS[action]), "%s keeps its defaults" % action)
	InputBindings.install()
	assert_eq(InputBindings.codes_for(InputBindings.PARRY), PackedStringArray(["key:D", "joy:10"]), "Reset restores the defaults")


func test_a_bound_mouse_button_really_triggers_its_action() -> void:
	InputBindings.install({InputBindings.BRACE: PackedStringArray(["mouse:8", "key:A", "joy:9"]),
		InputBindings.WORLD_INTERACT: PackedStringArray(["mouse:3", "key:E"])})
	var press := _mouse(MOUSE_BUTTON_XBUTTON1)
	assert_true(press.is_action_pressed(InputBindings.BRACE, false), "X1 is a fresh Brace press")
	assert_false(press.is_action_pressed(InputBindings.EVADE, false))
	assert_false(_mouse(MOUSE_BUTTON_XBUTTON1, false).is_action_pressed(InputBindings.BRACE, false), "its release is not a press")
	assert_true(_mouse(MOUSE_BUTTON_XBUTTON1, false).is_action_released(InputBindings.BRACE))
	assert_true(_mouse(MOUSE_BUTTON_MIDDLE).is_action_pressed(InputBindings.WORLD_INTERACT, false))
	assert_false(_mouse(MOUSE_BUTTON_LEFT).is_action_pressed(InputBindings.BRACE, false), "left click stays a click")
	assert_true(_key(KEY_A).is_action_pressed(InputBindings.BRACE, false), "the key beside it still works")
	# The Input singleton sees the same state (the world host reads movement and holds this way).
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	assert_true(Input.is_action_pressed(InputBindings.BRACE))
	Input.parse_input_event(_mouse(MOUSE_BUTTON_XBUTTON1, false))
	Input.flush_buffered_events()
	assert_false(Input.is_action_pressed(InputBindings.BRACE))


func test_prompts_prefer_the_key_and_fall_back_to_the_mouse_button() -> void:
	InputBindings.active_device = InputBindings.Device.KEYBOARD
	InputBindings.install({InputBindings.BRACE: PackedStringArray(["mouse:8", "key:A", "joy:9"]),
		InputBindings.EVADE: PackedStringArray(["mouse:9", "joy:2"]), InputBindings.PARRY: PackedStringArray(["mouse:3"])})
	assert_eq(InputBindings.label(InputBindings.BRACE), "A", "a key is the primary prompt even when a mouse button was bound first")
	assert_eq(InputBindings.labels(InputBindings.BRACE), "A / Mouse X1", "keys first, then mouse buttons")
	assert_eq(InputBindings.label(InputBindings.EVADE), "Mouse X2", "no key: the mouse button is the truthful prompt")
	assert_eq(InputBindings.prompt(InputBindings.PARRY), "[Middle Mouse]")
	assert_eq(InputBindings.key_label(InputBindings.PARRY), "Middle Mouse")
	# On a gamepad the pad binding is shown; an action without one falls back as before.
	InputBindings.active_device = InputBindings.Device.GAMEPAD
	assert_eq(InputBindings.label(InputBindings.BRACE), "LB")
	assert_eq(InputBindings.label(InputBindings.PARRY), "Middle Mouse")
	# A mouse button counts as keyboard-and-mouse input for the active device.
	assert_true(InputBindings.note_event(_mouse(MOUSE_BUTTON_XBUTTON1)))
	assert_eq(InputBindings.active_device, InputBindings.Device.KEYBOARD)
	# Conflicts are reported per context (the world and battle share keys on purpose).
	InputBindings.install({InputBindings.BRACE: PackedStringArray(["mouse:8"]), InputBindings.WORLD_INTERACT: PackedStringArray(["mouse:8"]),
		InputBindings.EVADE: PackedStringArray(["mouse:8"])})
	assert_eq(InputBindings.conflicts(InputBindings.BRACE, "mouse:8"), [InputBindings.EVADE] as Array[StringName])
	assert_empty(InputBindings.conflicts(InputBindings.WORLD_INTERACT, "mouse:8"))
	assert_empty(InputBindings.conflicts(InputBindings.BRACE, "mouse:9"))


func test_a_mouse_bound_menu_action_reaches_the_focused_control_only() -> void:
	InputBindings.install({InputBindings.CONFIRM: PackedStringArray(["mouse:8", "key:Enter", "joy:0"]),
		InputBindings.CANCEL: PackedStringArray(["mouse:9", "key:Escape"])})
	# The mouse codes are not copied into the built-in UI actions: a positional click must never
	# press the control under the pointer as well as the focused one.
	for ui_action: StringName in [&"ui_accept", &"ui_cancel"]:
		for event in InputMap.action_get_events(ui_action):
			assert_false(event is InputEventMouseButton, "%s has no mouse event" % ui_action)
	assert_true(InputMap.action_get_events(&"ui_accept").any(func(event: InputEvent) -> bool: return event is InputEventKey),
		"the key mirror is unchanged")
	# The forwarded action event: Confirm -> ui_accept, Back -> ui_cancel, press and release.
	var confirm := InputBindings.ui_mirror_event(_mouse(MOUSE_BUTTON_XBUTTON1))
	assert_not_null(confirm)
	assert_eq([confirm.action, confirm.pressed], [&"ui_accept", true])
	var released := InputBindings.ui_mirror_event(_mouse(MOUSE_BUTTON_XBUTTON1, false))
	assert_eq([released.action, released.pressed], [&"ui_accept", false])
	assert_eq(InputBindings.ui_mirror_event(_mouse(MOUSE_BUTTON_XBUTTON2)).action, &"ui_cancel")
	assert_null(InputBindings.ui_mirror_event(_mouse(MOUSE_BUTTON_MIDDLE)), "an unbound button forwards nothing")
	assert_null(InputBindings.ui_mirror_event(_mouse(MOUSE_BUTTON_LEFT)), "left click is never forwarded")
	assert_null(InputBindings.ui_mirror_event(_key(KEY_ENTER)), "keys reach the focused control by themselves")
	# With defaults nothing is forwarded at all.
	InputBindings.install()
	assert_null(InputBindings.ui_mirror_event(_mouse(MOUSE_BUTTON_XBUTTON1)))
	# Through the scene: the focused button is pressed once by the forwarded action.
	InputBindings.install({InputBindings.CONFIRM: PackedStringArray(["mouse:8", "key:Enter", "joy:0"])})
	var tree := Engine.get_main_loop() as SceneTree
	var focused := Button.new()
	var other := Button.new()
	other.position = Vector2(0, 100)
	tree.root.add_child(focused)
	tree.root.add_child(other)
	var presses := {"focused": 0, "other": 0}
	focused.pressed.connect(func() -> void: presses.focused += 1)
	other.pressed.connect(func() -> void: presses.other += 1)
	focused.grab_focus()
	for pressed in [true, false]:
		var mirrored := InputBindings.ui_mirror_event(_mouse(MOUSE_BUTTON_XBUTTON1, pressed))
		tree.root.push_input(mirrored)
	await tree.process_frame
	assert_eq(presses, {"focused": 1, "other": 0}, "exactly the focused control, exactly once")
	focused.queue_free()
	other.queue_free()
	await tree.process_frame
