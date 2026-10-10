extends SceneTree
## Checks actual exported resource bounds, transparency, source hashes and presentation animation.
const ROOT := "res://assets/art/world/first_footsteps_v01/"
## The Hollow's accepted runtime export (tools/prepare_fifth_polish.gd). A polish pass that re-exports
## its frames and re-points scenes/hollow.tscn bumps this with the scene.
const HOLLOW_FRAMES := "hollow_motion_v05"
var _failures := 0
var _checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)

func _run() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/first_footsteps_v01/regions.json"))
	for filename in spec.sources:
		_check(FileAccess.get_sha256(ROOT+"sources/"+filename) == spec.sources[filename].sha256,"Source changed: "+filename)
	for actor in spec.actors:
		var frames: SpriteFrames = load(ROOT+"frames/"+actor.id+".tres")
		_check(frames != null,"Missing frames: "+actor.id)
		for row in actor.rows:
			var animation := StringName(row.name)
			_check(frames.get_frame_count(animation) == row.frames.size(),"Frame count: "+actor.id+"/"+row.name)
			for i in frames.get_frame_count(animation):
				var texture := frames.get_frame_texture(animation,i) as AtlasTexture
				_check(texture != null and texture.filter_clip,"Clipped atlas: "+actor.id)
				_check(Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region),"Out-of-bounds region: "+actor.id)
				var image := texture.get_image()
				_check(image.get_size() == Vector2i(actor.cell[0],actor.cell[1]),"Wrong native cell: "+actor.id)
				_check(image.get_pixel(0,0).a < 0.01,"Opaque cell corner: "+actor.id)
				var lowest := -1
				for y in image.get_height():
					for x in image.get_width():
						if image.get_pixel(x,y).a > 0.5:
							lowest = maxi(lowest,y)
				_check(abs(lowest-actor.foot[1]) <= 2,"Foot baseline drift: "+actor.id+"/"+row.name)
			if actor.get("directional",false):
				_check(frames.has_animation(StringName(row.name.replace("walk_","idle_"))),"Missing idle direction")
		var scene: Node2D = load(ROOT+"scenes/"+actor.id+".tscn").instantiate()
		root.add_child(scene)
		var sprite: AnimatedSprite2D = scene.get_node("Visual")
		var runtime_frames := HOLLOW_FRAMES if actor.id == "hollow" else String(actor.id)
		_check(sprite.sprite_frames.resource_path == ROOT+"frames/"+runtime_frames+".tres","Scene embeds stale frames: "+actor.id)
		sprite.play(StringName(actor.rows[0].name))
		await create_timer(1.1/sprite.sprite_frames.get_animation_speed(StringName(actor.rows[0].name))).timeout
		_check(sprite.frame > 0,"Animation did not advance: "+actor.id)
		scene.queue_free()
		await process_frame
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	for id in manifest.assets:
		var entry: Dictionary = manifest.assets[id]
		if entry.has("texture"):
			_check(load(entry.texture) is AtlasTexture,"Missing prop: "+id)
	var tiles: TileSet = load(ROOT+"terrain.tres")
	var source := tiles.get_source(0) as TileSetAtlasSource
	_check(tiles.tile_size == Vector2i(32,32),"Wrong terrain grid")
	_check(source.get_tiles_count() == 14,"Rejected bank corners entered TileSet")
	for png in ["hollow","hollow_motion_v02","fen_patrol","rot_grove","bellkeeper","terrain_32","props","buildings"]:
		var settings := ConfigFile.new()
		_check(settings.load(ROOT+"atlases/"+png+".png.import") == OK,"Missing import: "+png)
		_check(settings.get_value("params","compress/mode") == 0 and not settings.get_value("params","mipmaps/generate"),"Lossy or mipmapped art: "+png)
	_verify_motion()
	await _verify_fixture()
	print("World art validation: %d checks, %d failures." % [_checks,_failures])
	quit(1 if _failures else 0)

func _verify_motion() -> void:
	# The frames the scene actually shows; the stale-frames check above pins which export that is.
	var scene: Node2D = load(ROOT+"scenes/hollow.tscn").instantiate()
	var sprite: AnimatedSprite2D = scene.get_node("Visual")
	var frames := sprite.sprite_frames
	scene.free()
	_check(frames.get_animation_names().size() == 16, "Eight walk and idle directions")
	for direction in ["north", "south", "west", "east", "northwest", "northeast", "southwest", "southeast"]:
		var walk := StringName("walk_"+direction)
		var idle := StringName("idle_"+direction)
		_check(frames.get_frame_count(walk) == 4, "Motion cycle: "+direction)
		_check(frames.get_frame_count(idle) == 2, "Standing idle pair: "+direction)
		_check(frames.get_animation_speed(walk) == 5, "Slower walk: "+direction)
		for i in frames.get_frame_count(walk):
			_verify_cell(frames.get_frame_texture(walk, i), "Motion", direction)
		for i in frames.get_frame_count(idle):
			_verify_cell(frames.get_frame_texture(idle, i), "Standing idle", direction)

func _verify_cell(texture: Texture2D, kind: String, direction: String) -> void:
	var image := texture.get_image()
	_check(image.get_size() == Vector2i(64,64), kind+" cell size")
	_check(image.get_pixel(0,0).a < .01, kind+" transparency")
	var lowest := -1
	for y in 64:
		for x in 64:
			if image.get_pixel(x,y).a > .5:
				lowest = maxi(lowest,y)
	_check(abs(lowest-60) <= 2, kind+" foot pivot: "+direction)

func _verify_fixture() -> void:
	var fixture: Node2D = load("res://scenes/prototypes/v04_art_workbench.tscn").instantiate()
	root.add_child(fixture)
	await physics_frame
	await physics_frame
	var start: Vector2 = fixture._player.position
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	for i in 18:
		await physics_frame
	_check(fixture._player.position.x > start.x+10,"Preview character did not walk")
	_check(fixture._visual.animation == &"walk_east","Preview movement did not select east animation")
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	await physics_frame
	await physics_frame
	_check(fixture._visual.animation == &"idle_east","Preview did not retain idle facing")
	# Put the feet immediately against the fixture bell, then hold north into it.
	fixture._player.position = Vector2(32,30)*32+Vector2(0,7)
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	for i in 12:
		await physics_frame
	_check(fixture._player.position.y >= 32.0*30+5.5,"Feet passed through bell footprint")
	_check(String(fixture._visual.animation).begins_with("idle_"),"Walking animation continued into wall")
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	fixture._sheet_view.show()
	start = fixture._player.position
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	for i in 4:
		await physics_frame
	_check(fixture._player.position.is_equal_approx(start),"Sheet modal did not stop preview movement")
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	fixture.queue_free()
	await process_frame
