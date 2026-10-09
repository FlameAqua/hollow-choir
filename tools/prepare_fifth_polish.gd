extends SceneTree
## Mechanical delivery conversion and atlas integration of the generated eye repair.
const WORLD := "res://assets/art/world/first_footsteps_v01/"
func _initialize() -> void:
	var generated := Image.load_from_file(WORLD + "sources/hollow_mask_v05.png")
	generated.resize(64, 64, Image.INTERPOLATE_NEAREST)
	var atlas := Image.load_from_file(WORLD + "atlases/hollow_idle_v04.png")
	# Only the generated mask insert is consumed; registration and all other art stay exact.
	var patch := Rect2i(27, 27, 7, 5)
	for column in 2:
		atlas.blit_rect(generated, patch, patch.position + Vector2i(column * 64, 0))
	assert(atlas.save_png(WORLD + "atlases/hollow_idle_v05.png") == OK)
	var proof := atlas.get_region(Rect2i(0, 0, 64, 64))
	proof.resize(512, 512, Image.INTERPOLATE_NEAREST)
	proof.save_png("res://.godot/qa/mask_v05_proof.png")
	if OS.get_cmdline_user_args().has("--images-only"):
		quit()
		return
	var frames := (load(WORLD + "frames/hollow_motion_v04.tres") as SpriteFrames).duplicate(true) as SpriteFrames
	for animation in frames.get_animation_names():
		if not String(animation).begins_with("idle_"):
			continue
		for i in frames.get_frame_count(animation):
			var old := frames.get_frame_texture(animation, i) as AtlasTexture
			var texture := old.duplicate() as AtlasTexture
			texture.atlas = load(WORLD + "atlases/hollow_idle_v05.png")
			frames.set_frame(animation, i, texture)
	frames.set_meta(&"art_status", "v05_local_mask_eye_repair_registered_v04_breath")
	assert(ResourceSaver.save(frames, WORLD + "frames/hollow_motion_v05.tres") == OK)
	quit()
