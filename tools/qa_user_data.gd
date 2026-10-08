extends RefCounted
## Guards QA runs started through tools/qa_godot.py, which points user:// at a throwaway home so
## tests and captures never read or write the player's own settings, saves or sandbox preferences.
## Preloaded by the test runner and capture tool (no class_name: a stale class cache cannot break them).

const ENV := "HOLLOW_CHOIR_QA_HOME"


## Prints where user:// points. Returns false when a launcher asked for isolation that did not take
## effect; the caller should stop before it reads or writes any data.
static func check() -> bool:
	var user_dir := OS.get_user_data_dir().replace("\\", "/")
	var home := OS.get_environment(ENV).replace("\\", "/").trim_suffix("/")
	print("User data: %s%s" % [user_dir, " (isolated QA home)" if not home.is_empty() else ""])
	if home.is_empty():
		return true
	var inside := user_dir.to_lower().begins_with(home.to_lower()) if OS.get_name() == "Windows" else user_dir.begins_with(home)
	if not inside:
		printerr("QA isolation failed: user data is %s, not inside %s. Nothing was run." % [user_dir, home])
	return inside
