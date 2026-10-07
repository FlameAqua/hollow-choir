extends SceneTree
## Compiles every GDScript file in the project and reports any that fail.
## Runs in-process (unlike --check-only) so autoload names resolve.
##
##   godot --headless --path . --script res://tools/check_scripts.gd

var _logger := TestErrorLogger.new()


func _initialize() -> void:
	OS.add_logger(_logger)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_logger.take_errors()
	var failed := 0
	var checked := 0
	for path in _scripts("res://"):
		checked += 1
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as Script
		var errors := _logger.take_errors()
		if script == null or not errors.is_empty():
			failed += 1
			print("FAIL %s" % path)
			for error in errors:
				print("    " + error)
	print("%d scripts checked, %d failed." % [checked, failed])
	OS.remove_logger(_logger)
	quit(1 if failed > 0 else 0)


func _scripts(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry != "addons":
				result.append_array(_scripts(path))
		elif entry.ends_with(".gd"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
