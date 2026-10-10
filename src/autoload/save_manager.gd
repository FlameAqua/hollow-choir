extends Node
## Versioned JSON save slots (DECISION_LOG D-011). Writes are atomic: the new file is written next
## to the old one and renamed over it, so a crash never leaves a half-written save.

const SAVE_DIR := "user://saves"
const SLOT_COUNT := SaveSlotSummary.SLOT_COUNT


func slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_slot(slot: int) -> Error:
	var err := write_progress(slot, GameState.progress)
	if err == OK:
		GameState.active_slot = slot
	EventBus.game_saved.emit(slot, err == OK)
	# Playtest revision: a successful Practice recording is an automatic save (never on failure).
	if err == OK:
		EventBus.save_completed.emit(SaveFact.make(slot, SaveFact.Origin.AUTOMATIC))
	return err


## Writes [param progress] to [param slot] atomically without publishing it into GameState. World
## transactions write a candidate first and adopt it only when this returns OK.
func write_progress(slot: int, progress: ProgressState) -> Error:
	return write_json_atomic(slot_path(slot), SaveMigrator.wrap(progress.to_dict(), slot))


## Loads [param slot] into GameState (GameState.adopt) only after it parsed and migrated; a missing,
## damaged or newer save changes neither the live progress nor the active slot.
func load_slot(slot: int) -> Error:
	var envelope := read_json(slot_path(slot))
	if envelope.is_empty():
		return ERR_FILE_CANT_READ
	var data := SaveMigrator.migrate(envelope)
	if data.is_empty():
		return ERR_FILE_UNRECOGNIZED
	GameState.adopt(ProgressState.from_dict(data), slot)
	EventBus.game_loaded.emit(slot)
	return OK


func delete_slot(slot: int) -> Error:
	if not has_slot(slot):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


## The title's summary of [param slot] (V0.5 UI). Reads the file without loading it, writing or
## logging an error, and type-checks every field it shows, so an empty, damaged, older-format or
## newer save never crashes the title. See SaveSlotSummary.State.
func summary(slot: int) -> SaveSlotSummary:
	var result := SaveSlotSummary.new()
	result.slot = slot
	if not has_slot(slot):
		return result
	result.state = SaveSlotSummary.State.UNREADABLE
	result.reason_text = WorldCopy.SAVE_SLOT_UNREADABLE
	var envelope: Variant = read_json_quiet(slot_path(slot))
	if typeof(envelope) != TYPE_DICTIONARY:
		return result
	result.save_version = ProgressState.number(envelope.get("save_version"), 0)
	result.saved_at_unix = maxi(0, ProgressState.number(envelope.get("saved_at_unix"), 0))
	result.saved_at_text = SaveSlotSummary.utc_text(result.saved_at_unix)
	if typeof(envelope.get("game_version")) == TYPE_STRING:
		result.game_version = envelope.game_version
	if result.save_version > SaveMigrator.CURRENT_VERSION:
		result.state = SaveSlotSummary.State.UNSUPPORTED
		result.reason_text = WorldCopy.SAVE_SLOT_UNSUPPORTED
		return result
	if result.save_version <= 0 or typeof(envelope.get("data")) != TYPE_DICTIONARY:
		return result
	var data: Dictionary = envelope.data
	var stats: Variant = data.get("stats")
	if typeof(stats) == TYPE_DICTIONARY:
		result.battles_won = maxi(0, ProgressState.number(stats.get("battles_won"), 0))
	var loadout: Variant = data.get("loadout")
	if typeof(loadout) == TYPE_DICTIONARY and typeof(loadout.get("weapon")) == TYPE_STRING:
		result.weapon_id = StringName(loadout.weapon)
		var weapon: WeaponDefinition = Database.registry.weapons.get(result.weapon_id)
		result.weapon_name = weapon.display_name if weapon != null else ""
	var progress := ProgressState.new()
	var campaign: Variant = data.get("campaign")
	if typeof(campaign) == TYPE_DICTIONARY:
		progress = ProgressState.from_dict({"campaign": campaign})
	result.difficulty = progress.difficulty
	result.difficulty_name = EnumText.difficulty(result.difficulty as Enums.TacticalDifficulty)
	result.starter_preset = progress.starter_preset
	result.state = SaveSlotSummary.State.READY
	result.reason_text = ""
	return result


## Every slot's summary, in slot order.
func summaries() -> Array[SaveSlotSummary]:
	var result: Array[SaveSlotSummary] = []
	for slot in SLOT_COUNT:
		result.append(summary(slot))
	return result


## The loadable journeys for Continue: READY slots, newest first, equal times by slot number.
func journeys() -> Array[SaveSlotSummary]:
	var result: Array[SaveSlotSummary] = []
	for entry in summaries():
		if entry.loadable():
			result.append(entry)
	result.sort_custom(SaveSlotSummary.newest_first)
	return result


static func write_json_atomic(path: String, payload: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))


## The parsed JSON dictionary at [param path], or null when the file is missing, unreadable or not a
## JSON object. Logs nothing (the title summarizes damaged slots without engine errors).
static func read_json_quiet(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not a valid save" % path)
		return {}
	return parsed
