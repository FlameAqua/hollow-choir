extends SceneTree
const WORLD := "res://assets/art/world/first_footsteps_v01/"

func _initialize() -> void:
	var icon := Image.load_from_file("res://assets/art/global/icon/sources/hollow_choir_v01.png")
	icon.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	assert(icon.save_png("res://assets/art/global/icon/hollow_choir_v01.png") == OK)
	var source := Image.load_from_file(WORLD + "sources/hollow_idle_v04.png")
	var pieces: Array[Image] = []
	var largest := 1
	for i in 16:
		var cell := Rect2i(i % 4 * source.get_width() / 4, i / 4 * source.get_height() / 4, source.get_width() / 4, source.get_height() / 4)
		var piece := source.get_region(cell)
		# Ignore almost-transparent delivery fringe when finding the actual painted silhouette.
		var left := piece.get_width()
		var top := piece.get_height()
		var right := 0
		var bottom := 0
		for y in piece.get_height():
			for x in piece.get_width():
				if piece.get_pixel(x, y).a > .5:
					left = mini(left, x)
					top = mini(top, y)
					right = maxi(right, x)
					bottom = maxi(bottom, y)
		var bound := Rect2i(left, top, right - left + 1, bottom - top + 1)
		pieces.append(piece.get_region(bound))
		largest = maxi(largest, bound.size.y)
	var atlas := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	var factor := 48.0 / largest
	for i in 16:
		var piece := pieces[i]
		piece.resize(roundi(piece.get_width() * factor), roundi(piece.get_height() * factor), Image.INTERPOLATE_NEAREST)
		# Shared foot baseline. The runtime holds the canonical head and boot pixels per pair.
		var offset := Vector2i(32 - piece.get_width() / 2, 60 - piece.get_height())
		atlas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(i % 4, i / 4) * 64 + offset)
	assert(atlas.save_png(WORLD + "atlases/hollow_idle_v04.png") == OK)
	if OS.get_cmdline_user_args().has("--images-only"):
		quit()
		return
	var frames := (load(WORLD + "frames/hollow_motion_v03.tres") as SpriteFrames).duplicate(true) as SpriteFrames
	var directions := ["south", "north", "west", "east", "southwest", "southeast", "northwest", "northeast"]
	for i in 8:
		var animation := StringName("idle_" + directions[i])
		frames.clear(animation)
		frames.set_animation_speed(animation, 1.4)
		for j in 2:
			var texture := AtlasTexture.new()
			texture.atlas = load(WORLD + "atlases/hollow_idle_v04.png")
			texture.region = Rect2((i % 2 * 2 + j) * 64, i / 2 * 64, 64, 64)
			texture.filter_clip = true
			frames.add_frame(animation, texture)
	frames.set_meta(&"art_status", "v04_stable_head_and_boots_authored_torso_breath")
	assert(ResourceSaver.save(frames, WORLD + "frames/hollow_motion_v04.tres") == OK)
	quit()
