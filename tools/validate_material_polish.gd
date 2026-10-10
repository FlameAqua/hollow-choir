extends SceneTree
## Asset integrity, not human art acceptance. Run after the editor imports generated native PNGs.
## Continuous slider/scrollbar strips (V0.5 playtest revision, tools/make_continuous_controls.py) are
## SVG with native end caps; every other material bitmap stays a native PNG.
const CONTINUOUS_STRIPS := ["slider_track", "slider_fill", "scroll_track", "scroll_thumb", "h_scroll_track", "h_scroll_thumb"]
var checks := 0
var failures := 0


static func _authored_format(id: String, texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.ends_with(".svg" if id in CONTINUOUS_STRIPS else ".png")

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	_check(UICraft.TEXTURES.size() == 32, "Material palette has 32 tracked bitmap assets")
	for id in UICraft.TEXTURES:
		var texture := UICraft.texture(id)
		_check(_authored_format(id, texture), "Bitmap asset: " + id)
		var config := ConfigFile.new()
		_check(config.load(texture.resource_path + ".import") == OK, "Import exists: " + id)
		_check(config.get_value("params", "compress/mode") == 0 and not config.get_value("params", "mipmaps/generate"), "Lossless/no mipmaps: " + id)
	_check(UICraft.CONTROLS.size() == 20, "Third-pass authored control assets")
	for id in UICraft.CONTROLS:
		var texture := UICraft.texture(id)
		_check(_authored_format(id, texture), "Control bitmap: " + id)
		var config := ConfigFile.new()
		_check(config.load(texture.resource_path + ".import") == OK, "Control import: " + id)
		_check(config.get_value("params", "compress/mode") == 0 and not config.get_value("params", "mipmaps/generate"), "Control lossless/no mipmaps: " + id)
	_check(UICraft.texture("intent_socket").get_image().get_pixel(32, 32).a > .95, "Intent socket restores opaque dark backing")
	for id in ["ring", "ring_open", "reaction_selected", "intent", "portrait"]:
		var image := UICraft.texture(id).get_image()
		_check(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a < .01, "Open socket alpha: " + id)
	for id in ["cloth", "inspection", "bag", "attack", "technique", "utility", "selected"]:
		_check(UICraft.panel(id) is StyleBoxTexture, "Authored panel texture: " + id)
	_check(CombatIcons.texture("stagger") == UICraft.texture("broken"), "Break uses the painted icon")
	var frames := load("res://assets/art/world/first_footsteps_v01/frames/hollow_motion_v04.tres") as SpriteFrames
	for direction in ["north", "south", "west", "east", "northwest", "northeast", "southwest", "southeast"]:
		var idle := StringName("idle_" + direction)
		_check(frames.get_frame_count(idle) == 2, "Authored standing pair: " + direction)
		_check(frames.get_frame_count(StringName("walk_" + direction)) == 4, "Walk retained: " + direction)
		_check(frames.get_frame_texture(idle, 0).get_image().get_data() != frames.get_frame_texture(idle, 1).get_image().get_data(), "Distinct idle frames: " + direction)
		for i in 2:
			_validate_feet(frames.get_frame_texture(idle, i), direction)
	var crow := load("res://assets/art/global/familiars/frames/bell_crow_idle_v03.tres") as SpriteFrames
	_check(crow.get_frame_count(&"idle") == 2, "Crow has a quiet authored breathing pair")
	_check(crow.get_frame_count(&"fidget") == 4 and not crow.get_animation_loop(&"fidget"), "Crow fidgets play once")
	for animation in [&"idle", &"fidget"]:
		for i in crow.get_frame_count(animation):
			_validate_feet(crow.get_frame_texture(animation, i), "crow")
	print("Material polish validation: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)

func _validate_feet(texture: Texture2D, label: String) -> void:
	var image := texture.get_image()
	_check(image.get_size() == Vector2i(64, 64), "Native cell: " + label)
	_check(image.get_pixel(0, 0).a < .01, "Transparent corner: " + label)
	var lowest := -1
	for y in 64:
		for x in 64:
			if image.get_pixel(x, y).a > .5:
				lowest = maxi(lowest, y)
	_check(abs(lowest - 60) <= 2, "Foot baseline: " + label)
