class_name TestCase
extends RefCounted
## Base class for tests. Every method starting with "test_" runs with before_each/after_each
## around it. Assertions record failures (with file:line) and let the test continue.

var _failures: PackedStringArray = PackedStringArray()
var _assertions: int = 0


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func get_failures() -> PackedStringArray:
	return _failures


func get_assertion_count() -> int:
	return _assertions


func reset_results() -> void:
	_failures = PackedStringArray()
	_assertions = 0


func fail(message: String) -> void:
	_failures.append("%s  (%s)" % [message, _caller_location()])


func assert_true(condition: bool, message: String = "expected true") -> void:
	_assertions += 1
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	_assertions += 1
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertions += 1
	if not _equal(actual, expected):
		fail("%sexpected <%s> but got <%s>" % [_prefix(message), str(expected), str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_assertions += 1
	if _equal(actual, unexpected):
		fail("%sdid not expect <%s>" % [_prefix(message), str(unexpected)])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	_assertions += 1
	if absf(actual - expected) > tolerance:
		fail("%sexpected %.4f (+/-%.4f) but got %.4f" % [_prefix(message), expected, tolerance, actual])


func assert_gt(actual: float, bound: float, message: String = "") -> void:
	_assertions += 1
	if not actual > bound:
		fail("%sexpected > %s but got %s" % [_prefix(message), str(bound), str(actual)])


func assert_gte(actual: float, bound: float, message: String = "") -> void:
	_assertions += 1
	if not actual >= bound:
		fail("%sexpected >= %s but got %s" % [_prefix(message), str(bound), str(actual)])


func assert_lt(actual: float, bound: float, message: String = "") -> void:
	_assertions += 1
	if not actual < bound:
		fail("%sexpected < %s but got %s" % [_prefix(message), str(bound), str(actual)])


func assert_lte(actual: float, bound: float, message: String = "") -> void:
	_assertions += 1
	if not actual <= bound:
		fail("%sexpected <= %s but got %s" % [_prefix(message), str(bound), str(actual)])


func assert_null(value: Variant, message: String = "expected null") -> void:
	_assertions += 1
	if value != null:
		fail("%s (got %s)" % [message, str(value)])


func assert_not_null(value: Variant, message: String = "expected a value") -> void:
	_assertions += 1
	if value == null:
		fail(message)


func assert_has(container: Variant, item: Variant, message: String = "") -> void:
	_assertions += 1
	if not container.has(item):
		fail("%sexpected %s to contain <%s>" % [_prefix(message), str(container), str(item)])


func assert_not_has(container: Variant, item: Variant, message: String = "") -> void:
	_assertions += 1
	if container.has(item):
		fail("%sexpected %s not to contain <%s>" % [_prefix(message), str(container), str(item)])


func assert_empty(container: Variant, message: String = "") -> void:
	_assertions += 1
	if not container.is_empty():
		fail("%sexpected empty but got %s" % [_prefix(message), str(container)])


func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


func _prefix(message: String) -> String:
	return "" if message.is_empty() else message + ": "


func _caller_location() -> String:
	for frame: Dictionary in get_stack():
		var source: String = frame.get("source", "")
		if not source.ends_with("test_case.gd"):
			return "%s:%d" % [source.get_file(), frame.get("line", 0)]
	return "?"
