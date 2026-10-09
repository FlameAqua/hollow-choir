extends SceneTree
## Mechanical export of the v02 generated movement sheet; original source/atlas stay intact.
const ROOT := "res://assets/art/world/first_footsteps_v01/"
const DIRECTIONS := [&"west", &"east", &"southwest", &"southeast", &"northwest", &"northeast"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := Image.load_from_file(ROOT + "sources/hollow_motion_v02.png")
	var cell := Vector2i(source.get_width() / 4, source.get_height() / 6)
	var bounds: Array[Rect2i] = []
	var largest := 1
	for y in 6:
		for x in 4:
			var left := cell.x
			var top := cell.y
			var right := 0
			var bottom := 0
			for py in cell.y:
				for px in cell.x:
					if source.get_pixel(x * cell.x + px, y * cell.y + py).a > .5:
						left = mini(left, px)
						top = mini(top, py)
						right = maxi(right, px)
						bottom = maxi(bottom, py)
			var rect := Rect2i(left, top, right - left + 1, bottom - top + 1)
			bounds.append(rect)
			largest = maxi(largest, rect.size.y)
	var scale_factor := 48.0 / largest
	var atlas := Image.create_empty(256, 384, false, Image.FORMAT_RGBA8)
	for i in bounds.size():
		var rect := bounds[i]
		var piece := source.get_region(Rect2i(Vector2i(i % 4, i / 4) * cell + rect.position, rect.size))
		piece.resize(maxi(1, roundi(rect.size.x * scale_factor)), maxi(1, roundi(rect.size.y * scale_factor)), Image.INTERPOLATE_NEAREST)
		var at := Vector2i(i % 4, i / 4) * 64 + Vector2i(32 - piece.get_width() / 2, 60 - piece.get_height())
		atlas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), at)
	assert(atlas.save_png(ROOT + "atlases/hollow_motion_v02.png") == OK)
	if OS.get_cmdline_user_args().has("--images-only"):
		quit()
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var original := load(ROOT + "frames/hollow.tres") as SpriteFrames
	for direction in [&"north", &"south"]:
		var walk := StringName("walk_" + String(direction))
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 5)
		for i in original.get_frame_count(walk):
			frames.add_frame(walk, original.get_frame_texture(walk, i))
		var idle := StringName("idle_" + String(direction))
		frames.add_animation(idle)
		frames.add_frame(idle, original.get_frame_texture(walk, 1))
	for y in 6:
		var walk := StringName("walk_" + String(DIRECTIONS[y]))
		var idle := StringName("idle_" + String(DIRECTIONS[y]))
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 5)
		for x in 4:
			var texture := AtlasTexture.new()
			texture.atlas = load(ROOT + "atlases/hollow_motion_v02.png")
			texture.region = Rect2(x * 64, y * 64, 64, 64)
			texture.filter_clip = true
			frames.add_frame(walk, texture)
		frames.add_animation(idle)
		frames.add_frame(idle, frames.get_frame_texture(walk, 1))
	frames.set_meta(&"foot_anchor", Vector2i(32, 60))
	frames.set_meta(&"cell_size", Vector2i(64, 64))
	frames.set_meta(&"art_status", "generated_v02_candidate_with_alternating_contact_and_passing_poses")
	assert(ResourceSaver.save(frames, ROOT + "frames/hollow_motion_v02.tres") == OK)
	print("Hollow motion: eight walk/idle directions; 5 fps; originals preserved")
	quit()
