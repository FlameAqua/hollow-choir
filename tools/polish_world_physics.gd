extends SceneTree
## One-time post-art pass on authored scenes. Never invokes the graybox builder.
const ROOT := "res://scenes/world/areas/"
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tiles := load("res://scenes/world/tiles/collision_tiles.tres").duplicate(true) as TileSet
	var source := tiles.get_source(0) as TileSetAtlasSource
	for bits in range(1, 16):
		if not source.has_alternative_tile(Vector2i.ZERO, bits):
			source.create_alternative_tile(Vector2i.ZERO, bits)
		var data := source.get_tile_data(Vector2i.ZERO, bits)
		var left := -13.0 if bits & 1 else -16.0
		var top := -13.0 if bits & 2 else -16.0
		var right := 13.0 if bits & 4 else 16.0
		var bottom := 13.0 if bits & 8 else 16.0
		data.set_collision_polygons_count(0, 1)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]))
	assert(ResourceSaver.save(tiles, "res://scenes/world/tiles/collision_polish.tres") == OK)
	var terrain := load("res://assets/art/world/first_footsteps_v01/terrain.tres") as TileSet
	var layer := terrain.get_custom_data_layer_by_name("surface")
	if layer < 0:
		terrain.add_custom_data_layer()
		layer = terrain.get_custom_data_layers_count() - 1
		terrain.set_custom_data_layer_name(layer, "surface")
		terrain.set_custom_data_layer_type(layer, TYPE_STRING)
	var art := terrain.get_source(0) as TileSetAtlasSource
	for i in art.get_tiles_count():
		var coord := art.get_tile_id(i)
		var surface := "wood" if coord.y == 2 else "stone" if coord == Vector2i(3, 0) else "peat"
		art.get_tile_data(coord, 0).set_custom_data("surface", surface)
	assert(ResourceSaver.save(terrain, "res://assets/art/world/first_footsteps_v01/terrain.tres") == OK)
	for id in ["gloamstead", "briarfen_reedway"]:
		var area := load(ROOT + id + ".tscn").instantiate() as WorldArea
		root.add_child(area)
		var collision := area.collision_layer_node()
		collision.tile_set = tiles
		var ground := area.get_node("Ground") as TileMapLayer
		var shores := 0
		for cell in collision.get_used_cells():
			if ground.get_cell_atlas_coords(cell) != Vector2i(1, 0):
				continue
			var bits := 0
			var neighbors := [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
			for i in 4:
				var neighbor: Vector2i = cell + neighbors[i]
				if collision.get_cell_source_id(neighbor) < 0 and ground.get_cell_source_id(neighbor) >= 0:
					bits |= 1 << i
			if bits > 0:
				collision.set_cell(cell, 0, Vector2i.ZERO, bits)
				shores += 1
		var props := 0
		for node in area.find_children("*", "CollisionShape2D", true, false):
			var shape := node as CollisionShape2D
			var prop := shape.get_parent().get_parent()
			var size := Vector2.ZERO
			if String(prop.name).begins_with("Willow"):
				size = Vector2(54, 24)
			elif prop.name in [&"TownBell", &"WaysideBell"]:
				size = Vector2(78, 24)
			elif prop.name == &"SquareLamp":
				size = Vector2(26, 14)
			elif prop.name == &"PreparationBench":
				size = Vector2(44, 18)
			if size != Vector2.ZERO:
				var rectangle := RectangleShape2D.new()
				rectangle.size = size
				shape.shape = rectangle
				shape.position.y = -size.y * .5
				props += 1
		var packed := PackedScene.new()
		assert(packed.pack(area) == OK)
		assert(ResourceSaver.save(packed, ROOT + id + ".tscn") == OK)
		print(id, ": ", props, " prop bases corrected, ", shores, " shore cells inset 3px toward water; anchors/portals preserved")
		area.free()
	quit()
