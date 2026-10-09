extends Node2D
## F6-only presentation fixture. No world host, battle launch, save, progression or production input map.
const PACK := "res://assets/art/world/first_footsteps_v01/"
const LAYOUT := "res://docs/design/world/v04_layout.json"
var _area := 0
var _restored := false
var _footprints := false
var _gallery := false
var _world: Node2D
var _ground: TileMapLayer
var _depth: Node2D
var _overhead: Node2D
var _player: CharacterBody2D
var _visual: AnimatedSprite2D
var _camera: Camera2D
var _tint: CanvasModulate
var _direction := "south"
var _obstacles: Array[Rect2] = []
var _capture := ""
var _capture_walk := ""
var _focus_building := false
var _areas: Array
var _lighting := false
var _debug_layer: Node2D
var _status: Label
var _sheet_view: PanelContainer

func _ready() -> void:
	_areas = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)).areas
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-capture="):
			_capture = arg.trim_prefix("--art-capture=")
		elif arg == "--art-area=reedway":
			_area = 1
		elif arg == "--art-restored":
			_restored = true
		elif arg == "--art-footprints":
			_footprints = true
		elif arg == "--art-gallery":
			_gallery = true
		elif arg == "--art-focus=building":
			_focus_building = true
		elif arg.begins_with("--art-walk="):
			_capture_walk = arg.trim_prefix("--art-walk=")
	_ui()
	_build()
	if not _capture.is_empty():
		_capture_frame.call_deferred()

func _build() -> void:
	if _world != null:
		remove_child(_world)
		_world.queue_free()
	_obstacles.clear()
	_world = Node2D.new()
	_world.name = "WorldPresentation"
	add_child(_world)
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = load(PACK + "terrain.tres").duplicate(true)
	_ground.tile_set.add_physics_layer()
	_ground.tile_set.set_physics_layer_collision_layer(0, 2)
	var water := (_ground.tile_set.get_source(0) as TileSetAtlasSource).get_tile_data(Vector2i(1, 0), 0)
	water.set_collision_polygons_count(0, 1)
	water.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	_world.add_child(_ground)
	var low := Node2D.new()
	low.name = "LowDecoration"
	low.z_index = 1
	_world.add_child(low)
	_depth = Node2D.new()
	_depth.name = "DepthSorted"
	_depth.y_sort_enabled = true
	_depth.z_index = 2
	_world.add_child(_depth)
	_overhead = Node2D.new()
	_overhead.name = "Overhead"
	_overhead.z_index = 3
	_world.add_child(_overhead)
	_debug_layer = Node2D.new()
	_debug_layer.name = "FootprintReview"
	_debug_layer.z_index = 8
	_debug_layer.draw.connect(_draw_footprints)
	_world.add_child(_debug_layer)
	_tint = CanvasModulate.new()
	_tint.name = "WorldLighting"
	_tint.color = Color(0.76,0.82,0.84) if _lighting else Color.WHITE
	_world.add_child(_tint)
	var area: Dictionary = _areas[_area]
	var dimensions := Vector2i(area.size_tiles[0], area.size_tiles[1])
	for y in dimensions.y:
		for x in dimensions.x:
			_ground.set_cell(Vector2i(x,y), 0, Vector2i(0 if _area == 0 else 1,0))
	for path in area.paths:
		for i in range(1, path.points.size()):
			_path(Vector2(path.points[i-1][0],path.points[i-1][1]), Vector2(path.points[i][0],path.points[i][1]), path.width_tiles)
	if _area == 0:
		for y in range(26,35):
			for x in range(27,38):
				_ground.set_cell(Vector2i(x,y),0,Vector2i(3,0))
		_prop("town_bell_answering" if _restored else "town_bell_quiet",Vector2(32,30)*32,Vector2(54,20))
		_prop("lamp_lit" if _restored else "lamp_unlit",Vector2(35,30)*32,Vector2(12,8))
		_prop("preparation_bench",Vector2(15,31)*32,Vector2(38,14))
		_prop("reed_gate",Vector2(67,26)*32)
		_actor("bellkeeper",Vector2(26,25)*32)
		_facade("stillroom",Vector2(23,23)*32,128)
		_facade("home",Vector2(43,23)*32,112)
		_facade("workshop",Vector2(42,42)*32,160)
	else:
		_prop("wayside_bell_restored" if _restored else "wayside_bell_quiet",Vector2(65,15)*32,Vector2(54,20))
		_prop("return_latch_open" if _restored else "return_latch_closed",Vector2(65,62)*32,Vector2.ZERO if _restored else Vector2(64,12))
		_prop("listening_stones",Vector2(84,40)*32,Vector2(46,16))
		_actor("fen_patrol",Vector2(27,39)*32)
		_actor("rot_grove",Vector2(60,25)*32)
	# Sparse fixed dressing. This never uses gameplay randomness.
	for i in 42:
		var p := Vector2i(5 + (i * 17) % (dimensions.x-10),5 + (i * 23) % (dimensions.y-10))
		if _ground.get_cell_atlas_coords(p) == Vector2i(0,0):
			_prop("willow" if i % 4 == 0 else "reeds",Vector2(p)*32,Vector2(18,10) if i % 4 == 0 else Vector2.ZERO)
	_spawn(dimensions)
	_status.text = "%s · %s · art fixture; no saved progress" % [area.name,"after" if _restored else "before"]
	if _gallery:
		_sheet_view.show()
	_debug_layer.queue_redraw()

func _path(from: Vector2, to: Vector2, width: int) -> void:
	var steps := ceili(from.distance_to(to)*2)
	for i in steps+1:
		var p := Vector2i(from.lerp(to,float(i)/maxi(1,steps)))
		for y in range(-width/2,width/2+1):
			for x in range(-width/2,width/2+1):
				_ground.set_cell(p+Vector2i(x,y),0,Vector2i(0 if _area else 2,0))
		if _area == 1:
			_ground.set_cell(p,0,Vector2i(0 if absf(to.y-from.y)>absf(to.x-from.x) else 1,2))

func _prop(id: String, at: Vector2, solid: Vector2 = Vector2.ZERO) -> Node2D:
	var node := Node2D.new()
	node.name = id.to_pascal_case()
	node.position = at
	if id == "reed_gate":
		node.scale = Vector2(1.5,1.5)
	_depth.add_child(node)
	var sprite := Sprite2D.new()
	sprite.texture = load(PACK + "atlases/" + id + ".tres")
	sprite.centered = false
	sprite.position = Vector2(-64,-124)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.add_child(sprite)
	if solid != Vector2.ZERO:
		_solid(node,Rect2(-solid.x/2,-solid.y,solid.x,solid.y))
	return node

func _facade(id: String, at: Vector2, width: float) -> void:
	var base := Node2D.new()
	base.name = id.to_pascal_case()
	base.position = at
	_depth.add_child(base)
	var walls := Sprite2D.new()
	walls.texture = load(PACK + "atlases/" + id + "_walls.tres")
	walls.centered = false
	walls.position = Vector2(-96,-188)
	base.add_child(walls)
	_solid(base,Rect2(-width/2,-48,width,48))
	var roof := Sprite2D.new()
	roof.name = id.to_pascal_case() + "Roof"
	roof.texture = load(PACK + "atlases/" + id + "_roof.tres")
	roof.centered = false
	roof.position = at + Vector2(-96,-264)
	_overhead.add_child(roof)

func _solid(parent: Node2D, rectangle: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	parent.add_child(body)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rectangle.size
	shape.shape = box
	shape.position = rectangle.get_center()
	body.add_child(shape)
	_obstacles.append(Rect2(parent.position+rectangle.position,rectangle.size))

func _actor(id: String, at: Vector2) -> Node2D:
	var node: Node2D = load(PACK + "scenes/" + id + ".tscn").instantiate()
	node.position = at
	_depth.add_child(node)
	var sprite: AnimatedSprite2D = node.get_node("Visual")
	if not Settings.data.reduce_motion:
		sprite.play(&"idle")
	return node

func _spawn(dimensions: Vector2i) -> void:
	_player = CharacterBody2D.new()
	_player.name = "PreviewHollow"
	_player.collision_layer = 4
	_player.collision_mask = 2
	_player.position = Vector2(32,33)*32 if _area == 0 else Vector2(58,27)*32
	if _focus_building and _area == 0:
		_player.position = Vector2(23,23.75)*32
	_depth.add_child(_player)
	var presentation: Node2D = load(PACK + "scenes/hollow.tscn").instantiate()
	_player.add_child(presentation)
	_visual = presentation.get_node("Visual")
	var shape := CollisionShape2D.new()
	var feet := RectangleShape2D.new()
	feet.size = Vector2(10,6)
	shape.shape = feet
	shape.position.y = -3
	_player.add_child(shape)
	_camera = Camera2D.new()
	_camera.name = "PreviewCamera"
	_camera.zoom = Vector2(2,2)
	_camera.offset = Vector2(0,-88)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = dimensions.x*32
	_camera.limit_bottom = dimensions.y*32
	_camera.position_smoothing_enabled = false
	_player.add_child(_camera)

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var move := Vector2.ZERO
	if not _sheet_view.visible and _capture.is_empty():
		move = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
	_player.velocity = move * 96.0
	_player.move_and_slide()
	_player.position = _player.position.clamp(Vector2(8,8),Vector2(_camera.limit_right-8,_camera.limit_bottom-8))
	if move != Vector2.ZERO and _player.get_real_velocity().length_squared() > 1.0:
		_direction = ("east" if move.x>0 else "west") if absf(move.x)>absf(move.y) else ("south" if move.y>0 else "north")
		_visual.play(StringName("walk_"+_direction))
	else:
		_visual.play(StringName("idle_"+_direction))
	_debug_layer.queue_redraw()

func _draw_footprints() -> void:
	if not _footprints or _player == null:
		return
	for rect in _obstacles:
		_debug_layer.draw_rect(rect,Color(0.95,0.55,0.3,0.9),false,1.0)
	_debug_layer.draw_rect(Rect2(_player.position+Vector2(-5,-6),Vector2(10,6)),Color(0.6,0.95,0.8),false,1.0)

func _ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	canvas.add_child(root)
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 16
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UITheme.label("First Footsteps · art workbench",UITheme.ACCENT,-1,true))
	_status = UITheme.label("",UITheme.TEXT,-1,true)
	column.add_child(_status)
	var row := HBoxContainer.new()
	column.add_child(row)
	for item in [["Gloamstead",func() -> void: _area=0;_build()],["Reedway",func() -> void: _area=1;_build()],
		["Before / After",func() -> void: _restored=not _restored;_build()],
		["Footprints",func() -> void: _footprints=not _footprints;_debug_layer.queue_redraw()],
		["Lighting",func() -> void: _lighting=not _lighting;_tint.color=Color(0.76,0.82,0.84) if _lighting else Color.WHITE],
		["Sheets",func() -> void: _sheet_view.visible=not _sheet_view.visible]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		row.add_child(button)
	var help := UITheme.label("Walk: WASD / arrows · Fixed camera zoom 2× · Preview controls only",UITheme.TEXT,-1,true)
	root.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_left=24
	help.offset_top=-44
	_sheet_view = PanelContainer.new()
	root.add_child(_sheet_view)
	_sheet_view.position=Vector2(24,180)
	_sheet_view.size=Vector2(1232,476)
	var sheets := HBoxContainer.new()
	_sheet_view.add_child(sheets)
	for pair in [["Hollow · four directions","hollow"],["Patrol · idle","fen_patrol"],["Guard · idle","rot_grove"],["Terrain · 32 px","terrain_32"]]:
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		sheets.add_child(stack)
		stack.add_child(UITheme.label(pair[0],UITheme.ACCENT,-1,true))
		var texture := TextureRect.new()
		texture.texture=load(PACK+"atlases/"+pair[1]+".png")
		texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		texture.custom_minimum_size=Vector2(280,380)
		stack.add_child(texture)
	_sheet_view.hide()

func _capture_frame() -> void:
	for i in 15:
		await get_tree().process_frame
	set_physics_process(false)
	if not _capture_walk.is_empty():
		_visual.play(StringName("walk_"+_capture_walk))
		await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_capture))
	print("Art workbench capture: "+_capture)
	AudioManager.request_music(&"")
	AudioManager.music._update_fade(AudioManager.music._fade_start+10000000)
	await get_tree().process_frame
	get_tree().quit()
