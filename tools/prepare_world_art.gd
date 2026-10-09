extends SceneTree
## Mechanical atlas export only: crop measured regions, preserve alpha, resize with nearest sampling,
## align feet and write native resources. Generated sources are never changed. This is not pixel cleanup.
const ROOT := "res://assets/art/world/first_footsteps_v01/"
const SPEC := "res://docs/art/first_footsteps_v01/regions.json"
var _report: Dictionary = {}
var _images_only := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_images_only = OS.get_cmdline_user_args().has("--world-export-images-only")
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	for family in spec.actors:
		_export_actor(family)
	_export_static(spec.props, "props", Vector2i(128, 128), 4, Vector2i(64, 124))
	_export_static(spec.buildings, "buildings", Vector2i(192, 192), 3, Vector2i(96, 188))
	_export_terrain(spec.terrain)
	if _images_only:
		print("World art candidate PNG exports ready for Godot import.")
		quit()
		return
	var file := FileAccess.open(ROOT + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "generated_candidate_mechanical_export_not_pixel_cleanup",
		"source_spec": SPEC, "tile_size": 32, "assets": _report}, "\t") + "\n")
	print("World art: %d resources exported; original sources preserved." % _report.size())
	quit()

func _source(path: String) -> Image:
	var image := Image.load_from_file(ROOT + "sources/" + path)
	assert(image != null and not image.is_empty(), path)
	image.convert(Image.FORMAT_RGBA8)
	return image

func _rect(values: Array) -> Rect2i:
	return Rect2i(values[0], values[1], values[2], values[3])

func _blank(size: Vector2i) -> Image:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image

func _place(target: Image, source: Image, entry: Dictionary, scale_factor: float,
		origin: Vector2i, foot: Vector2i) -> void:
	var region := _rect(entry.region)
	var piece := source.get_region(region)
	var dimensions := Vector2i(maxi(1, roundi(region.size.x * scale_factor)),
		maxi(1, roundi(region.size.y * scale_factor)))
	piece.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_NEAREST)
	var pivot := Vector2(float(entry.pivot[0] - region.position.x), float(entry.pivot[1] - region.position.y))
	var destination := origin + foot - Vector2i(roundi(pivot.x * scale_factor), roundi(pivot.y * scale_factor))
	assert(destination.x >= origin.x and destination.y >= origin.y, "Export cell overflow")
	target.blit_rect(piece, Rect2i(Vector2i.ZERO, dimensions), destination)

func _png(image: Image, name: String) -> String:
	var path := ROOT + "atlases/" + name + ".png"
	assert(image.save_png(path) == OK, path)
	return path

func _save(resource: Resource, path: String) -> void:
	assert(ResourceSaver.save(resource, path) == OK, path)

func _export_actor(family: Dictionary) -> void:
	var cell := Vector2i(family.cell[0], family.cell[1])
	var foot := Vector2i(family.foot[0], family.foot[1])
	var source := _source(family.source)
	var rows: Array = family.rows
	var sheet := _blank(Vector2i(cell.x * 4, cell.y * rows.size()))
	var largest := 1.0
	for row in rows:
		for entry in row.frames:
			largest = maxf(largest, entry.region[3])
	var scale_factor := float(family.body_height) / largest
	for y in rows.size():
		for x in rows[y].frames.size():
			_place(sheet, source, rows[y].frames[x], scale_factor, Vector2i(x * cell.x, y * cell.y), foot)
	var png := _png(sheet, family.id)
	if _images_only:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for y in rows.size():
		var row: Dictionary = rows[y]
		var name := StringName(row.name)
		frames.add_animation(name)
		frames.set_animation_speed(name, family.fps)
		for x in row.frames.size():
			var texture := AtlasTexture.new()
			texture.atlas = load(png)
			texture.region = Rect2(Vector2(x * cell.x, y * cell.y), Vector2(cell))
			texture.filter_clip = true
			frames.add_frame(name, texture)
		if family.get("directional", false):
			var idle := StringName(String(name).replace("walk_", "idle_"))
			frames.add_animation(idle)
			frames.add_frame(idle, frames.get_frame_texture(name, 1))
	frames.set_meta(&"foot_anchor", foot)
	frames.set_meta(&"cell_size", cell)
	frames.set_meta(&"art_status", "generated_candidate")
	var path: String = ROOT + "frames/" + family.id + ".tres"
	_save(frames, path)
	frames.take_over_path(path)
	var node := Node2D.new()
	node.name = family.id.to_pascal_case()
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Visual"
	sprite.sprite_frames = frames
	sprite.animation = StringName(rows[0].name.replace("walk_", "idle_") if family.get("directional", false) else rows[0].name)
	sprite.offset = Vector2(cell) * 0.5 - Vector2(foot)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.add_child(sprite)
	sprite.owner = node
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	_save(scene, ROOT + "scenes/" + family.id + ".tscn")
	node.free()
	_report[family.id] = {"frames": path, "atlas": png, "cell": family.cell,
		"foot": family.foot, "body_height": family.body_height, "animations": frames.get_animation_names()}

func _export_static(entries: Array, name: String, cell: Vector2i, columns: int, foot: Vector2i) -> void:
	var sheet := _blank(Vector2i(cell.x * columns, cell.y * ceili(float(entries.size()) / columns)))
	for i in entries.size():
		var entry: Dictionary = entries[i]
		_place(sheet, _source(entry.source), entry, entry.scale, Vector2i(i % columns, i / columns) * cell, foot)
	var png := _png(sheet, name)
	if _images_only:
		return
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var texture := AtlasTexture.new()
		texture.atlas = load(png)
		texture.region = Rect2(Vector2(i % columns, i / columns) * Vector2(cell), Vector2(cell))
		texture.filter_clip = true
		var path: String = ROOT + "atlases/" + entry.id + ".tres"
		_save(texture, path)
		_report[entry.id] = {"texture": path, "atlas": png, "cell": [cell.x, cell.y], "foot": [foot.x, foot.y],
			"collision": "none_art_only"}

func _export_terrain(entries: Array) -> void:
	var sheet := _blank(Vector2i(128, 128))
	var source := _source("terrain.png")
	for i in entries.size():
		var piece := source.get_region(_rect(entries[i].region))
		piece.resize(32, 32, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(piece, Rect2i(0, 0, 32, 32), Vector2i(i % 4, i / 4) * 32)
	var png := _png(sheet, "terrain_32")
	if _images_only:
		return
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(png)
	atlas.texture_region_size = Vector2i(32, 32)
	for i in entries.size():
		if entries[i].get("status", "") != "rejected_corner_join":
			atlas.create_tile(Vector2i(i % 4, i / 4))
		_report[entries[i].id] = {"atlas": png, "tile": [i % 4, i / 4], "tile_size": 32,
			"status": entries[i].get("status", "candidate_manual_paint_only")}
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32, 32)
	tiles.add_source(atlas, 0)
	_save(tiles, ROOT + "terrain.tres")
