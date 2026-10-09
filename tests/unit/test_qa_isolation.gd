extends TestCase
## The QA guard refuses a run whose user data or editor/resource cache escaped the isolated home,
## so tests and captures never share files with the developer's own editor or profile.

const QA_USER_DATA := preload("res://tools/qa_user_data.gd")


func test_guard_rejects_a_cache_outside_the_qa_home() -> void:
	var home := OS.get_environment(QA_USER_DATA.ENV)
	if home.is_empty():
		return # Not launched through tools/qa_godot.py (e.g. CI): isolation is not requested.
	assert_true(QA_USER_DATA.check(), "the launcher isolates user data and caches")
	var cache := OS.get_cache_dir().replace("\\", "/")
	var user := OS.get_user_data_dir().replace("\\", "/")
	assert_true(cache.to_lower().begins_with(home.replace("\\", "/").to_lower()), "cache lives in the QA home")
	# A home that still contains user:// but not the cache must be rejected.
	OS.set_environment(QA_USER_DATA.ENV, user.get_base_dir())
	var accepted := QA_USER_DATA.check()
	OS.set_environment(QA_USER_DATA.ENV, home)
	assert_false(accepted, "a cache outside the home stops the run")
