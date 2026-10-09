extends Node
## Versioned JSON save slots (DECISION_LOG D-011). Writes are atomic: the new file is written next
## to the old one and renamed over it, so a crash never leaves a half-written save.

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3


func slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_slot(slot: int) -> Error:
	var err := write_progress(slot, GameState.progress)
	if err == OK:
		GameState.active_slot = slot
	EventBus.game_saved.emit(slot, err == OK)
	return err


## Writes [param progress] to [param slot] atomically without publishing it into GameState. World
## transactions write a candidate first and adopt it only when this returns OK.
func write_progress(slot: int, progress: ProgressState) -> Error:
	return write_json_atomic(slot_path(slot), SaveMigrator.wrap(progress.to_dict(), slot))


func load_slot(slot: int) -> Error:
	var envelope := read_json(slot_path(slot))
	if envelope.is_empty():
		return ERR_FILE_CANT_READ
	var data := SaveMigrator.migrate(envelope)
	if data.is_empty():
		return ERR_FILE_UNRECOGNIZED
	GameState.progress = ProgressState.from_dict(data)
	GameState.active_slot = slot
	EventBus.game_loaded.emit(slot)
	return OK


func delete_slot(slot: int) -> Error:
	if not has_slot(slot):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


## Summary for slot pickers: {saved_at_unix, battles_won, weapon} or {} when empty/unreadable.
func slot_info(slot: int) -> Dictionary:
	var envelope := read_json(slot_path(slot))
	if envelope.is_empty():
		return {}
	var data: Dictionary = envelope.get("data", {})
	return {
		"saved_at_unix": int(envelope.get("saved_at_unix", 0)),
		"save_version": int(envelope.get("save_version", 0)),
		"battles_won": int(data.get("stats", {}).get("battles_won", 0)),
		"weapon": String(data.get("loadout", {}).get("weapon", "")),
	}


static func write_json_atomic(path: String, payload: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not a valid save" % path)
		return {}
	return parsed
