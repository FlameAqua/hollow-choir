extends SceneTree
## Headless test runner (no addons).
##
##   godot --headless --path . --import            # once per fresh checkout (class cache)
##   godot --headless --path . --script res://tests/run_tests.gd [-- --filter=substring]
##
## Discovers res://tests/**/test_*.gd scripts extending TestCase, runs every test_* method and
## exits with code 1 if anything failed.

const TEST_ROOT := "res://tests"


func _initialize() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var started := Time.get_ticks_msec()
	var files := _find_test_files(TEST_ROOT)
	files.sort()
	var passed := 0
	var failed := 0
	var assertions := 0
	var failure_report := PackedStringArray()
	for path in files:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			failure_report.append("%s: could not load" % path)
			failed += 1
			continue
		var instance: Object = script.new()
		if not instance is TestCase:
			continue
		var test_case: TestCase = instance
		for method in _test_methods(test_case):
			var full_name := "%s::%s" % [path.get_file().get_basename(), method]
			if not filter.is_empty() and not full_name.contains(filter):
				continue
			test_case.reset_results()
			test_case.before_each()
			test_case.call(method)
			test_case.after_each()
			assertions += test_case.get_assertion_count()
			var failures := test_case.get_failures()
			if failures.is_empty():
				passed += 1
			else:
				failed += 1
				failure_report.append("FAIL %s" % full_name)
				for failure in failures:
					failure_report.append("    " + failure)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	for line in failure_report:
		print(line)
	print("")
	print("Tests: %d passed, %d failed, %d assertions (%.2fs)" % [passed, failed, assertions, elapsed])
	quit(1 if failed > 0 or passed == 0 else 0)


func _test_methods(test_case: TestCase) -> PackedStringArray:
	var names := PackedStringArray()
	for method: Dictionary in test_case.get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names


func _find_test_files(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				result.append_array(_find_test_files(path))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
