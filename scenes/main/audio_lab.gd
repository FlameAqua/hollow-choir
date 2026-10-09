class_name AudioLab
extends Control
## Manual full-mix audition. No battle rules, save writes or persistent settings changes.
var _cues: OptionButton
var _versions: OptionButton
var _tones: HFlowContainer
var _status: Label
var _position: HSlider
var _hint: Label
var _dragging := false
var _previewing_end := false
var _loop: Button
var _back: Button
var _scroll: ScrollContainer
var _playlists: Array[MusicPlaylist] = []
var _tracks: Array[MusicTrack] = []

func _ready() -> void:
	var background := ColorRect.new()
	background.color = UITheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(UITheme.label("Audio Lab", UITheme.ACCENT, UITheme.font_size(1.5)))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.focus_mode = Control.FOCUS_ALL
	column.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_scroll.add_child(content)
	content.add_child(UITheme.label("Choose a song. Switch its version or tone at the same point in the music.", UITheme.TEXT, -1, true))
	content.add_child(UITheme.label("Song", UITheme.ACCENT))
	_cues = UITheme.selector()
	_cues.fit_to_longest_item = false
	_cues.custom_minimum_size.y = UITheme.control_height()
	content.add_child(_cues)
	if AudioManager.music.library != null:
		for playlist in AudioManager.music.library.playlists:
			if playlist != null and not playlist.available().is_empty():
				_playlists.append(playlist)
				_cues.add_item(String(playlist.cue_id).replace("_", " ").capitalize())
	_cues.item_selected.connect(_select_cue)
	content.add_child(UITheme.label("Version / tone", UITheme.ACCENT))
	_versions = UITheme.selector()
	_versions.fit_to_longest_item = false
	_versions.custom_minimum_size.y = UITheme.control_height()
	content.add_child(_versions)
	_versions.item_selected.connect(_select_version)
	content.add_child(UITheme.label("Tone", UITheme.ACCENT))
	_tones = HFlowContainer.new()
	_tones.add_theme_constant_override("h_separation", 12)
	_tones.add_theme_constant_override("v_separation", 8)
	content.add_child(_tones)
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 12)
	controls.add_theme_constant_override("v_separation", 8)
	content.add_child(controls)
	var next := _button(controls, "Next version", _next_version)
	next.tooltip_text = "Choose another version now and crossfade into its beginning."
	_loop = _button(controls, "Preview ending", _preview_ending)
	_loop.tooltip_text = "Skip to five seconds before the automatic end transition, then hear the outro blend into the next version."
	_button(controls, "Stop", _stop)
	_status = UITheme.label("", UITheme.TEXT, -1, true)
	content.add_child(_status)
	_position = HSlider.new()
	_position.step = 0.1
	_position.scrollable = false
	_position.custom_minimum_size.y = UITheme.control_height()
	_position.tooltip_text = "Click or drag to seek. Arrow keys adjust the focused playhead."
	_position.value_changed.connect(_seek)
	_position.drag_started.connect(func() -> void: _dragging = true)
	_position.drag_ended.connect(func(_changed: bool) -> void: _dragging = false)
	content.add_child(_position)
	_hint = UITheme.label("", UITheme.TEXT_DIM, -1, true)
	content.add_child(_hint)
	var effects := HFlowContainer.new()
	effects.add_theme_constant_override("h_separation", 12)
	effects.add_theme_constant_override("v_separation", 8)
	content.add_child(effects)
	_button(effects, "Hear hit", func() -> void: AudioManager.play(AudioManager.Cue.HIT))
	_button(effects, "Hear parry", func() -> void: AudioManager.play(AudioManager.Cue.PARRY))
	content.add_child(UITheme.label("Same-song switches keep the timestamp. Preview ending waits for the natural outro; Next version starts another mix now. Click or drag the playhead to skip. Volume follows Settings.", UITheme.TEXT_DIM, -1, true))
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.y = UITheme.control_height()
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(_leave)
	column.add_child(_back)
	if not _playlists.is_empty():
		var selected := 0
		for index in _playlists.size():
			if _playlists[index].cue_id == AudioManager.music.cue_id:
				selected = index
		_cues.select(selected)
		_select_cue(selected)
		_focus_first.call_deferred()
	else:
		_cues.disabled = true
		_versions.disabled = true
		_back.grab_focus.call_deferred()
	_process(0.0)

func _focus_first() -> void:
	# Flow containers need settled widths before ScrollContainer follows initial focus.
	await get_tree().process_frame
	await get_tree().process_frame
	_cues.grab_focus()
	_scroll.scroll_vertical = 0

func _select_cue(index: int) -> void:
	_previewing_end = false
	_tracks.clear()
	_versions.clear()
	var playlist := _playlists[index]
	for track in playlist.tracks:
		if track != null and track.playable():
			_tracks.append(track)
			_versions.add_item("v%02d · %s" % [track.version, String(track.tone).capitalize()])
	for child in _tones.get_children():
		_tones.remove_child(child)
		child.queue_free()
	var tones: Array[StringName] = []
	for track in _tracks:
		if not tones.has(track.tone):
			tones.append(track.tone)
	for next_tone in tones:
		var button := _button(_tones, String(next_tone).capitalize(), _select_tone.bind(next_tone))
		button.toggle_mode = true
		button.set_meta(&"tone", next_tone)
	AudioManager.request_music(playlist.cue_id)
	_sync_opening_choice()

func _select_version(index: int) -> void:
	_previewing_end = false
	AudioManager.music.audition(_playlists[_cues.selected].cue_id, _tracks[index].id)

func _select_tone(next_tone: StringName) -> void:
	_previewing_end = false
	AudioManager.request_music(_playlists[_cues.selected].cue_id, next_tone)
	_sync_opening_choice()

func _next_version() -> void:
	_previewing_end = false
	AudioManager.music.next_mix()

func _stop() -> void:
	_previewing_end = false
	AudioManager.request_music(&"")

func _preview_ending() -> void:
	_previewing_end = AudioManager.music.test_loop()
	_process(0.0)

func _seek(seconds: float) -> void:
	_previewing_end = false
	AudioManager.music.seek(seconds)
	_process(0.0)

func _sync_opening_choice() -> void:
	var current := AudioManager.music.current_track
	for button: Button in _tones.get_children():
		button.set_pressed_no_signal(current != null and current.tone == button.get_meta(&"tone"))
	for index in _tracks.size():
		if _tracks[index] == current:
			_versions.select(index)
			return

func _process(_delta: float) -> void:
	if _status == null:
		return
	var status := AudioManager.music.playback_status()
	var duration: float = status.duration
	var position: float = status.position
	_status.text = "Stopped" if status.track == &"" else "%s\n%.1f / %.1f seconds · %s · %d active %s" % [
		String(status.track).replace("_", " "), position, duration,
		"Crossfading" if status.fading else "Playing", status.players,
		"player" if status.players == 1 else "players"]
	_position.set_block_signals(true)
	_position.max_value = maxf(0.1, duration - 0.001)
	_position.editable = duration > 0.0
	if not _dragging:
		_position.set_value_no_signal(position)
	_position.set_block_signals(false)
	_loop.disabled = duration <= 0.0 or status.fading
	if _previewing_end:
		_hint.text = "Automatic end transition: the next version begins at 0:00." if status.transition == &"end" else \
			"Previewing ending: automatic transition in %.1f seconds." % status.seconds_until_transition
	else:
		_hint.text = "Changes blend at the current timestamp. Versions still rotate automatically at the end."
	_sync_opening_choice()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = UITheme.control_height()
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.CANCEL) or event.is_action_pressed(InputBindings.MENU):
		get_viewport().set_input_as_handled()
		_leave()

func _leave() -> void:
	AudioManager.play(AudioManager.Cue.UI_CANCEL)
	SceneRouter.goto(SceneRouter.MAIN_MENU)
