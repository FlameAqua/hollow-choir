extends CanvasLayer
## Scene changes with a short fade and an optional typed payload for the next scene
## (e.g. a BattleLaunch). The receiving scene calls take_payload() in its _ready().

const MAIN_MENU := "res://scenes/main/main_menu.tscn"
const BATTLE := "res://scenes/battle/battle_scene.tscn"
const SANDBOX := "res://scenes/sandbox/combat_sandbox.tscn"
const SETTINGS := "res://scenes/main/settings_screen.tscn"
const FIELD_GUIDE := "res://scenes/main/field_guide.tscn"
const AUDIO_LAB := "res://scenes/main/audio_lab.tscn"
const WORLD := "res://scenes/world/world_host.tscn"
const FADE_TIME := 0.18

var _payload: RefCounted
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.03, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func goto(path: String, payload: RefCounted = null) -> void:
	if _busy:
		return
	_busy = true
	SessionLog.event("scene", path.get_file().get_basename())
	_payload = payload
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: could not open %s (%d)" % [path, err])
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Returns and clears the payload handed to the current scene.
func take_payload() -> RefCounted:
	var payload := _payload
	_payload = null
	return payload


func start_battle(launch: BattleLaunch) -> void:
	goto(BATTLE, launch)
