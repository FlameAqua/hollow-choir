extends TestCase
## V0.4 pure rules: derived objectives, knowledge-filtered encounter cards and maps, latch sides,
## four-facing stability, bindings and the authored scene contract (IDs, anchors, triggers).

var kit: WorldKit


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()


func after_each() -> void:
	kit.restore()


func test_objective_derives_from_guard_and_bell_state() -> void:
	var definition := WorldDefinition.load_default()
	var world := WorldState.fresh(definition)
	assert_eq(WorldRules.objective(world, definition, &"gloamstead"), WorldCopy.OBJECTIVE_FIND)
	world.cleared.append(&"reedway_patrol")
	assert_eq(WorldRules.objective(world, definition, &"briarfen_reedway"), WorldCopy.OBJECTIVE_FIND, "the optional patrol changes nothing")
	world.cleared.append(&"bell_guard")
	assert_eq(WorldRules.objective(world, definition, &"briarfen_reedway"), WorldCopy.OBJECTIVE_RESTORE)
	world.wayside_bell_restored = true
	assert_eq(WorldRules.objective(world, definition, &"briarfen_reedway"), WorldCopy.OBJECTIVE_RETURN)
	assert_eq(WorldRules.objective(world, definition, &"gloamstead"), WorldCopy.OBJECTIVE_DONE)


func test_encounter_card_hides_unknown_species() -> void:
	var site := WorldKit.site(&"reedway_patrol")
	var card := WorldRules.encounter_card(site, GameState.progress)
	assert_eq(card.threat, "Patrol")
	assert_eq(card.group_count, 3)
	assert_eq(card.creatures, PackedStringArray([WorldCopy.UNKNOWN_CREATURE, WorldCopy.UNKNOWN_CREATURE, WorldCopy.UNKNOWN_CREATURE]))
	assert_eq(card.conditions.size(), 1, "authored battlefield condition is public")
	assert_eq(card.resource_rule, WorldCopy.RESOURCE_RULE)
	var text := card.plain_text()
	for enemy in site.encounter.enemies:
		assert_false(text.contains(enemy.display_name), "%s leaked before it is known" % enemy.display_name)
	for word in ["fen_patrol", "Fen Patrol", "weak", "resist", "Slash", "Pierce"]:
		assert_false(text.contains(word), "card leaks '%s'" % word)
	GameState.progress.bestiary.add(&"thornhound", Enums.ResearchSource.ENCOUNTER, 100)
	card = WorldRules.encounter_card(site, GameState.progress)
	assert_true(card.creatures.has("Thornhound"), "known species are named")
	assert_eq(card.creatures.count(WorldCopy.UNKNOWN_CREATURE), 2)


func test_map_shows_only_discovered_landmarks_and_walked_links() -> void:
	var definition := WorldDefinition.load_default()
	var area := definition.area(&"briarfen_reedway")
	var world := WorldState.fresh(definition)
	var readout := WorldRules.map_readout(area, world, 32, Vector2(100, 100), {})
	assert_empty(readout.landmarks, "nothing known yet")
	assert_empty(readout.links)
	world.discover(&"reedway_entry")
	world.discover(&"reedway_patrol")
	world.add_link(&"entry_fork")
	world.add_link(&"short_return")
	readout = WorldRules.map_readout(area, world, 32, Vector2(100, 100), {})
	var labels := readout.landmarks.map(func(entry: Dictionary) -> String: return entry.label)
	assert_eq(labels, ["Gloamstead gate", "Patrol"])
	assert_eq(readout.links.size(), 1, "a gated link stays undrawn until its flag is set")
	world.return_latch_open = true
	assert_eq(WorldRules.map_readout(area, world, 32, Vector2.ZERO, {}).links.size(), 2)
	for entry in readout.landmarks:
		for word in ["fen_patrol", "Fen Patrol", "Bogshell", "Thornhound", "Fen Wisp", "rot_grove"]:
			assert_false(String(entry.label + entry.description).contains(word), "map leaks '%s'" % word)


func test_latch_side_and_copy() -> void:
	var latch := WorldDefinition.load_default().area(&"briarfen_reedway").landmark(&"return_latch")
	var world := WorldState.fresh(WorldDefinition.load_default())
	var at := Vector2(100, 100)
	assert_true(WorldRules.on_far_side(latch, at, at + Vector2(0, -20)), "north is the far side")
	assert_false(WorldRules.on_far_side(latch, at, at + Vector2(0, 20)))
	var near := WorldRules.dialogue(latch, world, false)
	assert_eq(Array(near.paragraphs), [WorldCopy.LATCH_NEAR])
	assert_false(near.actions.any(func(action: Dictionary) -> bool: return action.id == WorldRules.ACT_OPEN_LATCH))
	var far := WorldRules.dialogue(latch, world, true)
	assert_true(far.actions.any(func(action: Dictionary) -> bool: return action.id == WorldRules.ACT_OPEN_LATCH))
	world.return_latch_open = true
	assert_eq(WorldRules.interaction_label(latch, world, true), "", "an open latch offers nothing")


func test_wayside_bell_copy_follows_state() -> void:
	var bell := WorldDefinition.load_default().area(&"briarfen_reedway").landmark(&"wayside_bell")
	var world := WorldState.fresh(WorldDefinition.load_default())
	var guarded := WorldRules.dialogue(bell, world, false)
	assert_eq(Array(guarded.paragraphs), [WorldCopy.BELL_GUARDED])
	assert_eq(guarded.actions.size(), 1, "only Leave while guarded")
	world.cleared.append(&"bell_guard")
	var ready := WorldRules.dialogue(bell, world, false)
	assert_eq(ready.actions[0].id, WorldRules.ACT_RING)
	world.wayside_bell_restored = true
	assert_eq(Array(WorldRules.dialogue(bell, world, false).paragraphs), [WorldCopy.BELL_RESTORED])


func test_eight_facing_choice_never_alternates_on_diagonals() -> void:
	assert_eq(WorldPlayer.facing_for(Vector2.RIGHT, &"south"), &"east")
	assert_eq(WorldPlayer.facing_for(Vector2.UP, &"east"), &"north")
	var diagonal := Vector2(1, 1).normalized()
	assert_eq(WorldPlayer.facing_for(diagonal, &"south"), &"southeast", "diagonals have authored art")
	assert_eq(WorldPlayer.facing_for(diagonal, &"east"), &"southeast")
	assert_eq(WorldPlayer.facing_for(diagonal, &"north"), &"southeast")
	var facing := &"west"
	for frame in 10:
		facing = WorldPlayer.facing_for(Vector2(-0.70, -0.71), facing)
	assert_eq(facing, &"northwest", "stable over frames")


func test_world_actions_are_separate_and_rebindable() -> void:
	InputBindings.install()
	for action in InputBindings.WORLD_ACTIONS:
		assert_true(InputMap.has_action(action))
		assert_true(InputBindings.DISPLAY_NAMES.has(action), "listed on the Controls page")
	assert_eq(InputBindings.codes_for(InputBindings.BRACE), PackedStringArray(["key:A", "joy:9"]), "combat bindings unchanged")
	assert_true(InputBindings.codes_for(InputBindings.WORLD_LEFT).has("axis:0:-1"), "left stick default")
	assert_true(InputBindings.codes_for(InputBindings.WORLD_MAP).has("joy:4"), "gamepad Back opens the map")
	InputBindings.install({InputBindings.WORLD_INTERACT: ["key:F"]})
	assert_eq(InputBindings.codes_for(InputBindings.WORLD_INTERACT), PackedStringArray(["key:F"]))
	assert_eq(InputBindings.codes_for(InputBindings.CONFIRM), PackedStringArray(["key:Enter", "joy:0"]), "remapping world input leaves combat alone")
	InputBindings.install()
	assert_eq(InputBindings.code_label("axis:1:-1"), "Pad L-Stick Up")


func test_area_scenes_match_the_definition() -> void:
	var definition := WorldDefinition.load_default()
	for area_def in definition.areas:
		var area := (load(area_def.scene_path) as PackedScene).instantiate() as WorldArea
		assert_eq(area.area_id, area_def.id)
		for layer in ["Ground", "GroundDetail", "LowDecoration", "DepthSorted", "Overhead", "WorldLighting", "WorldEffects",
				"Collision", "Interactions", "Anchors", "Portals"]:
			assert_true(area.has_node(layer), "%s has layer %s" % [area_def.id, layer])
		assert_true(area.get_node("Ground") is TileMapLayer and area.get_node("Collision") is TileMapLayer)
		assert_true((area.get_node("DepthSorted") as Node2D).y_sort_enabled)
		for landmark in area_def.landmarks:
			assert_true(area.has_point(landmark.id), "%s has a point for %s" % [area_def.id, landmark.id])
		for anchor in area_def.anchors():
			assert_true(area.has_anchor(anchor), "%s has anchor %s" % [area_def.id, anchor])
			assert_eq(area.portal_at(area.anchor(anchor)), &"", "anchor %s lies outside every trigger" % anchor)
			for site in area_def.landmarks:
				if site.kind == LandmarkDefinition.Kind.ENCOUNTER:
					assert_gt(area.anchor(anchor).distance_to(area.point(site.id)), site.interact_radius + 8.0,
						"anchor %s does not respawn inside %s" % [anchor, site.id])
			var own := area_def.landmark(anchor)
			if own != null and own.interact_radius > 0.0 and own.kind != LandmarkDefinition.Kind.ENCOUNTER:
				assert_lte(area.anchor(anchor).distance_to(area.point(anchor)), own.interact_radius,
					"resuming at %s keeps it within reach" % anchor)
			var cell := (area.anchor(anchor) / definition.tile_size).floor()
			assert_eq(area.collision_layer_node().get_cell_source_id(Vector2i(cell)), -1, "anchor %s is not inside a wall" % anchor)
		for portal in area.portals():
			assert_not_null(definition.portal_from(area_def.id, StringName(portal.name)), "trigger %s is paired" % portal.name)
		var size := area_def.size_tiles
		for x in size.x:
			for y in [0, size.y - 1]:
				assert_ne(area.collision_layer_node().get_cell_source_id(Vector2i(x, y)), -1, "closed boundary")
		area.free()


func test_analog_noise_at_a_sector_edge_keeps_one_facing() -> void:
	# A controller stick held near 22.5 degrees (between east and southeast) with a little noise.
	var facing := &"east"
	var changes := 0
	for frame in 60:
		var next := WorldPlayer.facing_for(Vector2.from_angle(deg_to_rad(22.5 + (2.0 if frame % 2 == 0 else -2.0))), facing)
		changes += int(next != facing)
		facing = next
	assert_eq(changes, 0, "noise around a sector edge never flips the art")
	assert_eq(WorldPlayer.facing_for(Vector2.from_angle(deg_to_rad(40.0)), &"east"), &"southeast", "a deliberate turn still turns")
	for turn: Array in [[Vector2(1, 1), &"east", &"southeast"], [Vector2(1, 0), &"southeast", &"east"],
			[Vector2(0, -1), &"northwest", &"north"], [Vector2(-1, -1), &"north", &"northwest"]]:
		assert_eq(WorldPlayer.facing_for((turn[0] as Vector2).normalized(), turn[1]), turn[2], "keyboard directions always turn")
