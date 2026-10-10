extends Node
## V0.5: breadcrumbs for bug reports and crash investigation, written into Godot's own session log.
##
## The engine already copies everything printed to the console into
## user://logs/hollow_choir.log (project.godot: debug/file_logging, flushed on every print), starts a
## fresh file each session and keeps the last few sessions beside it with a timestamp; errors with
## their script backtraces and an engine crash's backtrace land there too. On Windows that folder is
## %APPDATA%\Godot\app_userdata\Hollow Choir\logs. This adds what the engine cannot know: a header
## (build, platform, renderer, display) and one line per notable game event, stamped with the time
## since start, plus a closing line on a normal exit (a log without it ended in a crash or a kill).

const LOG_FOLDER := "user://logs"

## Tests turn this off so suites do not fill their logs with breadcrumbs.
var quiet := false
var _start_msec := 0
var _ended := false


func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	_header()
	EventBus.save_completed.connect(func(fact: SaveFact) -> void:
		event("save", "slot %d saved (%s)" % [fact.slot, "manual" if fact.origin == SaveFact.Origin.MANUAL else "automatic"]))
	EventBus.game_loaded.connect(func(slot: int) -> void: event("save", "slot %d loaded" % slot))
	EventBus.battle_finished.connect(func(result: BattleResult) -> void:
		event("battle", "result recorded: %s after %d rounds" % [EnumText.outcome(result.outcome), result.rounds]))
	EventBus.quest_changed.connect(func(change: QuestChange) -> void:
		event("quest", "%s stage %d" % [change.quest_id, change.stage]))


## One breadcrumb: "[T+01:23.456] category: text".
func event(category: String, text: String) -> void:
	if quiet:
		return
	print("[T+%s] %s: %s" % [_elapsed(), category, text])


## The folder holding this session's log and the previous ones, as an OS path.
func folder() -> String:
	return ProjectSettings.globalize_path(LOG_FOLDER)


func _notification(what: int) -> void:
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE) and not _ended:
		_ended = true
		event("session", "ended normally")


func _header() -> void:
	if quiet:
		return
	var info := Engine.get_version_info()
	var screen := DisplayServer.screen_get_size()
	print("[session] Hollow Choir %s, save format %d, %s build" % [ProjectSettings.get_setting("application/config/version", "?"),
		SaveMigrator.CURRENT_VERSION, "debug" if OS.is_debug_build() else "release"])
	print("[session] Godot %s · %s %s · %s" % [info.get("string", "?"), OS.get_name(), OS.get_version(), OS.get_locale()])
	print("[session] %s (%s) · %s · screen %dx%d, window %s" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(), RenderingServer.get_current_rendering_method(), screen.x, screen.y,
		DisplayServer.window_get_size()])
	print("[session] started %s · arguments %s" % [Time.get_datetime_string_from_system(false, true),
		OS.get_cmdline_user_args()])


func _elapsed() -> String:
	var msec := maxi(0, Time.get_ticks_msec() - _start_msec)
	return "%02d:%02d.%03d" % [msec / 60000, (msec / 1000) % 60, msec % 1000]
