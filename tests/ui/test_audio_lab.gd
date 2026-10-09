extends TestCase

func after_each() -> void:
	AudioManager.request_music(&"")
	AudioManager.music._update_fade(AudioManager.music._fade_start + 10000000)

func test_manual_controls_reach_real_intense_variant_without_changing_progress_or_settings() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var progress := GameState.progress.to_dict()
	var config := ConfigFile.new()
	Settings.data.write_to(config)
	var settings := config.encode_to_text()
	var previous_theme := tree.root.theme
	tree.root.theme = UITheme.build()
	var lab: AudioLab = load(SceneRouter.AUDIO_LAB).instantiate()
	tree.root.add_child(lab)
	lab.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lab.size = Vector2(1280, 720)
	for frame in 5:
		await tree.process_frame
	assert_true(lab._cues.has_focus())
	assert_eq(lab._scroll.scroll_vertical, 0, "initial page starts at the song selector")
	assert_gte(lab._cues.get_global_rect().position.y, lab._scroll.get_global_rect().position.y)
	assert_lte(lab._back.get_global_rect().end.y, 720)
	assert_lte(lab._scroll.get_global_rect().end.x, 1280)
	assert_gt(lab._scroll.size.y, 100)
	for index in lab._playlists.size():
		if lab._playlists[index].cue_id == &"briarfen_battle":
			lab._cues.select(index)
			lab._cues.item_selected.emit(index)
	for index in lab._tracks.size():
		if lab._tracks[index].id == &"briarfen_battle_v01":
			lab._versions.select(index)
			lab._versions.item_selected.emit(index)
	AudioManager.music._update_fade(AudioManager.music._fade_start + 10000000)
	AudioManager.music.seek(45.0)
	for button in lab._tones.get_children():
		if button.text == "Intense":
			button.pressed.emit()
	assert_eq(AudioManager.music.current_track.id, &"briarfen_battle_v01_intense")
	assert_eq(lab._tracks[lab._versions.selected].tone, &"intense")
	assert_almost_eq(AudioManager.music.playback_status().position, 45.0, 0.15,
		"real prepared Ogg retains the playhead through a tone button")
	AudioManager.music._update_fade(AudioManager.music._fade_start + 10000000)
	lab._process(0.0)
	assert_false(lab._loop.disabled)
	lab._loop.pressed.emit()
	assert_gt(AudioManager.music.playback_status().position, 110.0)
	assert_true(lab._hint.text.contains("automatic transition in 5."))
	assert_true(lab._status.text.contains("intense"))
	lab._scroll.scroll_vertical = 100000
	lab._back.grab_focus()
	assert_true(lab._back.has_focus())
	assert_eq(GameState.progress.to_dict(), progress)
	Settings.data.write_to(config)
	assert_eq(config.encode_to_text(), settings)
	lab.queue_free()
	await tree.process_frame
	tree.root.theme = previous_theme

func test_stop_ends_the_ending_preview_countdown() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var lab: AudioLab = load(SceneRouter.AUDIO_LAB).instantiate()
	tree.root.add_child(lab)
	for frame in 3:
		await tree.process_frame
	AudioManager.music._update_fade(AudioManager.music._fade_start + 10000000)
	lab._process(0.0)
	lab._loop.pressed.emit()
	assert_true(lab._hint.text.contains("automatic transition in"))
	var stop: Button = lab.find_children("*", "Button", true, false).filter(
		func(button: Button) -> bool: return button.text == "Stop")[0]
	stop.pressed.emit()
	lab._process(0.0)
	assert_eq(AudioManager.music.playback_status().track, &"")
	assert_false(lab._hint.text.contains("automatic transition"), "a stopped lab no longer counts down")
	lab.queue_free()
	await tree.process_frame

func test_seek_bar_accepts_real_click_and_keyboard_without_feedback_or_outgoing_audio() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var lab: AudioLab = load(SceneRouter.AUDIO_LAB).instantiate()
	tree.root.add_child(lab)
	lab.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lab.size = Vector2(1280, 720)
	for frame in 5:
		await tree.process_frame
	AudioManager.music._update_fade(AudioManager.music._fade_start + 10000000)
	lab._process(0.0)
	lab._scroll.ensure_control_visible(lab._position)
	await tree.process_frame
	var rect := lab._position.get_global_rect()
	var point := Vector2(rect.position.x + rect.size.x * 0.5, rect.get_center().y)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.global_position = point
	click.pressed = true
	tree.root.push_input(click, true)
	click.pressed = false
	tree.root.push_input(click, true)
	await tree.process_frame
	var status := AudioManager.music.playback_status()
	assert_almost_eq(status.position, status.duration * 0.5, 1.0, "a native slider click really seeks the stream")
	assert_eq(status.players, 1)
	var before: float = status.position
	lab._position.grab_focus()
	var value := lab._position.value
	var key := InputEventKey.new()
	# Bindings (and their ui_* mirrors) match physical keys, as a real keyboard press supplies.
	key.keycode = KEY_RIGHT
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	tree.root.push_input(key, true)
	key.pressed = false
	tree.root.push_input(key, true)
	assert_almost_eq(lab._position.value, value + lab._position.step, 0.001, "one Right press moves the playhead one step")
	assert_almost_eq(AudioManager.music.playback_status().position, lab._position.value, 0.001, "and seeks the stream there")
	for frame in 4:
		await tree.process_frame
	assert_eq(AudioManager.music.transition_reason, &"seek", "playback updates never seek via a feedback signal")
	assert_gt(AudioManager.music.playback_status().position, before)
	lab.queue_free()
	await tree.process_frame
