extends SceneTree
## Read-only evidence for the engineering collision pass. No area scene is modified.
## Option: --out=res://… (JSON). Defaults to the third-pass folder, so the second-pass evidence in
## v0_4_material_polish stays as recorded.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var area: Node2D = load("res://scenes/world/areas/gloamstead.tscn").instantiate()
	root.add_child(area)
	await physics_frame
	await physics_frame
	var tree := area.get_node("DepthSorted/Willow8_46") as Node2D
	var sprite := tree.get_node("Sprite") as Sprite2D
	var footprint := tree.get_node("Footprint/Shape") as CollisionShape2D
	var image := sprite.texture.get_image()
	var result := {"node": String(tree.get_path()), "position": tree.position, "sprite_offset": sprite.position, "footprint_position": footprint.position, "footprint_size": (footprint.shape as RectangleShape2D).size if footprint.shape is RectangleShape2D else null, "footprint_polygon": (footprint.shape as ConvexPolygonShape2D).points if footprint.shape is ConvexPolygonShape2D else null, "art_spans": [], "feet_queries": []}
	for y in [100, 108, 116, 120, 123]:
		var left := image.get_width()
		var right := -1
		for x in image.get_width():
			if image.get_pixel(x, y).a > .5:
				left = mini(left, x)
				right = maxi(right, x)
		result.art_spans.append({"local_y": y + sprite.position.y, "left": left + sprite.position.x, "right": right + sprite.position.x})
	var feet := RectangleShape2D.new()
	feet.size = Vector2(16, 9)
	for local in [Vector2(0, -6), Vector2(34, -6), Vector2(40, -6), Vector2(44, -12), Vector2(-40, -6)]:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = feet
		query.transform = Transform2D(0, tree.global_position + local + Vector2(0, -4.5))
		query.collision_mask = 2
		var hits := area.get_world_2d().direct_space_state.intersect_shape(query)
		var willow_hit := false
		for hit in hits:
			if tree.is_ancestor_of(hit.collider):
				willow_hit = true
		result.feet_queries.append({"feet_local": local, "willow_collision": willow_hit})
	var out := "res://docs/reports/v0_4_playtest_engineering/willow_footprint_probe.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result, "\t"))
	area.queue_free()
	await process_frame
	quit()
