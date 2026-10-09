extends TestCase
var tree: SceneTree
var old_resolution: Vector2i
var old_theme: Theme

func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	old_resolution = Settings.data.window_resolution
	old_theme = tree.root.theme
	tree.root.theme = UITheme.build()

func after_each() -> void:
	var release := InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	release.keycode = KEY_SPACE
	Input.parse_input_event(release)
	Settings.data.window_resolution = old_resolution
	Settings.apply()
	tree.root.theme = old_theme
	AudioManager.silence()

func test_dialogue_hold_accelerates_and_revealed_lines_scroll_smoothly() -> void:
	var paragraphs := PackedStringArray()
	for i in 18:
		paragraphs.append("The bellkeeper watches the reeds. This is a long conversation, line %d." % i)
	var modal := WorldModal.make(&"dialogue", "Bellkeeper", paragraphs, [WorldDialogueReadout.action(&"close", "Close")])
	tree.root.add_child(modal)
	modal.set_process(false)
	await _frames(5)
	modal._process(.1)
	var normal := modal._dialogue.visible_characters
	var held := InputEventKey.new()
	held.physical_keycode = KEY_SPACE
	held.keycode = KEY_SPACE
	held.pressed = true
	Input.parse_input_event(held)
	await _frames(1)
	modal._process(.1)
	assert_gt(modal._dialogue.visible_characters - normal, normal * 3, "holding Space accelerates the text without closing the conversation")
	assert_true(modal.reveal_dialogue())
	modal._process(.016)
	var first_scroll := modal._dialogue_scroll_value
	assert_gt(first_scroll, 0, "latest revealed line starts scrolling into view")
	for i in 60:
		modal._process(.016)
	await _frames(2)
	assert_gt(modal._dialogue_scroll.scroll_vertical, first_scroll, "smooth scroll reaches the newly revealed lines")
	assert_false(modal.reveal_dialogue(), "confirm can advance once all text is visible")
	assert_gt(modal._dialogue_scroll.size.y, 90, "speaker name leaves the majority of the card for dialogue")
	modal.queue_free()
	await _frames(2)

func test_log_from_pause_accepts_window_scaled_wheel_and_preserves_history() -> void:
	Settings.data.window_resolution = Vector2i(2560, 1440)
	Settings.apply()
	var fixture: TestCase = load("res://tests/ui/test_v02_ui.gd").new()
	fixture._tree = tree
	var scene: BattleScene = await fixture._battle()
	for i in 90:
		scene._log.append("Event %d: the party follows the marsh road." % i)
	scene._open_pause()
	scene._open_combat_help()
	await _frames(3)
	assert_true(scene.is_paused(), "reaction help keeps the battle paused")
	scene._combat_help.button(&"back").pressed.emit()
	await _frames(3)
	assert_true(scene._pause_panel.visible, "Back from reaction help restores Pause")
	var log_button: Button
	for button in scene._pause_panel.find_children("*", "Button", true, false):
		if button.text == "Battle log": log_button = button
	assert_not_null(log_button)
	log_button.pressed.emit()
	await _frames(5)
	assert_false(scene._pause_panel.visible)
	assert_false(scene._modal.visible)
	var bar := scene._log._scroll.get_v_scroll_bar()
	var bottom := bar.value
	var point := scene._log._scroll.get_global_rect().get_center()
	var window_point := tree.root.get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = window_point
	tree.root.push_input(motion, false)
	await _frames(2)
	var wheel := InputEventMouseButton.new()
	wheel.position = window_point
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	tree.root.push_input(wheel, false)
	await _frames(3)
	assert_lt(bar.value, bottom, "wheel reaches the log through the scaled window after closing Pause")
	var history := bar.value
	scene._log.append("The next event arrives.")
	await _frames(3)
	assert_eq(bar.value, history, "new events preserve the reader's history position")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_HOME
	key.pressed = true
	tree.root.push_input(key, true)
	await _frames(2)
	assert_eq(bar.value, 0.0, "Home reaches the first retained event")
	key.physical_keycode = KEY_END
	tree.root.push_input(key, true)
	await _frames(2)
	assert_gt(bar.value, history, "End returns to the latest event")
	scene.queue_free()
	await _frames(3)

func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame

func test_rendered_idle_head_and_feet_stay_identical_for_every_direction() -> void:
	if DisplayServer.get_name() == "headless":
		return # This check runs with the rendered regression pass.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = load("res://src/ui/world/hollow_idle.gdshader")
	sprite.material = material
	viewport.add_child(sprite)
	var frames: SpriteFrames = load("res://assets/art/world/first_footsteps_v01/frames/hollow_motion_v05.tres")
	for direction in ["north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest"]:
		var rendered: Array[Image] = []
		for frame in 2:
			sprite.texture = frames.get_frame_texture(StringName("idle_" + direction), frame)
			await _frames(2)
			await RenderingServer.frame_post_draw
			rendered.append(viewport.get_texture().get_image())
		assert_true(rendered[0].get_region(Rect2i(0, 0, 64, 32)).get_data() == rendered[1].get_region(Rect2i(0, 0, 64, 32)).get_data(), direction + " hood/mask pixels never shift or morph")
		assert_true(rendered[0].get_region(Rect2i(0, 52, 64, 12)).get_data() == rendered[1].get_region(Rect2i(0, 52, 64, 12)).get_data(), direction + " boots stay planted")
		assert_true(rendered[0].get_region(Rect2i(0, 32, 64, 20)).get_data() != rendered[1].get_region(Rect2i(0, 32, 64, 20)).get_data(), direction + " authored torso breathing remains visible")
		if OS.get_cmdline_user_args().has("--evidence"):
			for i in 2:
				rendered[i].save_png("res://docs/reports/v0_4_fourth_polish/idle_%s_%d.png" % [direction, i])
	viewport.queue_free()
	await _frames(2)
