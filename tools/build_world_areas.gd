extends SceneTree
## One-shot bootstrap for the V0.4 area scenes (graybox traversal pass). Reads the runtime world
## definition, paints native TileMapLayers (Ground from the Director's terrain atlas, a separate
## painted Collision layer), places foot-origin art instances, footprints, state views, landmark
## points, safe anchors and portal triggers, then saves ordinary editable scenes.
##
##   python tools/qa_godot.py --headless --script res://tools/build_world_areas.gd [-- --force]
##
## After the first run the scenes are authored content: edit them in the editor. Existing scenes
## are never overwritten without --force (which discards hand edits). Deterministic; no RNG.

const PACK := "res://assets/art/world/first_footsteps_v01/"
const COLLISION_TILESET := "res://scenes/world/tiles/collision_tiles.tres"
const T := 32
const SOLID_LAYER := 2
const DUSK := Color(0.76, 0.82, 0.84)

const PEAT := Vector2i(0, 0)
const WATER := Vector2i(1, 0)
const PATH := Vector2i(2, 0)
const PAVING := Vector2i(3, 0)
const BOARD_NS := Vector2i(0, 2)
const BOARD_EW := Vector2i(1, 2)

## Cell kinds of the graybox grid.
enum Cell { PEAT, PATH, PAVING, BOARD, SOLID_WATER, SOLID_LAND }

var _definition: WorldDefinition
var _root: WorldArea
var _cells: Dictionary = {}
var _board_dir: Dictionary = {}
var _size: Vector2i


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var force := OS.get_cmdline_user_args().has("--force")
	_definition = load(WorldDefinition.PATH) as WorldDefinition
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/world/areas"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/world/tiles"))
	if force or not ResourceLoader.exists(COLLISION_TILESET):
		_save_collision_tileset()
	var failed := false
	for area in _definition.areas:
		if ResourceLoader.exists(area.scene_path) and not force:
			print("keep %s (authored; pass --force to rebuild)" % area.scene_path)
			continue
		_build(area)
		var packed := PackedScene.new()
		var err := packed.pack(_root)
		if err == OK:
			err = ResourceSaver.save(packed, area.scene_path)
		print("%s %s" % ["wrote" if err == OK else "FAILED", area.scene_path])
		failed = failed or err != OK
		_root.free()
	quit(1 if failed else 0)


# --- Collision tileset ---------------------------------------------------------------------------

func _save_collision_tileset() -> void:
	var image := Image.create(T, T, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.85, 0.2, 0.25, 0.55))
	for i in T:
		image.set_pixel(i, i, Color(1, 1, 1, 0.8))
		image.set_pixel(i, T - 1 - i, Color(1, 1, 1, 0.8))
		image.set_pixel(i, 0, Color(1, 0.4, 0.4, 0.9))
		image.set_pixel(0, i, Color(1, 0.4, 0.4, 0.9))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, SOLID_LAYER)
	tileset.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(T, T)
	tileset.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	var h := T * 0.5
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	var err := ResourceSaver.save(tileset, COLLISION_TILESET)
	print("%s %s" % ["wrote" if err == OK else "FAILED", COLLISION_TILESET])


# --- Area assembly -------------------------------------------------------------------------------

func _build(area: AreaDefinition) -> void:
	_cells.clear()
	_board_dir.clear()
	_size = area.size_tiles
	_root = WorldArea.new()
	_root.name = String(area.id).to_pascal_case()
	_root.area_id = area.id
	var ground := _tile_layer("Ground", load(PACK + "terrain.tres"), 0)
	var detail := _tile_layer("GroundDetail", load(PACK + "terrain.tres"), 0)
	detail.set_meta("_note", "Boardwalk pieces, ripples and marks below feet. Never implies collision.")
	_node("LowDecoration", 1)
	var depth := _node("DepthSorted", 2)
	depth.y_sort_enabled = true
	_node("Overhead", 3)
	var lighting := CanvasModulate.new()
	lighting.name = "WorldLighting"
	lighting.color = DUSK
	_add(_root, lighting)
	_node("WorldEffects", 3)
	var collision := _tile_layer("Collision", load(COLLISION_TILESET), 4)
	collision.set_meta("_note", "Backend graybox: painted solid cells (water, fences, bounds). Hidden at runtime.")
	_node("Solids", 0)
	_node("Interactions", 0)
	_node("Anchors", 0)
	_node("Portals", 0)
	if area.id == &"gloamstead":
		_gloamstead(area)
	else:
		_reedway(area)
	for cell: Vector2i in _cells:
		var kind: Cell = _cells[cell]
		ground.set_cell(cell, 0, _atlas_for(cell, kind))
		if kind == Cell.SOLID_WATER or kind == Cell.SOLID_LAND:
			collision.set_cell(cell, 0, Vector2i.ZERO)
	for landmark in area.landmarks:
		var point := WorldPoint.new()
		point.name = String(landmark.id)
		point.position = _landmark_point(landmark)
		point.radius = landmark.interact_radius if landmark.interact_radius > 0.0 else landmark.discover_radius
		_add(_root.get_node("Interactions"), point)


func _gloamstead(area: AreaDefinition) -> void:
	_fill(Cell.PEAT)
	for path in area.paths:
		_paint_path(path, Cell.PATH)
	_paint_disc(Vector2(32, 30), 5.5, Cell.PAVING)
	_ring(2, Cell.SOLID_WATER)
	# Reed fence with a two-tile gate; the fen lies beyond it, crossed by one boardwalk corridor.
	for y in range(2, _size.y - 2):
		if y != 25 and y != 26:
			_cells[Vector2i(66, y)] = Cell.SOLID_LAND
		for x in range(67, _size.x - 2):
			var corridor := y >= 23 and y <= 28
			var planks := y == 25 or y == 26
			_cells[Vector2i(x, y)] = (Cell.BOARD if planks else Cell.PEAT) if corridor else Cell.SOLID_WATER
			if planks:
				_board_dir[Vector2i(x, y)] = BOARD_EW
	_portal("reed_gate", Vector2(72.5, 26.0) * T, Vector2(3, 6) * T)
	_anchor("town_bell", _tile(32, 32))
	_anchor("reed_gate", _tile(63, 26))
	# Landmarks and their visible state.
	var bell := _prop_root("TownBell", _foot(32, 30), Vector2(54, 20))
	_state_sprite(bell, "Quiet", WorldDefinition.FLAG_BELL, false, "town_bell_quiet")
	_state_sprite(bell, "Answering", WorldDefinition.FLAG_BELL, true, "town_bell_answering")
	var lamp := _prop_root("SquareLamp", _foot(35, 29), Vector2(12, 8))
	_state_sprite(lamp, "Unlit", WorldDefinition.FLAG_BELL, false, "lamp_unlit")
	var lit := _state_sprite(lamp, "Lit", WorldDefinition.FLAG_BELL, true, "lamp_lit")
	_warm_light(lit)
	_prop("preparation_bench", _foot(15, 31), Vector2(38, 14))
	var gate := _prop("reed_gate", _foot(66, 26) + Vector2(0, 4), Vector2.ZERO)
	gate.scale = Vector2(1.5, 1.5)
	_actor("Bellkeeper", "bellkeeper", _foot(26, 25), Vector2(16, 8))
	_facade("stillroom", Vector2(17, 23) * T, 128)
	_facade("home", Vector2(41, 22) * T, 112)
	_facade("home", Vector2(47.5, 22) * T, 112, "HomeEast")
	_facade("workshop", Vector2(46, 49) * T, 160)
	# Fixed dressing: reeds along the fence line, willows in the yards.
	for y in range(4, _size.y - 3, 3):
		if absi(y - 25) > 2:
			_prop("reeds", _foot(66, y), Vector2.ZERO, "FenceReeds%d" % y)
	for spot: Vector2i in [Vector2i(6, 8), Vector2i(8, 46), Vector2i(28, 48), Vector2i(58, 8), Vector2i(60, 46), Vector2i(30, 8)]:
		_prop("willow", _foot(spot.x, spot.y), Vector2(18, 10), "Willow%d_%d" % [spot.x, spot.y])


func _reedway(area: AreaDefinition) -> void:
	_fill(Cell.SOLID_WATER)
	for path in area.paths:
		_paint_path(path, Cell.PEAT if path.id in [&"outside_loop", &"overlook"] else Cell.BOARD)
	var corridor := WorldPath.new()
	corridor.points = PackedVector2Array([Vector2(22, 76), Vector2(22, 85)])
	corridor.width_tiles = 4
	_paint_path(corridor, Cell.BOARD)
	for pad: Array in [[Vector2(22, 76), 2.5], [Vector2(26, 59), 2.5], [Vector2(65, 15), 3.0], [Vector2(60, 25), 3.0],
			[Vector2(84, 40), 3.0]]:
		_paint_disc(pad[0], pad[1], Cell.PEAT)
	_ring(2, Cell.SOLID_WATER)
	_portal("reedway_entry", Vector2(22.5, 84.0) * T, Vector2(5, 3) * T)
	_anchor("reedway_entry", _tile(22, 76))
	_anchor("reedway_fork", _tile(26, 59))
	_anchor("reedway_patrol", Vector2(27.0, 47.5) * T)
	_anchor("bell_guard", Vector2(52.5, 26.2) * T)
	_anchor("wayside_bell", _tile(65, 16))
	_anchor("return_latch", _tile(65, 61))
	_anchor("listening_stones", _tile(84, 41))
	var patrol := _view_root("PatrolGroup", _foot(27, 39), WorldStateView.Source.CLEARED, &"reedway_patrol", false)
	_instance(patrol, "fen_patrol")
	_footprint(patrol, Vector2(32, 10))
	var guard := _view_root("GuardGroup", _foot(60, 25), WorldStateView.Source.CLEARED, &"bell_guard", false)
	_instance(guard, "rot_grove")
	_footprint(guard, Vector2(32, 10))
	var bell := _prop_root("WaysideBell", _foot(65, 13), Vector2(54, 20))
	_state_sprite(bell, "Quiet", WorldDefinition.FLAG_BELL, false, "wayside_bell_quiet")
	_state_sprite(bell, "Restored", WorldDefinition.FLAG_BELL, true, "wayside_bell_restored")
	var latch := _prop_root("ReturnLatch", Vector2(65.5, 64.0) * T, Vector2.ZERO)
	var closed := _state_sprite(latch, "Closed", WorldDefinition.FLAG_LATCH, false, "return_latch_closed")
	var barrier := StaticBody2D.new()
	barrier.name = "Barrier"
	barrier.collision_layer = SOLID_LAYER
	barrier.collision_mask = 0
	_add(closed, barrier)
	_shape(barrier, Rect2(-4 * T, -T, 8 * T, T))
	_state_sprite(latch, "Open", WorldDefinition.FLAG_LATCH, true, "return_latch_open")
	_prop("listening_stones", _foot(84, 38), Vector2(46, 16))
	_prop("fallen_root", _foot(31, 44), Vector2.ZERO)
	_prop("boulders", _foot(14, 30), Vector2.ZERO)
	# Fixed dressing on water cells touching the walkable network (every fifth such cell).
	var count := 0
	for y in range(3, _size.y - 3):
		for x in range(3, _size.x - 3):
			var cell := Vector2i(x, y)
			if _cells[cell] != Cell.SOLID_WATER or not _touches_walkable(cell):
				continue
			count += 1
			if count % 5 == 0:
				var kind := "willow" if count % 35 == 0 else "reeds"
				_prop(kind, _foot(x, y), Vector2.ZERO, "Dress%d_%d" % [x, y])


func _landmark_point(landmark: LandmarkDefinition) -> Vector2:
	match landmark.id:
		&"return_latch":
			return Vector2(65.5, 63.5) * T
		&"wayside_bell":
			return Vector2(65.5, 15.0) * T
		&"listening_stones":
			return Vector2(84.5, 40.0) * T
	return _tile(landmark.tile.x, landmark.tile.y)


# --- Grid painting -------------------------------------------------------------------------------

func _fill(kind: Cell) -> void:
	for y in _size.y:
		for x in _size.x:
			_cells[Vector2i(x, y)] = kind


func _ring(thickness: int, kind: Cell) -> void:
	for y in _size.y:
		for x in _size.x:
			if x < thickness or y < thickness or x >= _size.x - thickness or y >= _size.y - thickness:
				_cells[Vector2i(x, y)] = kind


func _paint_path(path: WorldPath, kind: Cell) -> void:
	var half := path.width_tiles * T * 0.5
	for y in _size.y:
		for x in _size.x:
			var centre := _tile(x, y)
			var distance := path.distance_to(centre, T)
			if distance > half:
				continue
			var cell := Vector2i(x, y)
			# A boardwalk is one plank line down the centre of a walkable peat bank, so the painted
			# water never suggests a wall where the feet can walk.
			if kind == Cell.BOARD and distance > T * 0.5:
				if _cells.get(cell) != Cell.BOARD:
					_cells[cell] = Cell.PEAT
				continue
			_cells[cell] = kind
			if kind == Cell.BOARD:
				_board_dir[cell] = _segment_dir(path, centre)


func _paint_disc(centre_tile: Vector2, radius_tiles: float, kind: Cell) -> void:
	var centre := (centre_tile + Vector2(0.5, 0.5)) * T
	for y in _size.y:
		for x in _size.x:
			if _tile(x, y).distance_to(centre) <= radius_tiles * T:
				_cells[Vector2i(x, y)] = kind


func _segment_dir(path: WorldPath, at: Vector2) -> Vector2i:
	var best := INF
	var dir := BOARD_NS
	for index in range(path.points.size() - 1):
		var a := (path.points[index] + Vector2(0.5, 0.5)) * T
		var b := (path.points[index + 1] + Vector2(0.5, 0.5)) * T
		var distance := at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
		if distance < best:
			best = distance
			dir = BOARD_EW if absf(b.x - a.x) > absf(b.y - a.y) else BOARD_NS
	return dir


func _atlas_for(cell: Vector2i, kind: Cell) -> Vector2i:
	match kind:
		Cell.PATH:
			return PATH
		Cell.PAVING:
			return PAVING
		Cell.BOARD:
			return _board_dir.get(cell, BOARD_NS)
		Cell.SOLID_WATER:
			return WATER
	return PEAT


func _touches_walkable(cell: Vector2i) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var kind: Cell = _cells.get(cell + offset, Cell.SOLID_WATER)
		if kind != Cell.SOLID_WATER and kind != Cell.SOLID_LAND:
			return true
	return false


# --- Node helpers --------------------------------------------------------------------------------

func _tile(x: float, y: float) -> Vector2:
	return (Vector2(x, y) + Vector2(0.5, 0.5)) * T


## Ground contact for a prop standing on tile (x, y): bottom centre of the tile.
func _foot(x: float, y: float) -> Vector2:
	return Vector2((x + 0.5) * T, (y + 1.0) * T)


func _add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = _root
	return child


func _node(node_name: String, z: int) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	node.z_index = z
	_add(_root, node)
	return node


func _tile_layer(node_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.tile_set = tileset
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add(_root, layer)
	return layer


func _anchor(anchor_id: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = anchor_id
	marker.position = at
	_add(_root.get_node("Anchors"), marker)


func _portal(landmark_id: String, centre: Vector2, size: Vector2) -> void:
	var portal := WorldPortal.new()
	portal.name = landmark_id
	portal.position = centre
	portal.size = size
	_add(_root.get_node("Portals"), portal)


func _sprite(parent: Node, texture_id: String, foot: Vector2, sprite_name: String = "Sprite") -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = load(PACK + "atlases/" + texture_id + ".tres")
	sprite.centered = false
	sprite.position = -foot
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add(parent, sprite)
	return sprite


func _prop_root(node_name: String, foot: Vector2, solid: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	node.position = foot
	_add(_root.get_node("DepthSorted"), node)
	if solid != Vector2.ZERO:
		_footprint(node, solid)
	return node


func _prop(texture_id: String, foot: Vector2, solid: Vector2, node_name: String = "") -> Node2D:
	var node := _prop_root(node_name if not node_name.is_empty() else texture_id.to_pascal_case(), foot, solid)
	_sprite(node, texture_id, Vector2(64, 124))
	return node


func _view_root(node_name: String, foot: Vector2, source: WorldStateView.Source, key: StringName, show_when: bool) -> WorldStateView:
	var view := WorldStateView.new()
	view.name = node_name
	view.position = foot
	view.source = source
	view.key = key
	view.show_when = show_when
	_add(_root.get_node("DepthSorted"), view)
	return view


func _state_sprite(parent: Node2D, node_name: String, flag: StringName, show_when: bool, texture_id: String) -> WorldStateView:
	var view := WorldStateView.new()
	view.name = node_name
	view.source = WorldStateView.Source.FLAG
	view.key = flag
	view.show_when = show_when
	_add(parent, view)
	_sprite(view, texture_id, Vector2(64, 124))
	return view


func _instance(parent: Node, scene_id: String) -> Node:
	var instance := (load(PACK + "scenes/" + scene_id + ".tscn") as PackedScene).instantiate()
	parent.add_child(instance)
	instance.owner = _root
	return instance


func _actor(node_name: String, scene_id: String, foot: Vector2, solid: Vector2) -> void:
	var node := _prop_root(node_name, foot, solid)
	_instance(node, scene_id)


func _footprint(parent: Node2D, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_layer = SOLID_LAYER
	body.collision_mask = 0
	_add(parent, body)
	_shape(body, Rect2(-size.x * 0.5, -size.y, size.x, size.y))


func _shape(body: StaticBody2D, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.name = "Shape"
	collision.shape = shape
	collision.position = rect.get_center()
	_add(body, collision)


func _facade(module: String, foot: Vector2, width: float, node_name: String = "") -> void:
	var base := _prop_root(node_name if not node_name.is_empty() else module.to_pascal_case(), foot, Vector2(width + 8, 56))
	_sprite(base, module + "_walls", Vector2(96, 188), "Walls")
	var roof := Sprite2D.new()
	roof.name = base.name + "Roof"
	roof.texture = load(PACK + "atlases/" + module + "_roof.tres")
	roof.centered = false
	roof.position = foot + Vector2(-96, -264)
	roof.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add(_root.get_node("Overhead"), roof)


func _warm_light(parent: Node2D) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var light := PointLight2D.new()
	light.name = "LampLight"
	light.texture = texture
	light.color = Color(1.0, 0.78, 0.45)
	light.energy = 0.9
	light.position = Vector2(0, -56)
	_add(parent, light)
