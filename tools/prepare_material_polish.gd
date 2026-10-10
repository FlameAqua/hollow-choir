extends SceneTree
## Mechanical crop/nearest-neighbour export only. Generated source PNGs are immutable.
const UI := "res://assets/art/global/ui/material_v02/"
const WORLD := "res://assets/art/world/first_footsteps_v01/"

func _initialize() -> void:
	_run.call_deferred()

func _export(source: Image, rect: Rect2i, id: String, native: Vector2i) -> void:
	var piece := source.get_region(rect)
	piece.resize(native.x, native.y, Image.INTERPOLATE_NEAREST)
	assert(piece.save_png(UI + "textures/" + id + ".png") == OK)

func _run() -> void:
	var material := Image.load_from_file(UI + "sources/materials.png")
	var names := ["bag", "cloth", "inspection", "map", "attack", "technique", "utility", "selected", "portrait", "intent", "number", "tooltip"]
	for i in names.size():
		var x := i % 4
		var y := i / 4
		var rect := Rect2i(x * material.get_width() / 4, y * material.get_height() / 4, material.get_width() / 4, material.get_height() / 4)
		_export(material, rect, names[i], Vector2i(64, 64) if i >= 4 else Vector2i(128, 128))
	_export(material, Rect2i(5, 1008, 304, 133), "slider_track", Vector2i(128, 32))
	_export(material, Rect2i(321, 1008, 300, 133), "slider_fill", Vector2i(128, 32))
	_export(material, Rect2i(650, 940, 258, 260), "slider_knob", Vector2i(26, 26))
	_export(material, Rect2i(947, 1014, 301, 112), "header", Vector2i(128, 48))
	var reaction := Image.load_from_file(UI + "sources/reactions.png")
	# The two rings are square crops centred on their art (sheet bounds x 28-317 / 345-635, y 34-323).
	# The earlier hand-measured squares sat up-left of it, so the exported rings were off-centre and
	# lost their right and bottom ornaments (V0.5 playtest).
	var regions := {
		"ring": Rect2i(25, 31, 295, 295), "ring_open": Rect2i(343, 31, 295, 295),
		"needle": Rect2i(679, 9, 180, 286), "impact": Rect2i(976, 18, 246, 282),
		"brace": Rect2i(10, 316, 297, 292), "evade": Rect2i(321, 316, 297, 292),
		"parry": Rect2i(634, 316, 297, 292), "reaction_selected": Rect2i(946, 316, 297, 292),
		"timing_track": Rect2i(23, 690, 443, 156), "timing_fill": Rect2i(497, 725, 330, 96),
		"cursor": Rect2i(862, 714, 74, 108), "broken": Rect2i(972, 612, 258, 276),
		"broken_plaque": Rect2i(23, 932, 403, 223), "target_rim": Rect2i(434, 949, 226, 239),
		"scroll_corner": Rect2i(689, 916, 240, 278), "hollow_head": Rect2i(951, 889, 292, 317)
	}
	for id in regions:
		var rect: Rect2i = regions[id]
		var native := Vector2i(64, 64)
		if id in ["ring", "ring_open"]:
			native = Vector2i(128, 128)
		if id in ["timing_track", "timing_fill", "broken_plaque"]:
			native = Vector2i(128, 40)
		if id in ["needle", "cursor"]:
			native = Vector2i(16, 32)
		_export(reaction, rect, id, native)
	_export_idle()
	_export_crow()
	if OS.get_cmdline_user_args().has("--images-only"):
		quit()
		return
	var frames := (load(WORLD + "frames/hollow_motion_v02.tres") as SpriteFrames).duplicate(true) as SpriteFrames
	var directions := ["south", "north", "west", "east", "southwest", "southeast", "northwest", "northeast"]
	for i in directions.size():
		var animation := StringName("idle_" + directions[i])
		frames.clear(animation)
		frames.set_animation_speed(animation, 1.4)
		for j in 2:
			var texture := AtlasTexture.new()
			texture.atlas = load(WORLD + "atlases/hollow_idle_v03.png")
			texture.region = Rect2((i % 2 * 2 + j) * 64, (i / 2) * 64, 64, 64)
			texture.filter_clip = true
			frames.add_frame(animation, texture)
	frames.set_meta(&"art_status", "v03_authored_standing_idle_no_fractional_stretch")
	assert(ResourceSaver.save(frames, WORLD + "frames/hollow_motion_v03.tres") == OK)
	var crow := SpriteFrames.new()
	crow.remove_animation(&"default")
	crow.add_animation(&"idle")
	crow.set_animation_speed(&"idle", 2.0)
	for i in 4:
		var texture := AtlasTexture.new()
		texture.atlas = load("res://assets/art/global/familiars/sprites/bell_crow_idle_v02.png")
		texture.region = Rect2(i * 64, 0, 64, 64)
		texture.filter_clip = true
		crow.add_frame(&"idle", texture)
	assert(ResourceSaver.save(crow, "res://assets/art/global/familiars/frames/bell_crow_idle_v02.tres") == OK)
	print("Material polish: 32 UI assets; eight authored standing idle pairs; immutable sources preserved.")
	quit()

func _export_idle() -> void:
	var source := Image.load_from_file(WORLD + "sources/hollow_idle_v03.png")
	var bounds: Array[Rect2i] = []
	var largest := 1
	for y in 4:
		for x in 4:
			var rect := Rect2i(x * source.get_width() / 4, y * source.get_height() / 4, source.get_width() / 4, source.get_height() / 4)
			var piece := source.get_region(rect)
			var left := piece.get_width()
			var right := 0
			var top := piece.get_height()
			var bottom := 0
			for py in piece.get_height():
				for px in piece.get_width():
					if piece.get_pixel(px, py).a > .5:
						left = mini(left, px)
						right = maxi(right, px)
						top = mini(top, py)
						bottom = maxi(bottom, py)
			var bound := Rect2i(rect.position + Vector2i(left, top), Vector2i(right - left + 1, bottom - top + 1))
			bounds.append(bound)
			largest = maxi(largest, bound.size.y)
	var factor := 48.0 / largest
	var atlas := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for i in bounds.size():
		var piece := source.get_region(bounds[i])
		piece.resize(roundi(piece.get_width() * factor), roundi(piece.get_height() * factor), Image.INTERPOLATE_NEAREST)
		var at := Vector2i(i % 4, i / 4) * 64 + Vector2i(32 - piece.get_width() / 2, 60 - piece.get_height())
		atlas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), at)
	assert(atlas.save_png(WORLD + "atlases/hollow_idle_v03.png") == OK)

func _export_crow() -> void:
	var source := Image.load_from_file("res://assets/art/global/familiars/sources/bell_crow_idle_v02.png")
	var bounds: Array[Rect2i] = []
	var largest := 1
	for i in 4:
		var cell := Rect2i(i * source.get_width() / 4, 0, source.get_width() / 4, source.get_height())
		var piece := source.get_region(cell)
		var left := piece.get_width()
		var top := piece.get_height()
		var right := 0
		var bottom := 0
		for y in piece.get_height():
			for x in piece.get_width():
				if piece.get_pixel(x, y).a > .5:
					left = mini(left, x)
					right = maxi(right, x)
					top = mini(top, y)
					bottom = maxi(bottom, y)
		var used := Rect2i(left, top, right - left + 1, bottom - top + 1)
		bounds.append(Rect2i(cell.position + used.position, used.size))
		largest = maxi(largest, maxi(used.size.y, used.size.x))
	var atlas := Image.create_empty(256, 64, false, Image.FORMAT_RGBA8)
	var factor := 56.0 / largest
	for i in 4:
		var piece := source.get_region(bounds[i])
		piece.resize(roundi(piece.get_width() * factor), roundi(piece.get_height() * factor), Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(i * 64 + 32 - piece.get_width() / 2, 60 - piece.get_height()))
	assert(atlas.save_png("res://assets/art/global/familiars/sprites/bell_crow_idle_v02.png") == OK)
