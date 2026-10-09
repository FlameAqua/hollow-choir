extends Node
## Runtime half of tools/capture_collision.gd (loaded once the autoloads exist). See that file.

const QA_USER_DATA := preload("res://tools/qa_user_data.gd")
## name: [area, prop node under DepthSorted, walk start, walk target (prop-local), world state]
const SHOTS := {
	"willow-east": [&"gloamstead", "Willow8_46", Vector2(84, -10), Vector2(3, -13), "fresh"],
	"willow-west": [&"gloamstead", "Willow8_46", Vector2(-84, -12), Vector2(3, -13), "fresh"],
	"willow-behind": [&"gloamstead", "Willow8_46", Vector2(3, -96), Vector2(3, -13), "fresh"],
	"reedway-willow": [&"briarfen_reedway", "Dress7_22", Vector2(84, -10), Vector2(3, -13), "fresh"],
	"wayside-bell-west": [&"briarfen_reedway", "WaysideBell", Vector2(-64, -16), Vector2(0, -12), "open"],
	"stones-west": [&"briarfen_reedway", "ListeningStones", Vector2(-84, -9), Vector2(0, -8), "fresh"],
	"lamp-west": [&"gloamstead", "SquareLamp", Vector2(-80, -8), Vector2(-9.5, -7.5), "fresh"],
	"lamp-east": [&"gloamstead", "SquareLamp", Vector2(70, -5), Vector2(-9.5, -7.5), "fresh"],
	"latch-open-west-post": [&"briarfen_reedway", "ReturnLatch", Vector2(-84, -15), Vector2(-20, -14.5), "open"],
	"latch-open-through": [&"briarfen_reedway", "ReturnLatch", Vector2(0, -72), Vector2(0, -14), "open"],
}

var _args := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame


func _run() -> void:
	if not QA_USER_DATA.check():
		get_tree().quit(1)
		return
	Settings.data.window_resolution = Vector2i(1280, 720)
	Settings.data.reduce_motion = true
	Settings.apply()
	get_tree().debug_collisions_hint = true
	var out := ProjectSettings.globalize_path(String(_args.get("out", "user://collision")))
	DirAccess.make_dir_recursive_absolute(out)
	var definition := WorldDefinition.load_default()
	for shot_name: String in SHOTS:
		if _args.has("shot") and _args.shot != shot_name:
			continue
		var shot: Array = SHOTS[shot_name]
		var area := (load(definition.area(shot[0]).scene_path) as PackedScene).instantiate() as WorldArea
		get_tree().root.add_child(area)
		area.collision_layer_node().visible = true
		area.collision_layer_node().modulate.a = 0.3
		var world := WorldState.new()
		if shot[4] == "open":
			world.cleared.append_array([&"reedway_patrol", &"bell_guard"])
			world.wayside_bell_restored = true
			world.return_latch_open = true
		area.apply_state(world)
		var prop := area.get_node("DepthSorted/" + String(shot[1])) as Node2D
		var player := WorldPlayer.new()
		area.depth_layer().add_child(player)
		player.camera().enabled = false
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.place(prop.position + shot[2])
		var target: Vector2 = prop.position + shot[3]
		for step in 240:
			var to := target - player.position
			if to.length() < 1.0:
				break
			player.step(to.normalized(), 1.0 / 60.0)
		player.stop()
		var camera := Camera2D.new()
		camera.zoom = Vector2(4, 4)
		camera.position = prop.position + Vector2(0, -40)
		area.add_child(camera)
		camera.make_current()
		await _frames(6)
		var path := out.path_join(shot_name + ".png")
		var err := get_viewport().get_texture().get_image().save_png(path)
		print("%s %s · feet rest at %s from the prop" % ["saved" if err == OK else "FAILED", path, (player.position - prop.position).round()])
		area.queue_free()
		await _frames(2)
	AudioManager.silence()
	await _frames(3)
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()
