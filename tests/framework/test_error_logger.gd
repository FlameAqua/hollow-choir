class_name TestErrorLogger
extends Logger
## Captures engine and script errors so a runtime error inside a test fails that test instead of
## silently aborting it. Warnings are ignored. May be called from any thread.

var _mutex := Mutex.new()
var _errors: PackedStringArray = PackedStringArray()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == Logger.ERROR_TYPE_WARNING:
		return
	var message := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [message, file.get_file(), line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func take_errors() -> PackedStringArray:
	_mutex.lock()
	var errors := _errors
	_errors = PackedStringArray()
	_mutex.unlock()
	return errors
