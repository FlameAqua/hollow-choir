extends SceneTree
## Mechanical crop, flip/rotate and nearest export of immutable generated bitmap sources.
const UI := "res://assets/art/global/ui/material_v03/"
const CROW := "res://assets/art/global/familiars/"

func _initialize() -> void:
	_run.call_deferred()

func _bounds(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := 0
	var bottom := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > .5:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1)

func _save(image: Image, id: String, native: Vector2i) -> void:
	image.resize(native.x, native.y, Image.INTERPOLATE_NEAREST)
	assert(image.save_png(UI + "textures/" + id + ".png") == OK)

func _run() -> void:
	var atlas := Image.load_from_file(UI + "sources/controls.png")
	var ids := ["check", "dropdown", "scroll_track", "scroll_thumb", "map", "menu", "log", "pause", "setup", "restart", "turn_order", "intent_socket", "brace", "evade", "parry", "peat"]
	for i in ids.size():
		var rect := Rect2i(i % 4 * atlas.get_width() / 4, i / 4 * atlas.get_height() / 4, atlas.get_width() / 4, atlas.get_height() / 4)
		var piece := atlas.get_region(rect)
		piece = piece.get_region(_bounds(piece))
		var native := Vector2i(64, 64)
		if i == 0: native = Vector2i(22, 22)
		if i == 1: native = Vector2i(16, 10)
		if i == 2: native = Vector2i(16, 64)
		if i == 3: native = Vector2i(16, 48)
		if i == 15:
			# The supplied tile has an edge: crop its quiet interior for a frameless material.
			piece = piece.get_region(Rect2i(12, 12, piece.get_width() - 24, piece.get_height() - 24))
			native = Vector2i(256, 256)
		_save(piece, ids[i], native)
		if i == 1:
			piece.flip_y()
			_save(piece, "scroll_up", Vector2i(16, 10))
		if i in [2, 3]:
			piece.rotate_90(CLOCKWISE)
			_save(piece, "h_" + ids[i], Vector2i(native.y, native.x))
	var title := Image.load_from_file(UI + "sources/wordmark.png")
	title = title.get_region(_bounds(title))
	_save(title, "wordmark", Vector2i(roundi(title.get_width() * 120.0 / title.get_height()), 120))
	if OS.get_cmdline_user_args().has("--controls-only"):
		quit()
		return
	var source := Image.load_from_file(CROW + "sources/bell_crow_idle_v03_clean.png")
	var birds: Array[Image] = []
	var largest := 1
	for i in 6:
		var bird := source.get_region(Rect2i(i % 3 * source.get_width() / 3, i / 3 * source.get_height() / 2, source.get_width() / 3, source.get_height() / 2))
		bird = bird.get_region(_bounds(bird))
		largest = maxi(largest, maxi(bird.get_width(), bird.get_height()))
		birds.append(bird)
	var crow_atlas := Image.create_empty(384, 64, false, Image.FORMAT_RGBA8)
	for i in birds.size():
		var bird := birds[i]
		var scale := 56.0 / largest
		bird.resize(roundi(bird.get_width() * scale), roundi(bird.get_height() * scale), Image.INTERPOLATE_NEAREST)
		crow_atlas.blit_rect(bird, Rect2i(Vector2i.ZERO, bird.get_size()), Vector2i(i * 64 + 32 - bird.get_width() / 2, 60 - bird.get_height()))
	assert(crow_atlas.save_png(CROW + "sprites/bell_crow_idle_v03.png") == OK)
	if not OS.get_cmdline_user_args().has("--images-only"):
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for animation in [&"idle", &"fidget"]:
			frames.add_animation(animation)
			frames.set_animation_speed(animation, .8 if animation == &"idle" else 4.0)
			frames.set_animation_loop(animation, animation == &"idle")
			for i in (2 if animation == &"idle" else 4):
				var texture := AtlasTexture.new()
				texture.atlas = load(CROW + "sprites/bell_crow_idle_v03.png")
				texture.region = Rect2((i + (0 if animation == &"idle" else 2)) * 64, 0, 64, 64)
				texture.filter_clip = true
				frames.add_frame(animation, texture)
		assert(ResourceSaver.save(frames, CROW + "frames/bell_crow_idle_v03.tres") == OK)
	print("Control polish native assets exported.")
	quit()
