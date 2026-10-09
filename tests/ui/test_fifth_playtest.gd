extends TestCase
var tree: SceneTree
var old_theme: Theme
var old_resolution: Vector2i

func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	old_theme = tree.root.theme
	old_resolution = Settings.data.window_resolution
	tree.root.theme = UITheme.build()

func after_each() -> void:
	Input.action_release(InputBindings.INFO)
	Engine.time_scale = 1
	Settings.data.window_resolution = old_resolution
	Settings.apply()
	tree.root.theme = old_theme
	AudioManager.silence()

func _battle(loadout: StringName = &"starter_sword") -> BattleScene:
	var fixture: TestCase = load("res://tests/ui/test_v02_ui.gd").new()
	fixture._tree = tree
	return await fixture._battle(loadout)

func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = tree.root.get_final_transform() * point
	event.relative = Vector2(2, 0)
	tree.root.push_input(event, false)
	await _frames(8)

func _right(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = tree.root.get_final_transform() * point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	tree.root.push_input(event, false)
	event.pressed = false
	tree.root.push_input(event, false)
	await _frames(4)

func _capture(name: String) -> void:
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--evidence"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://docs/reports/v0_4_fifth_polish")
		tree.root.get_texture().get_image().save_png("res://docs/reports/v0_4_fifth_polish/" + name + ".png")

func test_right_click_pins_and_fields_explain_without_replacing_the_card() -> void:
	Settings.data.window_resolution = Vector2i(2560, 1440)
	Settings.apply()
	var scene := await _battle()
	var source := scene._menu._buttons[0]
	await _move(source.get_global_rect().get_center())
	await _right(source.get_global_rect().get_center())
	var inspector := scene._inspector
	assert_true(inspector.pinned, "right click pins through the scaled window")
	var payload := inspector._payload
	var shown := inspector.shown_text()
	var request := scene.engine.get_request()
	var focus := scene._picker.acting_unit().focus
	var enemy := scene.engine.get_state().enemies()[0]
	await _move(scene._battlefield.body_point(enemy.uid))
	assert_eq(inspector.shown_text(), shown, "hovering a unit preserves the pinned action")
	assert_eq(inspector._payload, payload)
	assert_eq(scene.engine.get_request(), request, "right click never submits an action")
	assert_eq(scene._picker.acting_unit().focus, focus)
	assert_true(inspector._hint.text.contains("Pinned"))
	var region: Rect2 = inspector._card._regions[0].rect
	await _move(inspector._card._summary.get_global_transform_with_canvas() * region.get_center())
	assert_true(inspector._field_help.visible, "hovering Focus opens only a field explanation")
	assert_true(inspector._field_text.text.contains("Focus"))
	assert_eq(inspector._payload, payload)
	assert_eq(inspector.shown_text(), shown)
	assert_lt(inspector._field_help.get_global_rect().end.x, inspector.get_global_rect().position.x, "explanation sits to the left")
	assert_lte(inspector._field_help.get_global_rect().end.y, 720.0)
	await _capture("pinned-action-field")
	await _right(scene._battlefield.body_point(enemy.uid))
	await _frames(8)
	assert_false(inspector.pinned, "a second right click releases the pin")
	assert_true(inspector._payload is UnitReadout, "current hover resumes immediately")
	await _right(scene._battlefield.body_point(enemy.uid))
	assert_true(inspector.pinned)
	var resources := inspector._unit_card.get_child(1)
	var health := resources.get_child(0) as Control
	await _move(health.get_global_rect().get_center())
	assert_true(inspector._field_help.visible)
	assert_true(inspector._field_text.text.contains("Remaining health"))
	assert_true(inspector._payload is UnitReadout)
	await _capture("pinned-unit-field")
	scene._open_pause()
	await _frames(3)
	assert_false(inspector.pinned, "modal boundaries release the old inspection")
	assert_false(inspector._field_help.is_visible_in_tree())
	scene.queue_free()
	await _frames(3)

func test_eight_actions_fit_without_scrolling_and_inspection_has_even_insets() -> void:
	var scene := await _battle(&"starter_hammer")
	if scene._picker.acting_unit().definition.id != &"hollow":
		Engine.time_scale = 20
		for button in scene._menu._buttons:
			if (button.get_meta(&"option") as ActionOption).action.id == &"guard":
				button.pressed.emit()
				break
		var deadline := Time.get_ticks_msec() + 6000
		while (not scene._picker.is_active() or scene._picker.acting_unit().definition.id != &"hollow") and Time.get_ticks_msec() < deadline:
			await tree.process_frame
		Engine.time_scale = 1
		await _frames(6)
	# Current weapons supply seven actions. Add the real Guard action in this in-memory fixture
	# to exercise the proposed eighth slot without creating a new shipped ability or save.
	var actor := scene._picker.acting_unit()
	actor.actions.append(Database.registry.actions[&"guard"])
	scene._menu.show_options(actor, scene.engine.options_for(actor.uid), scene.engine)
	await _frames(6)
	assert_eq(scene._menu._list.columns, 2)
	assert_true(scene._menu.find_children("*", "ScrollContainer", true, false).is_empty())
	assert_eq(scene._menu._list.get_child_count(), 8, "eight real ActionOptions fit the proposed capacity")
	assert_true(scene._menu.find_children("*", "Label", true, false).all(func(label: Label) -> bool: return label.text != "THE HOLLOW"))
	for button: Control in scene._menu._list.get_children():
		assert_true(scene._menu.get_global_rect().encloses(button.get_global_rect()), "every action fits in the dock")
	await _move(scene._menu._buttons[0].get_global_rect().get_center())
	var inspector := scene._inspector
	var style := inspector.get_theme_stylebox("panel")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(style.get_content_margin(side), 14.0)
	assert_eq(inspector._content.body.position, Vector2.ONE * 6)
	assert_eq(inspector._content.size.x - inspector._content.body.size.x * InspectionContent.CONTENT_SCALE, 12.0)
	assert_gte(inspector.get_global_rect().end.y - inspector._hint.get_global_rect().end.y, 19.0, "footer clears the frame artwork")
	assert_eq(scene._log_button.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(scene._pause_button.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	for button: Button in scene._ribbon.get_children():
		assert_eq(button.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	await _capture("eight-actions")
	scene.queue_free()
	await _frames(3)

func test_status_cells_fit_in_the_unit_and_stage_and_turns_use_distinct_frames() -> void:
	var scene := await _battle()
	for enemy in scene.engine.get_state().enemies():
		scene._events.ledger.unit(enemy.uid).broken = true
		var burn := PresentationLedger.DisplayStatus.new()
		burn.status = Enums.StatusId.BURN
		burn.remaining = 2
		scene._events.ledger.unit(enemy.uid).statuses.append(burn)
	scene._battlefield.refresh_units()
	await _frames(4)
	for enemy in scene.engine.get_state().enemies():
		var view := scene._battlefield.view(enemy.uid)
		for region in view._regions:
			assert_lte((region.rect as Rect2).end.y, view.size.y, "status outline stays inside its reserved plate")
			assert_lte(view.global_position.y + (region.rect as Rect2).end.y, scene._battlefield.get_global_rect().end.y - 2, "status stays clear of the stage clip")
	await _capture("status-plates")
	var ally := scene.engine.get_state().party()[0]
	var enemy := scene.engine.get_state().enemies()[0]
	scene._banner.announce_turn(ally, 0, .4)
	await _frames(5)
	assert_eq(scene._banner._title.text, ally.display_name + "'s Turn")
	assert_false(scene._banner._badge.visible, "allies carry no enemy number")
	var ally_frame := scene._banner._panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert_eq(ally_frame.texture, UICraft.texture("utility"))
	await tree.create_timer(.18).timeout
	await _capture("ally-turn")
	await scene._banner._tween.finished
	scene._banner.announce_turn(enemy, 1, .4)
	await _frames(5)
	assert_eq(scene._banner._title.text, enemy.display_name + "'s Turn")
	assert_true(scene._banner._badge.visible and scene._banner._number == 1, "the enemy's number sits in its intent badge")
	assert_eq((scene._banner._panel.get_theme_stylebox("panel") as StyleBoxTexture).texture, UICraft.texture("attack"))
	await tree.create_timer(.18).timeout
	await _capture("enemy-turn")
	await scene._banner._tween.finished
	scene.queue_free()
	await _frames(3)

func test_mask_repair_preserves_every_pixel_outside_the_insert() -> void:
	var old := (load("res://assets/art/world/first_footsteps_v01/atlases/hollow_idle_v04.png") as Texture2D).get_image()
	var current := (load("res://assets/art/world/first_footsteps_v01/atlases/hollow_idle_v05.png") as Texture2D).get_image()
	var difference := 0
	var changed_elsewhere := 0
	for y in 256:
		for x in 256:
			if old.get_pixel(x, y) != current.get_pixel(x, y):
				difference += 1
				if not Rect2i(27, 27, 7, 5).has_point(Vector2i(x, y)) and not Rect2i(91, 27, 7, 5).has_point(Vector2i(x, y)):
					changed_elsewhere += 1
	assert_gt(difference, 0)
	assert_eq(changed_elsewhere, 0, "hood, torso, boots and seven other facings are byte-for-byte unchanged")
	for origin in [Vector2i(27, 28), Vector2i(31, 28)]:
		var dark_pixels := 0
		for y in 2:
			for x in 2:
				var pixel := current.get_pixelv(origin + Vector2i(x, y))
				if maxf(pixel.r, maxf(pixel.g, pixel.b)) < .15:
					dark_pixels += 1
		assert_eq(dark_pixels, 4, "each eye occupies matching two-by-two dark pixels")

func test_pin_accepts_supplies_intents_and_plain_conditions() -> void:
	var scene := await _battle()
	var inspector := scene._inspector
	var item: Button
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).item_slot >= 0:
			item = button
			break
	assert_not_null(item)
	await _move(item.get_global_rect().get_center())
	await _right(item.get_global_rect().get_center())
	assert_true(inspector.pinned)
	assert_true(inspector._payload is ActionReadout)
	assert_gte((inspector._payload as ActionReadout).item_charges, 0)
	await _right(Vector2(600, 200))
	var enemy := scene.engine.get_state().enemies()[0]
	var slot := scene._rail.slot(enemy.uid)
	var point := slot.global_position + Vector2(41, 15)
	await _move(point)
	await _right(point)
	assert_true(inspector.pinned)
	assert_true(inspector._payload is IntentReadout)
	await _move(item.get_global_rect().get_center())
	assert_eq(inspector._payload, slot.readout, "a pinned move ignores later supply hover")
	await _right(item.get_global_rect().get_center())
	var condition := scene._ribbon.get_child(0) as Button
	await _move(condition.get_global_rect().get_center())
	await _right(condition.get_global_rect().get_center())
	assert_true(inspector.pinned, "non-clickable conditions can still be pinned")
	assert_eq(inspector._payload, null, "plain condition rules don't fabricate an action")
	assert_eq(inspector.shown_text(), condition.tooltip_text)
	await _move(Vector2(600, 200))
	assert_eq(inspector.shown_text(), condition.tooltip_text)
	await _right(Vector2(600, 200))
	await tree.create_timer(.2).timeout
	assert_false(inspector.pinned)
	assert_eq(inspector.shown_text(), "", "unpinning onto empty ground returns the normal empty dock")
	var transient := Control.new()
	transient.tooltip_text = "Temporary source\nThis subject can disappear during inspection."
	transient.position = Vector2(580, 190)
	transient.size = Vector2(80, 50)
	scene.add_child(transient)
	await _move(transient.get_global_rect().get_center())
	await _right(transient.get_global_rect().get_center())
	assert_true(inspector.pinned)
	await _move(inspector.get_global_rect().get_center())
	transient.queue_free()
	await _frames(3)
	assert_false(inspector.pinned, "destroying a source clears the pin even while reading its card")
	scene.queue_free()
	await _frames(3)
