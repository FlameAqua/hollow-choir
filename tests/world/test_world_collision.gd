extends TestCase
## Authored prop footprints against the visible art, using the real feet body (third playtest).
## A prop's ground mask comes from its own sprites: the opaque pixels where it meets the ground
## (willow trunk and root flare, bell footings and roots, stones, the lamp plinth, gateposts).
## Hollow walks at each prop from sixteen directions. On the way in and at rest the feet box may
## touch at most a few edge pixels of that base, and an approach stopped by the prop itself ends
## within a few pixels of the art (no invisible wall). Canopy above the roots stays walk-behind.
## Collision is authored scene geometry; the art is only this test's reference.

const WILLOW_ART := "res://assets/art/world/first_footsteps_v01/atlases/willow.tres"
const WILLOW_ROOTS := "res://scenes/world/footprints/willow_roots.tres"
## Opaque base pixels a moving or resting feet box may touch (antialiased edges, single root tips).
const TOLERANCE := 8
## A prop that stops the feet leaves at most this gap to its visible base.
const REACH_GAP := 6.0
const START_DISTANCE := 76.0
## Trunk base of the willow art: the root flare is the component connected to this pixel.
const WILLOW_SEED := Vector2i(10, -12)
const WILLOW_CENTRE := Vector2(3, -13)

var tree: SceneTree
var area: WorldArea
var player: WorldPlayer
var _query := PhysicsShapeQueryParameters2D.new()
var _willow_mask := {}


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	var feet := RectangleShape2D.new()
	feet.size = WorldPlayer.FEET
	_query.shape = feet
	_query.collision_mask = 2


func after_each() -> void:
	if area != null:
		area.queue_free()
		area = null


## Opens an area scene on its own, in [param world]'s state, with a feet body to walk.
func _open(area_id: StringName, world: WorldState) -> void:
	var definition := WorldDefinition.load_default()
	area = (load(definition.area(area_id).scene_path) as PackedScene).instantiate() as WorldArea
	tree.root.add_child(area)
	area.apply_state(world)
	player = WorldPlayer.new()
	area.depth_layer().add_child(player)
	player.camera().enabled = false
	await tree.physics_frame
	await tree.physics_frame


static func _everything_open() -> WorldState:
	var world := WorldState.new()
	world.cleared.append_array([&"reedway_patrol", &"bell_guard"])
	world.wayside_bell_restored = true
	world.return_latch_open = true
	return world


func _willows() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for prop in area.depth_layer().get_children():
		var sprite := prop.get_node_or_null("Sprite") as Sprite2D
		if sprite != null and sprite.texture != null and sprite.texture.resource_path == WILLOW_ART:
			result.append(prop as Node2D)
	return result


## Opaque pixels of [param prop]'s visible sprites in prop-local integers, rows [param top]..-1,
## inside [param bounds] (prop-local) when given. With [param seed], only the 4-connected component
## containing it: hanging canopy strands are not ground.
func _ground(prop: Node2D, top: int, bounds: Array[Rect2i] = [], seed := Vector2i(0, 1)) -> Dictionary:
	var mask := {}
	for node in prop.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if not sprite.is_visible_in_tree() or sprite.texture == null:
			continue
		var image := sprite.texture.get_image()
		if image.is_compressed():
			image.decompress()
		var to_prop := prop.global_transform.affine_inverse() * sprite.global_transform
		var origin := sprite.offset - (sprite.texture.get_size() * 0.5 if sprite.centered else Vector2.ZERO)
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a <= 0.5:
					continue
				var at := to_prop * (origin + Vector2(x + 0.5, y + 0.5))
				var key := Vector2i(floori(at.x), floori(at.y))
				if key.y < top or key.y >= 0:
					continue
				if bounds.is_empty() or bounds.any(func(rect: Rect2i) -> bool: return rect.has_point(key)):
					mask[key] = true
	if seed.y > 0:
		return mask
	var component := {}
	var stack: Array[Vector2i] = [seed]
	while not stack.is_empty():
		var key: Vector2i = stack.pop_back()
		if component.has(key) or not mask.has(key):
			continue
		component[key] = true
		stack.append_array([key + Vector2i.LEFT, key + Vector2i.RIGHT, key + Vector2i.UP, key + Vector2i.DOWN])
	return component


## Mask pixels whose centres lie inside the feet box standing at [param feet] (prop-local).
static func _overlap(mask: Dictionary, feet: Vector2) -> int:
	var count := 0
	var half := WorldPlayer.FEET.x * 0.5
	for y in range(floori(feet.y - WorldPlayer.FEET.y), ceili(feet.y)):
		for x in range(floori(feet.x - half), ceili(feet.x + half)):
			if mask.has(Vector2i(x, y)) and absf(x + 0.5 - feet.x) < half and y + 0.5 > feet.y - WorldPlayer.FEET.y \
					and y + 0.5 < feet.y:
				count += 1
	return count


## Distance from the feet box at [param feet] to the nearest mask pixel.
static func _gap(mask: Dictionary, feet: Vector2) -> float:
	var box := Rect2(feet - Vector2(WorldPlayer.FEET.x * 0.5, WorldPlayer.FEET.y), WorldPlayer.FEET)
	var best := INF
	for key: Vector2i in mask:
		var dx := maxf(0.0, maxf(key.x - box.end.x, box.position.x - (key.x + 1)))
		var dy := maxf(0.0, maxf(key.y - box.end.y, box.position.y - (key.y + 1)))
		best = minf(best, Vector2(dx, dy).length())
	return best


func _free(feet: Vector2) -> bool:
	_query.transform = Transform2D(0, feet + Vector2(0, -WorldPlayer.FEET.y * 0.5))
	return area.get_world_2d().direct_space_state.intersect_shape(_query, 1).is_empty()


## Walks the feet at [param centre] (prop-local) from sixteen directions, starting wherever that
## start is free. Asserts the base is never entered; an approach stopped by [param blocker] (the
## prop's own shape) must end next to the art. Returns {reached, north_rest}.
func _sweep(prop: Node2D, mask: Dictionary, centre: Vector2, blocker: Node, label: String) -> Dictionary:
	var reached := 0
	var north_rest := Vector2.INF
	for index in 16:
		var start := centre + Vector2.RIGHT.rotated(TAU * index / 16.0) * START_DISTANCE
		if not _free(prop.position + start):
			continue
		player.place(prop.position + start)
		var worst := 0
		var still := 0
		for frame in 240:
			var before := player.position
			worst = maxi(worst, _overlap(mask, player.position - prop.position))
			var to := prop.position + centre - player.position
			if to.length() < 1.0:
				break
			player.step(to.normalized(), 1.0 / 60.0)
			still = still + 1 if player.position.distance_to(before) < 0.05 else 0
			if still > 8:
				break
		var rest := player.position - prop.position
		worst = maxi(worst, _overlap(mask, rest))
		var degrees := index * 22.5
		assert_lte(worst, TOLERANCE, "%s: feet entered the visible base approaching from %.1f° (%d px, rest %s)" % [
			label, degrees, worst, rest])
		var hit := player.get_last_slide_collision()
		if hit != null and hit.get_collider_shape() == blocker:
			reached += 1
			assert_lte(_gap(mask, rest), REACH_GAP, "%s: stopped short of the art approaching from %.1f° (rest %s)" % [
				label, degrees, rest])
		if index == 12:
			north_rest = rest
	return {"reached": reached, "north_rest": north_rest}


func test_every_willow_uses_the_shared_root_footprint() -> void:
	var roots := load(WILLOW_ROOTS) as ConvexPolygonShape2D
	assert_not_null(roots)
	var counts := {}
	for area_id: StringName in [&"gloamstead", &"briarfen_reedway"]:
		await _open(area_id, WorldState.new())
		var willows := _willows()
		counts[area_id] = willows.size()
		for willow in willows:
			var body := willow.get_node_or_null("Footprint") as StaticBody2D
			var shape := willow.get_node_or_null("Footprint/Shape") as CollisionShape2D
			assert_true(body != null and shape != null, "%s/%s has a ground footprint" % [area_id, willow.name])
			if shape == null:
				continue
			assert_eq(shape.shape, roots, "%s/%s uses the shared root polygon" % [area_id, willow.name])
			assert_eq(shape.position, Vector2.ZERO)
			assert_eq(body.collision_layer, 2)
			assert_false(shape.disabled)
		area.free()
		area = null
	assert_eq(counts, {&"gloamstead": 6, &"briarfen_reedway": 15}, "every willow in both areas")


func test_willow_roots_stop_the_feet_from_every_side_in_both_areas() -> void:
	for area_id: StringName in [&"gloamstead", &"briarfen_reedway"]:
		await _open(area_id, _everything_open())
		for willow in _willows():
			if _willow_mask.is_empty():
				_willow_mask = _ground(willow, -26, [], WILLOW_SEED)
				assert_gt(_willow_mask.size(), 1200, "the willow root flare is read from the art")
			var result := _sweep(willow, _willow_mask, WILLOW_CENTRE, willow.get_node("Footprint/Shape"), "%s/%s" % [area_id, willow.name])
			if area_id == &"gloamstead":
				assert_gte(result.reached, 12, "%s: open-ground willow is reached from most sides" % willow.name)
		area.free()
		area = null


func test_willow_canopy_stays_walk_behind() -> void:
	await _open(&"gloamstead", WorldState.new())
	assert_true(area.depth_layer().y_sort_enabled, "props and Hollow share the Y-sorted layer")
	for willow in _willows():
		_willow_mask = _willow_mask if not _willow_mask.is_empty() else _ground(willow, -26, [], WILLOW_SEED)
		# Under the hanging canopy, beside and behind the trunk, is open ground.
		for spot: Vector2 in [Vector2(-50, -40), Vector2(52, -36), Vector2(-40, -80), Vector2(44, -84), Vector2(3, -60)]:
			assert_true(_free(willow.position + spot), "%s: canopy ground at %s stays walkable" % [willow.name, spot])
		var result := _sweep(willow, _willow_mask, WILLOW_CENTRE, willow.get_node("Footprint/Shape"), "behind " + willow.name)
		var rest: Vector2 = result.north_rest
		assert_true(rest != Vector2.INF, "%s: approached from behind" % willow.name)
		assert_lt(rest.y, -24.0, "%s: from behind, the feet stop at the back of the roots" % willow.name)
		assert_gt(rest.y, -30.0, "%s: ... right behind the trunk, not held off by the canopy" % willow.name)


func test_bells_stones_lamp_and_gateposts_match_their_visible_bases() -> void:
	await _open(&"gloamstead", WorldState.new())
	var bell := area.depth_layer().get_node("TownBell") as Node2D
	_sweep(bell, _ground(bell, -24, [Rect2i(-38, -24, 77, 24)]), Vector2(0, -12), bell.get_node("Footprint/Shape"), "town bell footings")
	var lamp := area.depth_layer().get_node("SquareLamp") as Node2D
	var plinth := _ground(lamp, -14)
	assert_gt(plinth.size(), 150)
	var lamp_result := _sweep(lamp, plinth, Vector2(-9.5, -7.5), lamp.get_node("Footprint/Shape"), "square lamp plinth")
	assert_gte(lamp_result.reached, 14, "the plinth is reached from every open side")
	assert_true(_free(lamp.position + Vector2(10, -4)), "the space under the hanging lantern is walkable")
	var bench := area.depth_layer().get_node("PreparationBench") as Node2D
	_sweep(bench, _ground(bench, -18), Vector2(0, -9), bench.get_node("Footprint/Shape"), "preparation bench")
	area.free()
	area = null
	await _open(&"briarfen_reedway", _everything_open())
	var wayside := area.depth_layer().get_node("WaysideBell") as Node2D
	var roots := _ground(wayside, -24)
	assert_true(roots.has(Vector2i(-45, -17)), "the wayside bell's left roots are part of its base")
	_sweep(wayside, roots, Vector2(0, -12), wayside.get_node("Footprint/Shape"), "wayside bell roots")
	var stones := area.depth_layer().get_node("ListeningStones") as Node2D
	var stone_base := _ground(stones, -16)
	assert_true(stone_base.has(Vector2i(-33, -12)) and stone_base.has(Vector2i(30, -10)), "outer stones are part of the base")
	var stone_result := _sweep(stones, stone_base, Vector2(0, -8), stones.get_node("Footprint/Shape"), "listening stones")
	assert_gte(stone_result.reached, 10)
	var latch := area.depth_layer().get_node("ReturnLatch") as Node2D
	var left := _ground(latch, -20, [Rect2i(-28, -20, 17, 12)])
	var right := _ground(latch, -12, [Rect2i(13, -12, 15, 8)])
	assert_gt(left.size(), 80)
	assert_gt(right.size(), 60)
	_sweep(latch, left, Vector2(-20, -14.5), latch.get_node("Posts/LeftPost"), "open latch, west gatepost")
	_sweep(latch, right, Vector2(19.5, -7), latch.get_node("Posts/RightPost"), "open latch, east gatepost")


func test_open_gateposts_keep_the_short_return_passable() -> void:
	await _open(&"briarfen_reedway", _everything_open())
	var latch := area.depth_layer().get_node("ReturnLatch") as Node2D
	player.place(latch.position + Vector2(0, -72), &"south")
	for frame in 120:
		player.step(Vector2.DOWN, 1.0 / 60.0)
	assert_gt(player.position.y, latch.position.y + 40.0, "the boards between the open gateposts stay walkable")
	assert_almost_eq(player.position.x, latch.position.x, 0.5, "without sliding off the line between the posts")
	area.free()
	area = null
	await _open(&"briarfen_reedway", WorldState.new())
	latch = area.depth_layer().get_node("ReturnLatch") as Node2D
	player.place(latch.position + Vector2(0, -72), &"south")
	for frame in 120:
		player.step(Vector2.DOWN, 1.0 / 60.0)
	assert_lt(player.position.y, latch.position.y - 30.0, "the closed gate still bars the short return")


func test_every_safe_anchor_stands_clear_of_all_solids() -> void:
	for area_id: StringName in [&"gloamstead", &"briarfen_reedway"]:
		for world: WorldState in [WorldState.new(), _everything_open()]:
			await _open(area_id, world)
			for anchor in area.get_node("Anchors").get_children():
				assert_true(_free((anchor as Node2D).position), "%s/%s: Hollow fits at the anchor" % [area_id, anchor.name])
			area.free()
			area = null
