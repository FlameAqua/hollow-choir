extends TestCase
## V0.5 follow-up presentation: the ring art is centred and complete (it frames the Forge wheel and
## the map's places), the Forge's three sockets sit symmetrically on the wheel, an item card for a
## choice in a popup sits beside the whole popup and above it, and the session log is configured,
## written and reachable from Settings.

var tree: SceneTree
var stage: Control
var old_theme: Theme
var kit: WorldKit
var host: WorldHost


class MessageLog:
	extends Logger
	var _mutex := Mutex.new()
	var lines := PackedStringArray()

	func _log_message(message: String, _error: bool) -> void:
		_mutex.lock()
		lines.append(message)
		_mutex.unlock()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		pass


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)
	old_theme = tree.root.theme
	tree.root.theme = UITheme.build()
	kit = WorldKit.new()
	kit.isolate()
	stage = Control.new()
	tree.root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func after_each() -> void:
	if host != null:
		host.queue_free()
		host = null
	stage.queue_free()
	tree.root.theme = old_theme
	kit.restore()
	AudioManager.silence()


func _frames(count: int = 5) -> void:
	for index in count:
		await tree.process_frame


## The rect of [param image]'s solid pixels (alpha above 0.1); faint halo pixels are ignored.
static func _solid(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.1:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


func test_the_ring_art_is_centred_and_complete() -> void:
	for id in ["ring", "ring_open"]:
		var image := UICraft.texture(id).get_image()
		var solid := _solid(image)
		var centre := Vector2(solid.position) + Vector2(solid.size) * 0.5
		assert_almost_eq(centre.x, image.get_width() * 0.5, 1.0, "%s is centred across" % id)
		assert_almost_eq(centre.y, image.get_height() * 0.5, 1.0, "%s is centred down" % id)
		assert_true(solid.position.x > 0 and solid.position.y > 0 and solid.end.x < image.get_width()
			and solid.end.y < image.get_height(), "%s keeps all four ornaments inside its image: %s" % [id, solid])


func test_the_forge_sockets_sit_symmetrically_on_the_wheel() -> void:
	GameState.progress.weapon_mastery[&"pilgrims_edge"] = 1
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await _frames(4)
	host.open_crafting(WorldKit.site(&"preparation_bench"))
	await _frames(4)
	var wheel := host.modal.find_child("WeaponSockets", true, false) as Control
	var ring := wheel.get_child(0) as TextureRect
	assert_eq(ring.texture, UICraft.texture("ring"))
	var centre := ring.get_global_rect().get_center()
	var weapon := (wheel.find_child("ForgeWeapon", false, false) as Control).get_global_rect().get_center()
	assert_lt(weapon.distance_to(centre), 1.0, "the weapon sits in the middle of the wheel")
	var sockets: Array[Vector2] = []
	for index in 3:
		sockets.append((wheel.find_child("FittingSocket_%d" % index, false, false) as Control).get_global_rect().get_center())
	assert_almost_eq(sockets[0].x, centre.x, 1.0, "the usable socket is straight above the middle")
	assert_almost_eq((sockets[1].x + sockets[2].x) * 0.5, centre.x, 1.0, "the locked sockets mirror each other")
	assert_almost_eq(sockets[1].y, sockets[2].y, 0.5)
	assert_almost_eq(sockets[1].distance_to(centre), sockets[2].distance_to(centre), 0.5)


func test_a_choice_card_sits_beside_the_whole_popup_and_above_it() -> void:
	var origin := Button.new()
	origin.position = Vector2(172, 174)
	origin.size = Vector2(48, 48)
	stage.add_child(origin)
	var options: Array[Dictionary] = []
	for name in ["Mending Draught", "Fen Water Flask", "Clotting Salve", "Focus Tincture", "Spare Tonic"]:
		options.append({"id": StringName(name.to_snake_case()), "selectable": true,
			"payload": JourneyUI.facts(name, "A supply for the next encounter.", "Supply", JourneyUI.icon("empty"))})
	var popup := OwnedChoicePopup.make(origin, "Supply 2", options)
	stage.add_child(popup)
	await _frames(6)
	var option := popup.find_child("Owned_fen_water_flask", true, false) as Button
	var motion := InputEventMouseMotion.new()
	motion.position = option.get_global_rect().get_center()
	tree.root.push_input(motion, true)
	var card: HoverInspector
	for attempt in 60:
		await tree.process_frame
		for inspector: HoverInspector in stage.find_children("*", "HoverInspector", true, false):
			if inspector.is_visible_in_tree():
				card = inspector
		if card != null and card.shown_text().begins_with("Fen Water Flask"):
			break
	assert_not_null(card, "hovering a choice shows its card")
	if card == null:
		return
	assert_true(card.shown_text().begins_with("Fen Water Flask"))
	assert_false(card.get_global_rect().intersects(popup.get_global_rect()), "the card never covers the popup")
	assert_gte(card.get_global_rect().position.x, popup.get_global_rect().end.x, "it sits to the popup's side")
	assert_almost_eq(card.get_global_rect().position.y, option.get_global_rect().position.y, 1.0, "level with the choice")
	assert_gt(_z(card), _z(popup), "and draws above it")


## The z the renderer uses: relative z adds up through parents, but a top-level item hangs off the
## canvas itself, so its own z is where the sum stops.
static func _z(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		var canvas_item := node as CanvasItem
		z += canvas_item.z_index
		if not canvas_item.z_as_relative or canvas_item.top_level:
			break
		node = node.get_parent()
	return z


func test_each_session_keeps_its_log_and_the_game_adds_breadcrumbs() -> void:
	assert_true(ProjectSettings.get_setting("debug/file_logging/enable_file_logging"), "file logging on every platform")
	assert_eq(ProjectSettings.get_setting("debug/file_logging/log_path"), "user://logs/hollow_choir.log")
	assert_true(ProjectSettings.get_setting("application/run/flush_stdout_on_print"), "lines reach the file before a crash")
	assert_gte(int(ProjectSettings.get_setting("debug/file_logging/max_log_files")), 2,
		"the session before a crash survives the restart")
	assert_eq(SessionLog.folder(), ProjectSettings.globalize_path("user://logs"))
	var capture := MessageLog.new()
	OS.add_logger(capture)
	var was_quiet := SessionLog.quiet
	SessionLog.quiet = false
	SessionLog.event("test", "one breadcrumb")
	SessionLog.quiet = true
	SessionLog.event("test", "silenced")
	SessionLog.quiet = was_quiet
	OS.remove_logger(capture)
	var lines := Array(capture.lines).filter(func(line: String) -> bool: return line.contains("test: "))
	assert_eq(lines.size(), 1, "one line, and none while quiet")
	assert_true(RegEx.create_from_string("^\\[T\\+\\d\\d:\\d\\d\\.\\d{3}\\] test: one breadcrumb").search(lines[0]) != null,
		"time since start, category, text: %s" % lines)
	# Settings offers the folder for bug reports.
	var settings := (load(SceneRouter.SETTINGS) as PackedScene).instantiate()
	stage.add_child(settings)
	await _frames(3)
	var open := settings.find_child("OpenLogs", true, false) as Button
	assert_not_null(open)
	assert_eq(open.text, "Open log folder")
