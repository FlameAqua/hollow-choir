extends Node
## Loads, applies and saves GameSettings (user://settings.cfg). Difficulty and assist can change at
## any time, including mid-save; the next battle (or the sandbox restart) picks them up.

const PATH := "user://settings.cfg"

var data := GameSettings.new()
var _applied_resolution := Vector2i.ZERO
var _applied_window_mode := -1


func _ready() -> void:
	load_settings()
	apply()
	# Every event the window receives (before any node can consume it) tells us which device the
	# player is using, so prompts show the right bindings.
	get_tree().root.window_input.connect(func(event: InputEvent) -> void:
		if InputBindings.note_event(event):
			EventBus.input_device_changed.emit())


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		data.read_from(config)
	InputBindings.install(data.bindings)


func save_settings() -> Error:
	var config := ConfigFile.new()
	data.write_to(config)
	return config.save(PATH)


## Sets one field, saves, re-applies and notifies listeners.
func set_value(field: String, value: Variant) -> void:
	data.set(field, value)
	save_settings()
	apply()
	EventBus.settings_changed.emit()


func set_binding(action: StringName, codes: PackedStringArray) -> void:
	data.bindings[action] = codes
	InputBindings.install(data.bindings)
	save_settings()
	EventBus.settings_changed.emit()


func reset_bindings() -> void:
	data.bindings = {}
	InputBindings.install()
	save_settings()
	EventBus.settings_changed.emit()


func apply() -> void:
	_apply_window()
	AudioManager.set_bus_volume(AudioManager.BUS_MASTER, data.master_volume)
	AudioManager.set_bus_volume(AudioManager.BUS_MUSIC, data.music_volume)
	AudioManager.set_bus_volume(AudioManager.BUS_SFX, data.sfx_volume)
	get_tree().root.theme = UITheme.build(data.text_scale)


func difficulty_profile() -> TacticalDifficultyProfile:
	return Database.difficulty(data.tactical_difficulty)


func assist_profile() -> ExecutionAssistProfile:
	return data.resolve_assist(Database.assist(data.execution_assist))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _applied_resolution == data.window_resolution and _applied_window_mode == int(data.window_mode):
		return
	_applied_resolution = data.window_resolution
	_applied_window_mode = int(data.window_mode)
	match data.window_mode:
		GameSettings.WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		GameSettings.WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Keep the whole decorated window inside the current monitor's work area.
			var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			var fitted := Vector2i(mini(data.window_resolution.x, usable.size.x - 24), mini(data.window_resolution.y, usable.size.y - 56))
			DisplayServer.window_set_size(fitted)
			DisplayServer.window_set_position(usable.position + (usable.size - fitted) / 2)
